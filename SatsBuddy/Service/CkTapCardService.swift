//
//  CkTapCardService.swift
//  SatsBuddy
//
//  Created by Codex CLI on 9/8/25.
//

import BitcoinDevKit
import CKTap
import Foundation
import os

enum CkTapCardError: LocalizedError {
    case unsupportedCard(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedCard(let message):
            return message
        }
    }
}

final class CkTapCardService {
    let addressDeriver: BdkClient
    let network: Network

    init(addressDeriver: BdkClient, network: Network) {
        self.addressDeriver = addressDeriver
        self.network = network
    }

    // Default factories for convenience where DI is not wired explicitly
    static func defaultMainnet() -> CkTapCardService {
        CkTapCardService(addressDeriver: .live, network: .bitcoin)
    }
    static func defaultTestnet() -> CkTapCardService {
        CkTapCardService(addressDeriver: .live, network: .testnet)
    }

    /// Reads a card via CKTap and returns the aggregated `SatsCardInfo` that the UI consumes.
    ///
    /// High level:
    /// - Identify card type (SatsCard/TapSigner/SatsChip)
    /// - For SatsCard:
    ///   - Use `status()` for basic metadata (version, slots, etc.)
    ///   - Use `address()` only for the currently active (sealed) slot
    ///   - For each used slot: call `dump(slot:)` to get pubkey + descriptor
    ///   - For unsealed historical slots: derive real addresses via BDK (BdkClient)
    func readCardInfo(transport: CkTransport) async throws -> SatsCardInfo {
        Log.cktap.info("Reading card info via CKTap…")
        let cardType = try await CKTap.toCktap(transport: transport)

        switch cardType {
        case .satsCard(let card):
            return try await readSatsCard(card)

        case .tapSigner(_):
            Log.cktap.info("TapSigner detected")
            throw CkTapCardError.unsupportedCard("TAPSIGNER not supported")

        case .satsChip(_):
            Log.cktap.info("SatsChip detected")
            throw CkTapCardError.unsupportedCard("SATSCHIP not supported")
        }
    }

    private func readSatsCard(_ card: CKTap.SatsCard) async throws -> SatsCardInfo {
        let status = await card.status()
        Log.cktap.debug("status.ver -> \(status.ver, privacy: .public)")
        Log.cktap.debug("status slots -> active: \(status.activeSlot), total: \(status.numSlots)")

        // Active slot address:
        // The active slot is sealed and `dump(slot:)` will usually fail without a CVC.
        // CKTap provides `card.address()` to fetch its address directly without unsealing.
        var currentAddress: String?
        do {
            currentAddress = try await card.address()
            Log.cktap.debug("card.address() -> \(currentAddress ?? "nil", privacy: .public)")
        } catch {
            Log.cktap.error(
                "card.address() failed: \(error.localizedDescription, privacy: .public)"
            )
        }

        var slots: [SlotInfo] = []
        for slotNumber in 0..<status.numSlots {
            let isActive = status.activeSlot == slotNumber
            let isUsed = slotNumber <= status.activeSlot

            var slotPubkey: String?
            var slotAddress: String?
            var slotDescriptor: String?

            if isUsed {
                // `dump(slot:)`
                //  - For used, unsealed slots (historical slots), this returns `pubkey` and
                //    `pubkeyDescriptor` which we can use to derive the exact on-chain address
                //    the slot generated.
                //  - For the currently active slot (sealed), this usually fails without a CVC.
                //    In that case, we fall back to the address obtained via `card.address()` above.
                do {
                    let details = try await card.dump(slot: slotNumber, cvc: nil)
                    slotPubkey = details.pubkey
                    slotDescriptor = details.pubkeyDescriptor

                    // Derive the address we show the user from the descriptor of unsealed slots.
                    if let descriptor = slotDescriptor, !descriptor.isEmpty {
                        do {
                            slotAddress = try addressDeriver.deriveAddress(
                                descriptor,
                                network
                            )
                            Log.cktap.debug(
                                "Derived address for slot \(slotNumber): \(slotAddress!, privacy: .public)"
                            )
                        } catch {
                            Log.cktap.error(
                                "Derive address failed for slot \(slotNumber): \(error.localizedDescription, privacy: .public)"
                            )
                        }
                    }
                } catch {
                    Log.cktap.error(
                        "dump(slot:) failed for slot \(slotNumber): \(error, privacy: .public)"
                    )
                    // Sealed active slot fallback: use `card.address()` value if dump fails.
                    if isActive { slotAddress = currentAddress }
                }
            }

            let slotInfo = SlotInfo(
                slotNumber: slotNumber,
                isActive: isActive,
                isUsed: isUsed,
                pubkey: slotPubkey,
                pubkeyDescriptor: slotDescriptor,
                address: slotAddress
            )
            slots.append(slotInfo)
        }

        return SatsCardInfo(
            version: status.ver.isEmpty ? "Unknown" : status.ver,
            birth: status.birth,
            address: currentAddress,
            activeSlot: status.activeSlot,
            totalSlots: status.numSlots,
            slots: slots,
            isActive: true
        )
    }
}
