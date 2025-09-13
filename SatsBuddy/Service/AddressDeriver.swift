//
//  AddressDeriver.swift
//  SatsBuddy
//

import BitcoinDevKit
import Foundation
import os

final class AddressDeriver {
    /// Derives the display address for a given slot descriptor.
    /// - Parameters:
    ///   - descriptor: A standard descriptor string from CKTap (e.g., "wpkh(<pubkey>)").
    ///   - network: The Bitcoin network (e.g., .bitcoin or .testnet).
    /// - Returns: The corresponding address string for external index 0.
    func deriveAddress(from descriptor: String, network: Network) throws -> String {
        // Parse the target descriptor from CKTap.
        let descriptor = try Descriptor(descriptor: descriptor, network: network)

        // BDK Wallet requires both an external (receive) and a change descriptor.
        // We only need to derive the first external address, but we still must
        // supply a valid change descriptor. Any static single-key descriptor works.
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
