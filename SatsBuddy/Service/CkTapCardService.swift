//
//  CkTapCardService.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/8/25.
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
    private struct ActiveSlotSnapshot {
        let state: SlotState
        let isUsed: Bool
        let pubkey: String?
        let descriptor: String?
        let address: String?
    }

    let addressDeriver: BdkClient
    let network: Network

    init(addressDeriver: BdkClient, network: Network) {
        self.addressDeriver = addressDeriver
        self.network = network
    }

    static func defaultMainnet() -> CkTapCardService {
        CkTapCardService(addressDeriver: .live, network: .bitcoin)
    }
    static func defaultTestnet() -> CkTapCardService {
        CkTapCardService(addressDeriver: .live, network: .testnet)
    }

    /// Advance a SATSCARD to the next slot (CVC required) and return updated card info.
    func setupNextSlot(transport: CkTransport, cvc: String) async throws -> SatsCardInfo {
        let cardType = try await CKTap.toCktap(transport: transport)

        switch cardType {
        case .satsCard(let card):
            let liveStatus = await card.status()
            if Self.shouldVerifyAuthenticity(activeSlotAddress: liveStatus.addr) {
                try await SatsCardAuthenticityVerifier.verify(card)
            }
            try await card.newSlot(cvc: cvc)
            return try await readSatsCard(card)

        case .tapSigner(_):
            throw CkTapCardError.unsupportedCard("TAPSIGNER not supported")

        case .satsChip(_):
            throw CkTapCardError.unsupportedCard("SATSCHIP not supported")
        }
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
        let cardType = try await CKTap.toCktap(transport: transport)

        switch cardType {
        case .satsCard(let card):
            let liveStatus = await card.status()
            if Self.shouldVerifyAuthenticity(activeSlotAddress: liveStatus.addr) {
                try await SatsCardAuthenticityVerifier.verify(card)
            }
            return try await readSatsCard(card)

        case .tapSigner(_):
            throw CkTapCardError.unsupportedCard("TAPSIGNER not supported")

        case .satsChip(_):
            throw CkTapCardError.unsupportedCard("SATSCHIP not supported")
        }
    }

    static func shouldVerifyAuthenticity(activeSlotAddress: String?) -> Bool {
        guard let activeSlotAddress else { return false }
        return !activeSlotAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func readSatsCard(_ card: CKTap.SatsCard) async throws -> SatsCardInfo {
        let status = await card.status()

        // Active slot address:
        // The active slot is sealed and `dump(slot:)` will usually fail without a CVC.
        // CKTap provides `card.address()` to fetch its address directly without unsealing.
        var currentAddress: String?
        do {
            currentAddress = try await card.address()
        } catch {
            Log.cktap.error(
                "card.address() failed (activeSlot=\(status.activeSlot)): \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }

        var slots: [SlotInfo] = []
        for slotNumber in 0..<status.numSlots {
            let isActive = status.activeSlot == slotNumber
            let isHistorical = slotNumber < status.activeSlot

            var slotPubkey: String?
            var slotAddress: String?
            var slotDescriptor: String?
            let slotState: SlotState
            let isUsed: Bool

            if !isActive, isHistorical {
                isUsed = true
                slotState = .historical
                // `dump(slot:)`
                //  - For used, unsealed slots (historical slots), this returns `pubkey` and
                //    `pubkeyDescriptor` which we can use to derive the exact on-chain address
                //    the slot generated.
                do {
                    let details = try await card.dump(slot: slotNumber, cvc: nil)
                    slotPubkey = details.pubkey
                    slotDescriptor = details.pubkeyDescriptor

                    // Derive the address we show the user from the descriptor of unsealed slots.
                    if let descriptor = slotDescriptor, !descriptor.isEmpty {
                        slotAddress = deriveAddress(for: descriptor, slotNumber: slotNumber)
                    }
                } catch {
                    Log.cktap.error(
                        "dump(slot:) failed for slot \(slotNumber): \(error.localizedDescription, privacy: .private(mask: .hash))"
                    )
                }
            } else if isActive {
                let activeSlot = await readActiveSlot(
                    card,
                    slotNumber: slotNumber,
                    currentAddress: currentAddress
                )
                isUsed = activeSlot.isUsed
                slotState = activeSlot.state
                slotPubkey = activeSlot.pubkey
                slotDescriptor = activeSlot.descriptor
                slotAddress = activeSlot.address
            } else {
                isUsed = false
                slotState = .unused
            }

            let slotInfo = SlotInfo(
                slotNumber: slotNumber,
                isActive: isActive,
                isUsed: isUsed,
                pubkey: slotPubkey,
                pubkeyDescriptor: slotDescriptor,
                address: slotAddress,
                balance: nil,
                state: slotState
            )
            slots.append(slotInfo)
        }

        return SatsCardInfo(
            version: status.ver.isEmpty ? "Unknown" : status.ver,
            birth: status.birth,
            address: currentAddress,
            pubkey: status.pubkey,
            cardIdent: status.cardIdent,
            activeSlot: status.activeSlot,
            totalSlots: status.numSlots,
            slots: slots,
            isActive: true
        )
    }

    private func deriveAddress(for descriptor: String, slotNumber: UInt8) -> String? {
        do {
            return try addressDeriver.deriveAddress(descriptor, network)
        } catch {
            Log.cktap.error(
                "Derive address failed for slot \(slotNumber): \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
            return nil
        }
    }

    private func readActiveSlot(
        _ card: CKTap.SatsCard,
        slotNumber: UInt8,
        currentAddress: String?
    ) async -> ActiveSlotSnapshot {
        var slotAddress = currentAddress
        var slotPubkey: String?
        var slotDescriptor: String?

        do {
            let dump = try await card.dump(slot: slotNumber, cvc: nil)
            slotPubkey = dump.pubkey
            slotDescriptor = dump.pubkeyDescriptor
            if let descriptor = slotDescriptor, !descriptor.isEmpty {
                slotAddress = slotAddress ?? deriveAddress(for: descriptor, slotNumber: slotNumber)
            }

            return ActiveSlotSnapshot(
                state: .activeNeedsSetup,
                isUsed: true,
                pubkey: slotPubkey,
                descriptor: slotDescriptor,
                address: slotAddress
            )
        } catch let dumpError as DumpError {
            switch dumpError {
            case .SlotSealed:
                if let descriptor = try? await card.read(), !descriptor.isEmpty {
                    slotDescriptor = descriptor
                    slotAddress =
                        slotAddress ?? deriveAddress(for: descriptor, slotNumber: slotNumber)
                }

                return ActiveSlotSnapshot(
                    state: .activeReady,
                    isUsed: true,
                    pubkey: slotPubkey,
                    descriptor: slotDescriptor,
                    address: slotAddress
                )

            case .SlotUnused:
                return ActiveSlotSnapshot(
                    state: .unused,
                    isUsed: false,
                    pubkey: nil,
                    descriptor: nil,
                    address: nil
                )

            case .SlotTampered:
                Log.cktap.error("Active slot \(slotNumber) was reported as tampered.")
                return ActiveSlotSnapshot(
                    state: .activeNeedsSetup,
                    isUsed: true,
                    pubkey: nil,
                    descriptor: nil,
                    address: nil
                )

            case .Key, .CkTap:
                break
            }
        } catch {
            Log.cktap.error(
                "Unable to inspect active slot \(slotNumber): \(error.localizedDescription, privacy: .public)"
            )
        }

        let fallbackState: SlotState = SlotInfo(
            slotNumber: slotNumber,
            isActive: true,
            isUsed: true,
            pubkey: nil,
            pubkeyDescriptor: nil,
            address: currentAddress,
            balance: nil
        ).state

        return ActiveSlotSnapshot(
            state: fallbackState,
            isUsed: fallbackState != .unused,
            pubkey: slotPubkey,
            descriptor: slotDescriptor,
            address: slotAddress
        )
    }
}
