//
//  SatsCardDetailView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/3/25.
//

import Observation
import SwiftUI

struct SatsCardDetailView: View {
    let card: SatsCardInfo
    @State private var viewModel = SatsCardDetailViewModel()
    @Bindable var cardViewModel: SatsCardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "creditcard.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.headline)

                            Text("SATSCARD")
                                .font(.headline)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Version \(card.version)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let activeSlot = card.activeSlot, let totalSlots = card.totalSlots {
                                Text("• Slot \(activeSlot)/\(totalSlots)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last updated: \(card.dateScanned, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("\(card.dateScanned.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .fontDesign(.monospaced)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                            .stroke(.quaternary, lineWidth: 1)
                    )

                    if let totalSlots = card.totalSlots {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Slots (\(totalSlots) total)")
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.slots) { slot in
                                    SlotRowView(slot: slot)
                                }
                            }
                        }
                    }

                    if viewModel.isLoading {
                        ProgressView("Loading slot details...")
                            .padding()
                    }
                    
                    HStack {
                        Text("Made in Nashville.")
                            .foregroundStyle(.secondary)
                            .fontDesign(.monospaced)
                            .font(.caption)
                    }
                }
                .padding()
            }
            .navigationTitle("SATSCARD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        cardViewModel.refreshCard(card)
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(cardViewModel.isScanning)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadSlotDetails(for: card)
        }
    }
}

#Preview {
    let sampleSlots = [
        SlotInfo(
            slotNumber: 0,
            isActive: false,
            isUsed: true,
            pubkey: "02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9388",
            pubkeyDescriptor:
                "wpkh(02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9388)",
            address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            balance: nil
        ),
        SlotInfo(
            slotNumber: 1,
            isActive: false,
            isUsed: true,
            pubkey: "03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c3b4",
            pubkeyDescriptor:
                "wpkh(03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c3b4)",
            address: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            balance: nil
        ),
        SlotInfo(
            slotNumber: 2,
            isActive: true,
            isUsed: true,
            pubkey: "02e493dbf1c10d80f3581e4904930b1404cc6c13900ee0758474fa94abe8c4cd1351",
            pubkeyDescriptor:
                "wpkh(02e493dbf1c10d80f3581e4904930b1404cc6c13900ee0758474fa94abe8c4cd1351)",
            address: "bc1qrp33g013ahg3pq0ny9kxwj42yl4xpr3xz4fzqc",
            balance: 21000
        ),
    ]

    let sampleCard = SatsCardInfo(
        version: "1.0.3",
        address: "bc1qrp33g013ahg3pq0ny9kxwj42yl4xpr3xz4fzqc",
        activeSlot: 2,
        totalSlots: 10,
        slots: sampleSlots,
        isActive: true
    )

    SatsCardDetailView(card: sampleCard, cardViewModel: SatsCardViewModel(ckTapService: .mock))
}
