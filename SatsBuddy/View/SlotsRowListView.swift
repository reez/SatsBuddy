//
//  SlotsRowListView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/8/25.
//

import SwiftUI

struct SlotsRowListView: View {
    let totalSlots: UInt8
    let slots: [SlotInfo]
    let card: SatsCardInfo
    let viewModel: SatsCardDetailViewModel
    let priceStore: PriceStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Slots")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                LazyVStack(spacing: 0) {
                    ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                        NavigationLink {
                            SlotHistoryView(
                                slot: slot,
                                card: card,
                                priceStore: priceStore
                            )
                        } label: {
                            SlotSummaryRowView(
                                slot: slot,
                                viewModel: viewModel,
                                priceStore: priceStore
                            )
                            .padding(.vertical, 32)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if index < slots.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.06))
                        }
                    }
                }
                .padding(16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

#if DEBUG
    #Preview {
        let sampleSlots: [SlotInfo] = [
            SlotInfo(
                slotNumber: 0,
                isActive: false,
                isUsed: true,
                pubkey: "02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f",
                pubkeyDescriptor:
                    "wpkh(02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f)",
                address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
                balance: nil
            ),
            SlotInfo(
                slotNumber: 1,
                isActive: true,
                isUsed: true,
                pubkey: "03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c",
                pubkeyDescriptor:
                    "wpkh(03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c)",
                address: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
                balance: 100000
            ),
            SlotInfo(
                slotNumber: 2,
                isActive: false,
                isUsed: false,
                pubkey: nil,
                pubkeyDescriptor: nil,
                address: nil,
                balance: nil
            ),
        ]

        NavigationStack {
            SlotsRowListView(
                totalSlots: 10,
                slots: sampleSlots,
                card: SatsCardInfo(version: "1", pubkey: "1234"),
                viewModel: SatsCardDetailViewModel(bdkClient: .mock),
                priceStore: PriceStore()
            )
        }
    }
#endif
