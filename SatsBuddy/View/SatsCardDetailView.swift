//
//  SatsCardDetailView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/3/25.
//

import BitcoinUI
import Observation
import SwiftUI

struct SatsCardDetailView: View {
    let card: SatsCardInfo
    @State var viewModel: SatsCardDetailViewModel
    @Bindable var cardViewModel: SatsCardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var traceID = String(UUID().uuidString.prefix(6))
    @State private var labelText: String = ""
    @State private var isRenaming = false
    @State private var isShowingSend = false
    @State private var isShowingSetupSheet = false
    @State private var isShowingDeleteConfirm = false
    @State private var setupCvc: String = ""
    @State private var showToolbarSweep = false

    private var updatedCard: SatsCardInfo {
        cardViewModel.scannedCards.first(where: { $0.cardIdentifier == card.cardIdentifier })
            ?? card
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .zero) {
                ActiveSlotView(
                    slot: slotForDisplay,
                    card: updatedCard,
                    isLoading: viewModel.isLoading || isShowingPlaceholderSlot,
                    viewModel: viewModel,
                    isScanning: cardViewModel.isScanning,
                    onRefresh: {
                        cardViewModel.refreshCard(updatedCard)
                    },
                    onSetupNextSlot: needsNextSlotSetup ? { isShowingSetupSheet = true } : nil,
                    onSweepBalance: canSendFromActiveSlot ? { isShowingSend = true } : nil,
                    canSweepBalance: canSweepBalance,
                    isSweepButtonHidden: $showToolbarSweep,
                    price: cardViewModel.price
                )
                .padding(.horizontal)

                FooterView(updatedCard: updatedCard)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            .padding()
        }
        .refreshable {
            await viewModel.refreshBalance(
                for: updatedCard,
                traceID: String(UUID().uuidString.prefix(6))
            )
        }
        .coordinateSpace(name: "detailScroll")
        .navigationTitle(updatedCard.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isShowingSend) {
            SendFlowView(
                slot: slotForDisplay,
                card: updatedCard,
                onBroadcastSuccess: { refreshedCard in
                    let cardForReload =
                        refreshedCard.map { cardViewModel.applyCardSnapshot($0) } ?? updatedCard
                    viewModel.loadSlotDetails(for: cardForReload, traceID: traceID)
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if showToolbarSweep && canSendFromActiveSlot {
                    Button {
                        isShowingSend = true
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.footnote)
                            .foregroundStyle(canSweepBalance ? .primary : .secondary)
                            .frame(width: 30, height: 30)
                    }
                    .disabled(!canSweepBalance)
                    .animation(.easeInOut(duration: 0.2), value: showToolbarSweep)
                }
            }
        }
        .toolbarTitleMenu {
            Button("Rename Card") {
                prepareLabelForEditing()
                isRenaming = true
            }
            Button("Remove Card", role: .destructive) {
                isShowingDeleteConfirm = true
            }
        }
        .alert("Remove this card?", isPresented: $isShowingDeleteConfirm) {
            Button("Remove Card", role: .destructive) {
                cardViewModel.removeCard(updatedCard)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .task(id: loadTaskID, priority: .userInitiated) {
            Log.ui.info(
                "[\(traceID)] Detail task triggered for card \(updatedCard.cardIdentifier, privacy: .private(mask: .hash))"
            )
            let identifier = updatedCard.cardIdentifier
            await MainActor.run {
                cardViewModel.detailLoadingCardIdentifier = identifier
                viewModel.loadSlotDetails(for: updatedCard, traceID: traceID)
            }
            Log.ui.info("[\(traceID)] Detail task completed loadSlotDetails")
        }
        .sheet(isPresented: $isRenaming, onDismiss: { prepareLabelForEditing() }) {
            RenameCardSheet(
                initialText: labelText,
                fallbackName: fallbackName,
                onCancel: { isRenaming = false },
                onSave: { newValue in
                    applyLabelChange(newValue)
                    isRenaming = false
                }
            )
        }
        .sheet(isPresented: $isShowingSetupSheet, onDismiss: { setupCvc = "" }) {
            NavigationStack {
                Form {
                    Section("Activate next slot") {
                        TextField("Card CVC", text: $setupCvc)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                    }
                    Section {
                        Button("Continue") {
                            isShowingSetupSheet = false
                            cardViewModel.startSetupNextSlot(for: updatedCard, cvc: setupCvc)
                        }
                        .disabled(setupCvc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Cancel", role: .cancel) {
                            isShowingSetupSheet = false
                        }
                    }
                }
                .navigationTitle("Activate Next Slot")
            }
        }
        .onAppear {
            cardViewModel.refreshPrice()
            cardViewModel.detailLoadingCardIdentifier = updatedCard.cardIdentifier
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            let identifier = updatedCard.cardIdentifier
            if isLoading {
                cardViewModel.detailLoadingCardIdentifier = identifier
            } else if cardViewModel.detailLoadingCardIdentifier == identifier {
                cardViewModel.detailLoadingCardIdentifier = nil
            }
        }
        .onDisappear {
            if cardViewModel.detailLoadingCardIdentifier == updatedCard.cardIdentifier {
                cardViewModel.detailLoadingCardIdentifier = nil
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
            pubkey: "02e493dbf1c10d80f3581e4904930b1404cc6c13900ee0758474fa94abe8c4cd1351",
            activeSlot: 2,
            totalSlots: 10,
            slots: sampleSlots,
            isActive: true
        )

        SatsCardDetailView(
            card: sampleCard,
            viewModel: SatsCardDetailViewModel(),
            cardViewModel: SatsCardViewModel(
                ckTapService: .mock,
                cardsStore: .mock,
                priceClient: .mock
            )
        )
    }
#endif

extension SatsCardDetailView {
    private var activeSlot: SlotInfo? {
        viewModel.slots.first(where: { $0.isActive })
    }

    private var slotForDisplay: SlotInfo {
        activeSlot ?? placeholderSlot(for: updatedCard)
    }

    private var isShowingPlaceholderSlot: Bool {
        activeSlot == nil
    }

    private var needsNextSlotSetup: Bool {
        slotForDisplay.isActive && slotForDisplay.isUsed && slotForDisplay.address == nil
    }

    private var canSendFromActiveSlot: Bool {
        guard let address = slotForDisplay.address?.trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            return false
        }

        return !address.isEmpty
    }

    private var canSweepBalance: Bool {
        canSendFromActiveSlot && !viewModel.isSweepBalanceButtonDisabled
    }

    private func placeholderSlot(for card: SatsCardInfo) -> SlotInfo {
        SlotInfo(
            slotNumber: card.activeSlot ?? 0,
            isActive: true,
            isUsed: card.isActive,
            pubkey: card.pubkey,
            pubkeyDescriptor: nil,
            address: card.address,
            balance: nil
        )
    }

    private func prepareLabelForEditing() {
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

    private func applyLabelChange(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
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
            return
        }

        cardViewModel.updateLabel(for: updatedCard, to: trimmed)
    }

    private var fallbackName: String? {
        if let label = updatedCard.label,
            !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return label
        }
        if !updatedCard.pubkey.isEmpty {
            return updatedCard.pubkey
        }
        if let address = updatedCard.address, !address.isEmpty {
            return address
        }
        return nil
    }

    private var loadTaskID: String {
        let timestamp = updatedCard.dateScanned.timeIntervalSinceReferenceDate
        return "\(updatedCard.cardIdentifier)|\(timestamp)"
    }

}

private struct RenameCardSheet: View {
    @State private var text: String
    let fallbackName: String?
    let onCancel: () -> Void
    let onSave: (String) -> Void

    init(
        initialText: String,
        fallbackName: String?,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void
    ) {
        _text = State(initialValue: initialText)
        self.fallbackName = fallbackName
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Card Name") {
                    TextField(fallbackName ?? "Card name", text: $text)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit { onSave(text) }
                }
            }
            .navigationTitle("Rename Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(text) }
                }
            }
        }
    }
}
