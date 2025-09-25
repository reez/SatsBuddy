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
    @State var viewModel: SatsCardDetailViewModel
    @Bindable var cardViewModel: SatsCardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var traceID = String(UUID().uuidString.prefix(6))

    // Get the updated card from the cardViewModel's scannedCards array
    private var updatedCard: SatsCardInfo {
        cardViewModel.scannedCards.first(where: { $0.cardIdentifier == card.cardIdentifier })
            ?? card
    }

    var body: some View {
        VStack {
            if let activeSlot = viewModel.slots.first(where: { $0.isActive }) {
                VStack(spacing: 16) {
                    Spacer()

                    // Balance
                    if let balance = activeSlot.balance {
                        VStack(spacing: 32) {
                            HStack {
                                Image(systemName: "bitcoinsign")
                                    .font(.title)
                                    .fontWeight(.regular)
                                    .foregroundStyle(.secondary)
                                Text("\(balance.formatted(.number.grouping(.automatic)))")
                            }
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)

                            Text(
                                "\(updatedCard.dateScanned.formatted(date: .omitted, time: .standard))"
                            )
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .fontDesign(.monospaced)
                        }
                    } else if viewModel.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading balance...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Address
                    if let address = activeSlot.address,
                       let activeSlot = updatedCard.activeSlot,
                       let totalSlots = updatedCard.totalSlots
                    {
                        VStack(spacing: 8) {
                            Text("Slot \(activeSlot)/\(totalSlots)")

                            Button {
                                UIPasteboard.general.string = address
                            } label: {
                                Text(address)
                                    .fontDesign(.monospaced)
                                    .truncationMode(.middle)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                            }
                            .buttonStyle(.plain)

                            Button {
                                if let url = URL(
                                    string: "https://mempool.space/address/\(address)"
                                ) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Verify on mempool.space")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        .font(.callout)
                    }

                    Spacer()
                }
            } else if viewModel.isLoading {
                ProgressView("Loading slot details...")
                    .padding()
            }

            VStack {
                Text("SATSCARD • Version \(updatedCard.version)")
                Text("SATSBUDDY • Made in Nashville.")
            }
            .foregroundStyle(.secondary)
            .fontDesign(.monospaced)
            .font(.caption)
            .padding(.top, 40)
        }
        .padding()
        .navigationTitle("SATSCARD")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    cardViewModel.refreshCard(card)
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(cardViewModel.isScanning)
            }
        }
        .onAppear {
            Log.ui.info(
                "[\(traceID)] Detail onAppear for card: \(updatedCard.cardIdentifier, privacy: .public)"
            )
            viewModel.loadSlotDetails(for: updatedCard, traceID: traceID)
            DispatchQueue.main.async {
                Log.ui.info("[\(traceID)] Main queue tick after loadSlotDetails return")
            }
        }
        .onChange(of: updatedCard.dateScanned) { newValue in
            Log.ui.info(
                "[\(traceID)] updatedCard.dateScanned changed -> \(newValue.formatted(date: .omitted, time: .standard))"
            )
            viewModel.loadSlotDetails(for: updatedCard, traceID: traceID)
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

    SatsCardDetailView(
        card: sampleCard,
        viewModel: SatsCardDetailViewModel(),
        cardViewModel: SatsCardViewModel(ckTapService: .mock)
    )
}
