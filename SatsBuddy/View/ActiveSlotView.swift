//
//  ActiveSlotView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/25/25.
//

import SwiftUI

struct ActiveSlotView: View {
    let slot: SlotInfo
    let card: SatsCardInfo
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 32) {
                HStack {
                    Image(systemName: "bitcoinsign")
                        .font(.title)
                        .fontWeight(.regular)
                        .foregroundStyle(.secondary)
                    Text(slot.balance?.formatted(.number.grouping(.automatic)) ?? "1,234")
                        .redacted(reason: slot.balance == nil ? .placeholder : [])
                }
                .font(.largeTitle)
                .fontWeight(.bold)
                .fontDesign(.rounded)
            }

            Spacer()

            if let address = slot.address,
                let activeSlot = card.activeSlot,
                let totalSlots = card.totalSlots,
                let pubkey = card.pubkey
            {
                AddressView(
                    address: address,
                    activeSlot: activeSlot,
                    totalSlots: totalSlots,
                    pubkey: pubkey
                )
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.secondary, lineWidth: 1)
                )
            }

            Spacer()
        }
    }
}

#if DEBUG
    #Preview {
        let slot = SlotInfo(
            slotNumber: 1,
            isActive: true,
            isUsed: true,
            pubkey: "03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c",
            pubkeyDescriptor:
                "wpkh(03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c)",
            address: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            balance: 50_000
        )

        let card = SatsCardInfo(
            version: "1.0.3",
            address: slot.address,
            activeSlot: 1,
            totalSlots: 10,
            slots: [slot],
            isActive: true
        )

        return ActiveSlotView(slot: slot, card: card, isLoading: false)
            .padding()
    }
#endif
