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
    private init(deriveAddress: @escaping (String, Network) throws -> String) {
        self.deriveAddress = deriveAddress
    }
}

extension BdkClient {
    static let live = Self(deriveAddress: { descriptor, network in
        try BdkService().deriveAddress(descriptor: descriptor, network: network)
    })
}

#if DEBUG
    extension BdkClient {
        static let mock = Self(deriveAddress: { descriptor, _ in
            let seed = abs(descriptor.hashValue) % 3
            switch seed {
            case 0: return "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
            case 1: return "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"
            default: return "bc1qrp33g013ahg3pq0ny9kxwj42yl4xpr3xz4fzqc"
            }
        })
    }
#endif
