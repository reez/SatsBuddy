//
//  SatsCard.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/2/25.
//

import Foundation

enum SlotState: String, Codable, Equatable {
    case unused
    case activeReady
    case activeNeedsSetup
    case historical

    var lifecycleLabel: String {
        switch self {
        case .activeReady:
            return "Sealed"
        case .activeNeedsSetup, .unused:
            return "Unused"
        case .historical:
            return "Unsealed"
        }
    }

    static func inferred(
        isActive: Bool,
        isUsed: Bool,
        address: String?
    ) -> SlotState {
        if !isUsed {
            return .unused
        }

        if isActive {
            return normalizedAddress(address) == nil ? .activeNeedsSetup : .activeReady
        }

        return .historical
    }

    private static func normalizedAddress(_ address: String?) -> String? {
        guard let address = address?.trimmingCharacters(in: .whitespacesAndNewlines),
            !address.isEmpty
        else {
            return nil
        }

        return address
    }
}

struct SlotInfo: Identifiable, Codable {
    let id: UUID
    let slotNumber: UInt8
    let isActive: Bool
    let isUsed: Bool
    let pubkey: String?
    let pubkeyDescriptor: String?
    let address: String?
    var balance: UInt64?
    let state: SlotState

    private enum CodingKeys: String, CodingKey {
        case id
        case slotNumber
        case isActive
        case isUsed
        case pubkey
        case pubkeyDescriptor
        case address
        case balance
        case state
    }

    init(
        id: UUID = UUID(),
        slotNumber: UInt8,
        isActive: Bool,
        isUsed: Bool,
        pubkey: String?,
        pubkeyDescriptor: String?,
        address: String?,
        balance: UInt64? = nil,
        state: SlotState? = nil
    ) {
        self.id = id
        self.slotNumber = slotNumber
        self.isActive = isActive
        self.isUsed = isUsed
        self.pubkey = pubkey
        self.pubkeyDescriptor = pubkeyDescriptor
        self.address = address
        self.balance = balance
        self.state =
            state
            ?? SlotState.inferred(
                isActive: isActive,
                isUsed: isUsed,
                address: address
            )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let slotNumber = try container.decode(UInt8.self, forKey: .slotNumber)
        let isActive = try container.decode(Bool.self, forKey: .isActive)
        let isUsed = try container.decode(Bool.self, forKey: .isUsed)
        let pubkey = try container.decodeIfPresent(String.self, forKey: .pubkey)
        let pubkeyDescriptor = try container.decodeIfPresent(String.self, forKey: .pubkeyDescriptor)
        let address = try container.decodeIfPresent(String.self, forKey: .address)
        let balance = try container.decodeIfPresent(UInt64.self, forKey: .balance)
        let state =
            try container.decodeIfPresent(SlotState.self, forKey: .state)
            ?? SlotState.inferred(
                isActive: isActive,
                isUsed: isUsed,
                address: address
            )

        self.init(
            id: id,
            slotNumber: slotNumber,
            isActive: isActive,
            isUsed: isUsed,
            pubkey: pubkey,
            pubkeyDescriptor: pubkeyDescriptor,
            address: address,
            balance: balance,
            state: state
        )
    }

    var displaySlotNumber: Int {
        Int(slotNumber) + 1
    }

    var normalizedAddress: String? {
        guard let address = address?.trimmingCharacters(in: .whitespacesAndNewlines),
            !address.isEmpty
        else {
            return nil
        }

        return address
    }

    var isReadyToReceive: Bool {
        isActive && state == .activeReady
    }

    var needsSetupToReceive: Bool {
        isActive && (state == .activeNeedsSetup || state == .unused)
    }

    var receiveAddress: String? {
        guard isReadyToReceive else { return nil }
        return normalizedAddress
    }

    var requiresUnsealBeforeSweep: Bool {
        isActive && state == .activeReady
    }

    var shouldActivateNextSlotAfterSweep: Bool {
        isActive && state != .unused
    }

    var showsCurrentBadge: Bool {
        isActive
    }

    var lifecycleBadgeText: String {
        state.lifecycleLabel
    }
}

struct SatsCardInfo: Identifiable, Codable {
    let id: UUID
    let version: String
    let birth: UInt64?  // Card birth timestamp - unique identifier
    let address: String?
    let pubkey: String
    let cardIdent: String?
    let cardNonce: String?
    let activeSlot: UInt8?
    let totalSlots: UInt8?
    let isActive: Bool
    var dateScanned: Date  // Made mutable for refresh
    var label: String?
    let slots: [SlotInfo]

    init(
        id: UUID = UUID(),
        version: String,
        birth: UInt64? = nil,
        address: String? = nil,
        pubkey: String,
        cardIdent: String? = nil,
        cardNonce: String? = nil,
        activeSlot: UInt8? = nil,
        totalSlots: UInt8? = nil,
        slots: [SlotInfo] = [],
        isActive: Bool = true,
        dateScanned: Date = Date(),
        label: String? = nil
    ) {
        self.id = id
        self.version = version
        self.birth = birth
        self.address = address
        self.pubkey = pubkey
        self.cardIdent = cardIdent
        self.cardNonce = cardNonce
        self.activeSlot = activeSlot
        self.totalSlots = totalSlots
        self.slots = slots
        self.isActive = isActive
        self.dateScanned = dateScanned
        self.label = label
    }

    var displayName: String {
        if let trimmedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmedLabel.isEmpty
        {
            return trimmedLabel
        }
        if !pubkey.isEmpty {
            return pubkey
        }
        if let address, !address.isEmpty {
            return address
        }
        return "SATSCARD"
    }

    /// Stable hardware identifier exposed by CKTap, used to merge scans.
    var cardIdentifier: String { cardIdent ?? pubkey }

    var isExhausted: Bool {
        guard let activeSlot, let totalSlots else { return false }
        return activeSlot >= totalSlots
    }

    var displayActiveSlotNumber: Int? {
        guard let activeSlot else { return nil }
        if let totalSlots, activeSlot >= totalSlots {
            return nil
        }
        return Int(activeSlot) + 1
    }
}
