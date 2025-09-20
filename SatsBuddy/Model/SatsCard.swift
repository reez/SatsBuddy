//
//  SatsCard.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/2/25.
//

import Foundation

struct SlotInfo: Identifiable {
    let id = UUID()
    let slotNumber: UInt8
    let isActive: Bool
    let isUsed: Bool
    let pubkey: String?
    let pubkeyDescriptor: String?
    let address: String?
    var balance: UInt64?
}

struct SatsCardInfo: Identifiable {
    let id = UUID()
    let version: String
    let birth: UInt64?  // Card birth timestamp - unique identifier
    let address: String?
    let pubkey: String?  // TODO: use this as the unique identifier
    let cardNonce: String?
    let activeSlot: UInt8?
    let totalSlots: UInt8?
    let isActive: Bool
    var dateScanned: Date  // Made mutable for refresh
    let slots: [SlotInfo]

    // Unique identifier for matching cards across scans
    var cardIdentifier: String {
        return "\(version)-\(birth ?? 0)-\(totalSlots ?? 0)"
    }

    init(
        version: String,
        birth: UInt64? = nil,
        address: String? = nil,
        pubkey: String? = nil,
        cardNonce: String? = nil,
        activeSlot: UInt8? = nil,
        totalSlots: UInt8? = nil,
        slots: [SlotInfo] = [],
        isActive: Bool = true
    ) {
        self.version = version
        self.birth = birth
        self.address = address
        self.pubkey = pubkey
        self.cardNonce = cardNonce
        self.activeSlot = activeSlot
        self.totalSlots = totalSlots
        self.slots = slots
        self.isActive = isActive
        self.dateScanned = Date()
    }
}
