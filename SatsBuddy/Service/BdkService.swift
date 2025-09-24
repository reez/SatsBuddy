//
//  BdkService.swift
//  SatsBuddy
//

import BitcoinDevKit
import Foundation
import os

private struct BdkService {
    func deriveAddress(descriptor: String, network: Network) throws -> String {
        // Parse the target descriptor from CKTap.
        let descriptor = try Descriptor(descriptor: descriptor, network: network)

        // BDK Wallet requires both receive and change descriptors; we only need
        // the first external address, so use a static valid change descriptor.
        let changeDescriptor = try Descriptor(
            descriptor: "wpkh(0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798)",
            network: network
        )

        // Use an in-memory persister so nothing touches disk.
        let persister = try Persister.newInMemory()

        // Create a temporary wallet to derive an address conforming to descriptor rules.
        let wallet = try Wallet(
            descriptor: descriptor,
            changeDescriptor: changeDescriptor,
            network: network,
            persister: persister
        )

        // We only need the first external address to display to the user.
        let addressInfo = wallet.peekAddress(keychain: .external, index: 0)
        let address = String(describing: addressInfo.address)
        Log.cktap.debug("Derived address from descriptor: \(address, privacy: .public)")
        return address
    }

}

struct BdkClient {
    let deriveAddress: (String, Network) throws -> String
    let getBalanceFromAddress: (String, Network) async throws -> Balance
    private init(
        deriveAddress: @escaping (String, Network) throws -> String,
        getBalanceFromAddress: @escaping (String, Network) async throws -> Balance
    ) {
        self.deriveAddress = deriveAddress
        self.getBalanceFromAddress = getBalanceFromAddress
    }
}

extension BdkClient {
    static let live = Self(
        deriveAddress: { descriptor, network in
            try BdkService().deriveAddress(descriptor: descriptor, network: network)
        },
        getBalanceFromAddress: { address, network in
            Log.cktap.debug(
                "BdkService.getBalanceFromAddress called with address: \(address, privacy: .public)"
            )

            // Use Mempool.space API to get real balance
            let urlString = "https://mempool.space/api/address/\(address)"
            guard let url = URL(string: urlString) else {
                throw NSError(
                    domain: "BdkService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
                )
            }

            let (data, _) = try await URLSession.shared.data(from: url)

            struct MempoolAddressResponse: Codable {
                let chain_stats: ChainStats
                let mempool_stats: MempoolStats

                struct ChainStats: Codable {
                    let funded_txo_sum: UInt64
                    let spent_txo_sum: UInt64
                }

                struct MempoolStats: Codable {
                    let funded_txo_sum: UInt64
                    let spent_txo_sum: UInt64
                }
            }

            let response = try JSONDecoder().decode(MempoolAddressResponse.self, from: data)

            // Calculate balance: (confirmed funded - confirmed spent) + (mempool funded - mempool spent)
            let confirmedBalance =
                response.chain_stats.funded_txo_sum - response.chain_stats.spent_txo_sum
            let mempoolBalance =
                response.mempool_stats.funded_txo_sum - response.mempool_stats.spent_txo_sum
            let totalBalance = confirmedBalance + mempoolBalance

            Log.cktap.debug(
                "Retrieved real balance from Mempool.space: \(totalBalance, privacy: .public) sats"
            )

            let confirmedAmount = Amount.fromSat(satoshi: confirmedBalance)
            let mempoolAmount = Amount.fromSat(satoshi: mempoolBalance)
            let totalAmount = Amount.fromSat(satoshi: totalBalance)
            let zero = Amount.fromSat(satoshi: 0)

            return Balance(
                immature: zero,
                trustedPending: mempoolAmount,
                untrustedPending: zero,
                confirmed: confirmedAmount,
                trustedSpendable: confirmedAmount,
                total: totalAmount
            )
        }
    )
}

#if DEBUG
    extension BdkClient {
        static let mock = Self(
            deriveAddress: { descriptor, _ in
                let seed = abs(descriptor.hashValue) % 3
                switch seed {
                case 0: return "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
                case 1: return "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"
                default: return "bc1qrp33g013ahg3pq0ny9kxwj42yl4xpr3xz4fzqc"
                }
            },
            getBalanceFromAddress: { address, _ in
                // Create a mock balance based on address for testing
                let seed = abs(address.hashValue) % 3
                let satAmount: UInt64 =
                    switch seed {
                    case 0: 75000
                    case 1: 125000
                    default: 31500
                    }

                let amount = Amount.fromSat(satoshi: satAmount)
                let zero = Amount.fromSat(satoshi: 0)

                return Balance(
                    immature: zero,
                    trustedPending: zero,
                    untrustedPending: zero,
                    confirmed: amount,
                    trustedSpendable: amount,
                    total: amount
                )
            }
        )
    }
#endif
