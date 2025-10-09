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

    var body: some View {
        List {
            Section {
                ForEach(slots) { slot in
                    Group {
                        if slot.isUsed, slot.address?.isEmpty == false {
                            SlotRowView(slot: slot) {
                                NavigationLink {
                                    SlotHistoryView(slot: slot)
                                } label: {
                                    HStack(spacing: 12) {
                                        Text("See Transactions")
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            SlotRowView(slot: slot)
                        }
                    }
                    .listRowInsets(
                        EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0)
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.horizontal, 4)
                }
            } header: {
                Text("Slots")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
            .textCase(nil)
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 12)
        .padding(.top, 8)
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
            slots: sampleSlots
        )
    }
}
