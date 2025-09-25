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
    @State private var labelText: String = ""
    @FocusState private var isLabelFieldFocused: Bool

    // Get the updated card from the cardViewModel's scannedCards array
    private var updatedCard: SatsCardInfo {
        cardViewModel.scannedCards.first(where: { $0.cardIdentifier == card.cardIdentifier })
            ?? card
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Card name", text: $labelText)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.weight(.semibold))
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .focused($isLabelFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { commitLabelChange() }

                Text("Add a friendly card name (optional)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let activeSlot = viewModel.slots.first(where: { $0.isActive }) {
                ActiveSlotView(slot: activeSlot, card: updatedCard, isLoading: viewModel.isLoading)
            } else if viewModel.isLoading {
                ProgressView("Loading slot details...")
                    .padding()
            }

            FooterView(updatedCard: updatedCard)
                .padding(.top, 40)
        }
        .padding()
        .navigationTitle(updatedCard.displayName)
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
            syncLabelText()
        }
        .onChange(of: updatedCard.dateScanned) { newValue in
            Log.ui.info(
                "[\(traceID)] updatedCard.dateScanned changed -> \(newValue.formatted(date: .omitted, time: .standard))"
            )
            viewModel.loadSlotDetails(for: updatedCard, traceID: traceID)
        }
        .onChange(of: updatedCard.label) { _ in
            syncLabelText()
        }
        .onChange(of: updatedCard.pubkey) { _ in
            syncLabelText()
        }
        .onChange(of: isLabelFieldFocused) { focused in
            if !focused {
                commitLabelChange()
            }
        }
    }
}

#if DEBUG
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
        cardViewModel: SatsCardViewModel(ckTapService: .mock, cardsStore: .mock)
    )
}
#endif

extension SatsCardDetailView {
    private func syncLabelText() {
        if let label = updatedCard.label,
           !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            labelText = label
        } else if let fallback = fallbackName {
            labelText = fallback
        } else {
            labelText = ""
        }
    }

    private func commitLabelChange() {
        let trimmed = labelText.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = updatedCard.label ?? ""

        if trimmed == current { return }

        if trimmed.isEmpty {
            cardViewModel.updateLabel(for: updatedCard, to: trimmed)
            return
        }

        if updatedCard.label == nil,
           let fallback = fallbackName,
           trimmed == fallback
        {
            // User left the default identifier; keep storage clean.
            syncLabelText()
            return
        }

        cardViewModel.updateLabel(for: updatedCard, to: trimmed)
    }

    private var fallbackName: String? {
        if let pubkey = updatedCard.pubkey, !pubkey.isEmpty {
            return pubkey
        }
        if let address = updatedCard.address, !address.isEmpty {
            return address
        }
        return nil
    }
}
