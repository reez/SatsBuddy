//
//  ActiveSlotView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/25/25.
//

import SwiftUI
import UIKit

struct ActiveSlotView: View {
    let slot: SlotInfo
    let card: SatsCardInfo
    let isLoading: Bool

    @State private var copied = false

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
                List {
                    Section {
                        // Address row
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Address")
                                .foregroundStyle(.secondary)
                            Button {
                                UIPasteboard.general.string = address
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    copied = false
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(address)
                                            .truncationMode(.middle)
                                            .lineLimit(1)
                                            .foregroundColor(.primary)

                                        Spacer()

                                        if copied {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.green)
                                                .symbolEffect(.bounce, value: copied)
                                        }
                                    }
                                }
                            }
                            .sensoryFeedback(.success, trigger: copied)
                        }

                        // Pubkey row
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pubkey")
                                .foregroundStyle(.secondary)
                            Text(pubkey)
                                .truncationMode(.middle)
                                .lineLimit(1)
                        }

                        // Verify button row
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Explorer")
                                .foregroundStyle(.secondary)
                            Button {
                                if let url = URL(string: "https://mempool.space/address/\(address)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("View on mempool.space")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Section {
                        // Slot row
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Slot")
                                .foregroundStyle(.secondary)
                            Text("\(activeSlot)/\(totalSlots)")
                        }
                    }
                }
                .font(.caption)
                .listStyle(.insetGrouped)
                .scrollDisabled(true)
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
