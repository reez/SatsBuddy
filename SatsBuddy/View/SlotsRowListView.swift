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
        VStack(alignment: .leading, spacing: 12) {
            Text("Slots (\(totalSlots) total)")
                .font(.headline)
                .padding(.horizontal)

            LazyVStack(spacing: 8) {
                ForEach(slots) { slot in
                    SlotRowView(slot: slot)
                }
            }
        }
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

    SlotsRowListView(
        totalSlots: 10,
        slots: sampleSlots
    )
    .padding()
}
