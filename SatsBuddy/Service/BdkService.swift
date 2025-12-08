//
//  BdkService.swift
//  SatsBuddy
//

import BitcoinDevKit
import Foundation
import os

private struct BdkService {
    func deriveAddress(descriptor: String, network: Network) throws -> String {
        let descriptor = try Descriptor(descriptor: descriptor, network: network)

        let persister = try Persister.newInMemory()

        let wallet = try Wallet.createSingle(
            descriptor: descriptor,
            network: network,
            persister: persister
        )

        let addressInfo = wallet.peekAddress(keychain: .external, index: 0)
        let address = String(describing: addressInfo.address)
        Log.cktap.debug(
            "Derived first external address from descriptor: \(address, privacy: .private(mask: .hash))"
        )
        return address
    }

    func fetchBalance(address: String, network: Network) async throws -> Balance {
        Log.cktap.debug(
            "Fetching on-chain balance for address \(address, privacy: .private(mask: .hash))"
        )

        let baseURL = mempoolBaseURL(for: network)
        let urlString = "\(baseURL)/api/address/\(address)"
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
            "Retrieved on-chain balance from Mempool.space: \(totalBalance, privacy: .private) sats"
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

    func fetchTransactions(
        address: String,
        network: Network,
        limit: Int = 25
    ) async throws -> [SlotTransaction] {
        Log.cktap.debug(
            "Fetching transactions for address \(address, privacy: .private(mask: .hash))"
        )

        let baseURL = mempoolBaseURL(for: network)
        let urlString = "\(baseURL)/api/address/\(address)/txs"

        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "BdkService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid transactions URL"]
            )
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()

        let transactions = try decoder.decode([MempoolTransaction].self, from: data)
        let targetAddress = address.lowercased()

        let mapped = transactions.map { tx -> SlotTransaction in
            let received = tx.vout
                .filter { $0.scriptpubkey_address?.lowercased() == targetAddress }
                .reduce(UInt64(0)) { $0 + $1.value }

            let spent = tx.vin
                .compactMap { $0.prevout }
                .filter { $0.scriptpubkey_address?.lowercased() == targetAddress }
                .reduce(UInt64(0)) { total, prevout in
                    total + (prevout.value ?? 0)
                }

            let netAmount = Int64(received) - Int64(spent)

            let direction: SlotTransaction.Direction = netAmount >= 0 ? .incoming : .outgoing

            let timestamp: Date?
            if let blockTime = tx.status.block_time {
                timestamp = Date(timeIntervalSince1970: TimeInterval(blockTime))
            } else {
                timestamp = nil
            }

            return SlotTransaction(
                txid: tx.txid,
                amount: netAmount,
                fee: tx.fee,
                timestamp: timestamp,
                confirmed: tx.status.confirmed,
                direction: direction
            )
        }

        if limit > 0 {
            return Array(mapped.prefix(limit))
        }

        return mapped
    }

    func warmUpIfNeeded() async {
        await BdkWarmUp.shared.run()
    }

    func buildPsbt(
        sourcePubkey: String?,
        sourceDescriptor: String?,
        destinationAddress: String,
        feeRate: UInt64,
        network: Network
    ) async throws -> Psbt {
        let descriptorString: String
        if let sourceDescriptor, !sourceDescriptor.isEmpty {
            descriptorString = sourceDescriptor
        } else if let sourcePubkey {
            descriptorString = "wpkh(\(sourcePubkey))"
        } else {
            throw NSError(
                domain: "BdkService",
                code: 100,
                userInfo: [NSLocalizedDescriptionKey: "Missing source key/descriptor"]
            )
        }

        let descriptor = try Descriptor(
            descriptor: descriptorString,
            network: network
        )
        let persister = try Persister.newInMemory()
        let wallet = try Wallet.createSingle(
            descriptor: descriptor,
            network: network,
            persister: persister
        )

        let revealed = wallet.revealNextAddress(keychain: .external).address
        Log.cktap.debug(
            "Syncing for revealed address: \(revealed, privacy: .private(mask: .hash)) descriptor=\(descriptorString, privacy: .private(mask: .hash))"
        )

        let base = "\(mempoolBaseURL(for: network))/api"
        let esplora = EsploraClient(url: base)

        let syncRequest = try wallet.startSyncWithRevealedSpks().build()
        let update = try esplora.sync(request: syncRequest, parallelRequests: 4)
        try wallet.applyUpdate(update: update)

        let utxos = wallet.listUnspent()
        let total = utxos.reduce(UInt64(0)) { $0 + $1.txout.value.toSat() }
        Log.cktap.debug(
            "Post-sync UTXOs: count=\(utxos.count) total=\(total, privacy: .private) sats"
        )

        let destScript = try Address(address: destinationAddress, network: network)
            .scriptPubkey()

        let psbt = try TxBuilder()
            .drainWallet()
            .drainTo(script: destScript)
            .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: feeRate))
            .finish(wallet: wallet)

        return psbt
    }

    private func mempoolBaseURL(for network: Network) -> String {
        switch network {
        case .bitcoin:
            return "https://mempool.space"
        case .testnet:
            return "https://mempool.space/testnet"
        case .testnet4:
            return "https://mempool.space/testnet4"
        case .signet:
            return "https://mempool.space/signet"
        case .regtest:
            return "http://localhost:3000"
        @unknown default:
            return "https://mempool.space"
        }
    }
}

