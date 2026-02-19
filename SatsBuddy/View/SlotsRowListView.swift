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
    let price: Price?
    let card: SatsCardInfo

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
                                price: price,
                                card: card
                            )
                        } label: {
                            SlotSummaryRowView(slot: slot)
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

private struct SlotsCard<Content: View>: View {
    private let content: Content
    private let contentPadding: CGFloat

    init(contentPadding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.contentPadding = contentPadding
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(contentPadding)
            .background(
                shape
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.45))
            )
            .overlay(
                shape
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .clipShape(shape)
    }
}

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
    ]

    NavigationStack {
        SlotsRowListView(
            totalSlots: 10,
            slots: sampleSlots,
            price: Price(
                time: 1_734_000_000,
                usd: 89_000,
                eur: 82_000,
                gbp: 70_000,
                cad: 120_000,
                chf: 80_000,
                aud: 130_000,
                jpy: 13_700_000
            ),
            card: SatsCardInfo(version: "1", pubkey: "1234")
        )
    }
}