struct BdkClient {
    let deriveAddress: @Sendable (String, Network) throws -> String
    let getBalanceFromAddress: @Sendable (String, Network) async throws -> Balance
    let warmUp: @Sendable () async -> Void
    let getTransactionsForAddress:
        @Sendable (String, Network, Int) async throws -> [SlotTransaction]
    let buildPsbt: @Sendable (String?, String?, String, UInt64, Network) async throws -> Psbt

    private init(
        deriveAddress: @escaping @Sendable (String, Network) throws -> String,
        getBalanceFromAddress: @escaping @Sendable (String, Network) async throws -> Balance,
        warmUp: @escaping @Sendable () async -> Void,
        getTransactionsForAddress:
            @escaping @Sendable (String, Network, Int) async throws ->
            [SlotTransaction],
        buildPsbt:
            @escaping @Sendable (String?, String?, String, UInt64, Network) async throws ->
            Psbt
    ) {
        self.deriveAddress = deriveAddress
        self.getBalanceFromAddress = getBalanceFromAddress
        self.warmUp = warmUp
        self.getTransactionsForAddress = getTransactionsForAddress
        self.buildPsbt = buildPsbt
    }
}

extension BdkClient {
    static let live = Self(
        deriveAddress: { descriptor, network in
            try BdkService().deriveAddress(descriptor: descriptor, network: network)
        },
        getBalanceFromAddress: { address, network in
            try await BdkService().fetchBalance(address: address, network: network)
        },
        warmUp: {
            await BdkService().warmUpIfNeeded()
        },
        getTransactionsForAddress: { address, network, limit in
            try await BdkService().fetchTransactions(
                address: address,
                network: network,
                limit: limit
            )
        },
        buildPsbt: { sourcePubkey, sourceDescriptor, destination, feeRate, network in
            try await BdkService().buildPsbt(
                sourcePubkey: sourcePubkey,
                sourceDescriptor: sourceDescriptor,
                destinationAddress: destination,
                feeRate: feeRate,
                network: network
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
            },
            warmUp: {},
            getTransactionsForAddress: { address, _, limit in
                let baseSeed = abs(address.hashValue)
                let count = min(max(limit, 1), 10)
                return (0..<count).map { index in
                    let valueSeed = baseSeed &+ index
                    let isIncoming = valueSeed % 2 == 0
                    let amount = Int64((valueSeed % 50_000) + 1_000) * (isIncoming ? 1 : -1)
                    let timestamp = Date().addingTimeInterval(Double(-index * 86_400))
                    return SlotTransaction(
                        txid: String(format: "mock-tx-%08x-%02d", baseSeed, index),
                        amount: amount,
                        fee: UInt64((valueSeed % 500) + 100),
                        timestamp: timestamp,
                        confirmed: index != 0,
                        direction: isIncoming ? .incoming : .outgoing
                    )
                }
            },
            buildPsbt: { _, _, _, _, _ in
                throw NSError(
                    domain: "BdkClient.mock",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "buildPsbt not implemented in mock"]
                )
            }
        )
    }
#endif

private actor BdkWarmUp {
    static let shared = BdkWarmUp()

    private var hasWarmed = false
    private var isRunning = false

    func run() async {
        guard !hasWarmed, !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        guard let url = URL(string: "https://mempool.space/api/blocks/tip/height") else {
            Log.cktap.error("Warm-up skipped: invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 3

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        configuration.timeoutIntervalForResource = 5

        let session = URLSession(configuration: configuration)

        let start = Date()
        Log.cktap.debug("Starting mempool warm-up request")
        do {
            let (_, response) = try await session.data(for: request)
            let elapsed = Date().timeIntervalSince(start)
            if let httpResponse = response as? HTTPURLResponse {
                Log.cktap.debug(
                    "Warm-up request completed: status=\(httpResponse.statusCode, privacy: .public) (\(String(format: "%.3f", elapsed))s)"
                )
            } else {
                Log.cktap.debug(
                    "Warm-up request completed (\(String(format: "%.3f", elapsed))s)"
                )
            }
            hasWarmed = true
        } catch {
            let elapsed = Date().timeIntervalSince(start)
            Log.cktap.error(
                "Warm-up request failed after \(String(format: "%.3f", elapsed))s: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
