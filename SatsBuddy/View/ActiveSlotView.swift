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
    let viewModel: SatsCardDetailViewModel
    let priceStore: PriceStore
    let isScanning: Bool
    let onRefresh: () -> Void
    let onSetupNextSlot: (() -> Void)?
    let onSweepBalance: (() -> Void)?
    let canSweepBalance: Bool
    @Binding var isSweepButtonHidden: Bool

    @AppStorage("balanceDisplayFormat") private var balanceFormat: BalanceDisplayFormat = .bip177

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 8)

            BalanceHeaderView(
                slot: slot,
                isLoading: isLoading,
                balanceFormat: $balanceFormat,
                errorMessage: viewModel.errorMessage,
                priceStore: priceStore
            )

            if let onSweepBalance {
                Button {
                    onSweepBalance()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")

                        Text("Sweep Balance")
                            .bold()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .foregroundStyle(canSweepBalance ? .primary : .secondary)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            canSweepBalance ? Color.primary : Color.secondary.opacity(0.35),
                            lineWidth: 1
                        )
                }
                .opacity(canSweepBalance ? 1 : 0.65)
                .disabled(!canSweepBalance)
                .onGeometryChange(for: Bool.self) { proxy in
                    proxy.frame(in: .named("detailScroll")).maxY < 0
                } action: { hidden in
                    isSweepButtonHidden = hidden
                }

                if let sweepBalanceDisabledMessage = viewModel.sweepBalanceDisabledMessage {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sweepBalanceDisabledMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let sweepBalanceDisabledLinkURL = viewModel.sweepBalanceDisabledLinkURL {
                            Text(
                                .init(
                                    "[mempool.space](\(sweepBalanceDisabledLinkURL.absoluteString))"
                                )
                            )
                            .font(.footnote)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            VStack(spacing: 0) {
                ReceiveRow(
                    displayAddress: receiveAddress,
                    onSetupNextSlot: onSetupNextSlot,
                    exhaustedMessage: exhaustedReceiveMessage
                )

                Divider()

                CardIdRow(cardIdentifier: card.cardIdentifier)

                Divider()

                ExplorerRow(displayAddress: explorerAddress)

                Divider()
                    .padding(.vertical, 8)

                SlotNavigationRow(
                    slotPositionText: slotPositionText,
                    card: card,
                    viewModel: viewModel,
                    priceStore: priceStore
                )

                Divider()

                RefreshRow(
                    refreshTimestampText: refreshTimestampText,
                    isScanning: isScanning,
                    onRefresh: onRefresh
                )
            }
            .animation(.smooth, value: isLoading)

            Spacer()
        }
    }
}

// MARK: - Subviews

private struct BalanceHeaderView: View {
    let slot: SlotInfo
    let isLoading: Bool
    @Binding var balanceFormat: BalanceDisplayFormat
    let errorMessage: String?
    let priceStore: PriceStore
    private var price: Price? { priceStore.price }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 15) {
                if balanceFormat.showsBitcoinSymbol {
                    Image(systemName: "bitcoinsign")
                        .foregroundStyle(.secondary)
                        .font(.title)
                        .fontWeight(.thin)
                } else if balanceFormat == .fiat {
                    let symbol = balanceFormat.displayPrefix(price: price)
                    if !symbol.isEmpty {
                        Text(symbol)
                            .foregroundStyle(.secondary)
                            .font(.title)
                            .fontWeight(.thin)
                    }
                }

                Text(formattedBalance)
                    .contentTransition(.numericText(countsDown: true))
                    .opacity(slot.balance == nil ? 0.3 : 1)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8),
                        value: balanceFormat
                    )

                Text(balanceFormat.displayText(price: price))
                    .foregroundStyle(.secondary)
                    .font(.title)
                    .fontWeight(.thin)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
                    .id("format-\(balanceFormat)")
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.7),
                        value: balanceFormat
                    )

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 20, height: 20)
                        .opacity(isLoading ? 1 : 0)
                        .accessibilityHidden(!isLoading)
                }
            }
            .font(.largeTitle)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .fontWeight(.bold)
            .fontDesign(.rounded)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.smooth, value: slot.balance)
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    let formats = BalanceDisplayFormat.allCases
                    balanceFormat = formats[(balanceFormat.index + 1) % formats.count]
                }
            }
            .sensoryFeedback(.selection, trigger: balanceFormat)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
        }
    }

    private var formattedBalance: String {
        let amount = slot.balance ?? 0
        return balanceFormat.formatted(amount, price: price)
    }
}

private struct ReceiveRow: View {
    let displayAddress: String?
    let onSetupNextSlot: (() -> Void)?
    let exhaustedMessage: String?

    @State private var isPreparingReceiveSheet = false
    @State private var receiveSheetState: ReceiveSheetState?
    @State private var copied = false

    var body: some View {
        if exhaustedMessage != nil {
            VStack(alignment: .leading, spacing: 4) {
                Text("Receive")
                    .foregroundStyle(.secondary)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All slots used")
                            .foregroundStyle(.primary)
                    }

                    Spacer(minLength: 12)
                }
            }
            .padding(.vertical, 8)
        } else if displayAddress == nil, let onSetupNextSlot {
            Button(action: onSetupNextSlot) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Receive")
                        .foregroundStyle(.secondary)
                    HStack(alignment: .center) {
                        Text("Activate next slot")
                            .foregroundStyle(.primary)

                        Spacer(minLength: 12)

                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.blue)
                            .font(.footnote)
                            .fontWeight(.bold)
                    }
                }
            }
            .padding(.vertical, 8)
            .buttonStyle(.plain)
        } else {
            Button {
                guard let address = displayAddress else { return }
                isPreparingReceiveSheet = true
                receiveSheetState = ReceiveSheetState(address: address)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Receive")
                        .foregroundStyle(.secondary)
                    HStack(alignment: .top) {
                        Text(displayAddress ?? "No address")
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer(minLength: 80)

                        if isPreparingReceiveSheet {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "qrcode")
                                .foregroundStyle(.blue)
                                .font(.footnote)
                                .fontWeight(.bold)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .buttonStyle(.plain)
            .disabled(displayAddress == nil)
            .sheet(
                item: $receiveSheetState,
                onDismiss: { isPreparingReceiveSheet = false }
            ) { sheetState in
                ReceiveView(address: sheetState.address, isCopied: $copied)
                    .onAppear { isPreparingReceiveSheet = false }
            }
        }
    }
}

private struct CardIdRow: View {
    let cardIdentifier: String

    @State private var isCardIdCopied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = cardIdentifier
            isCardIdCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isCardIdCopied = false
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Card ID")
                    .foregroundStyle(.secondary)
                HStack(alignment: .top) {
                    Text(cardIdentifier)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 80)

                    Image(systemName: isCardIdCopied ? "checkmark" : "doc.on.doc")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundStyle(isCardIdCopied ? .green : .blue)
                        .symbolEffect(.bounce, value: isCardIdCopied)
                }
            }
        }
        .padding(.vertical, 8)
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: isCardIdCopied) { _, newValue in
            newValue
        }
        .disabled(cardIdentifier.isEmpty)
    }
}

private struct ExplorerRow: View {
    let displayAddress: String?

    var body: some View {
        Button {
            guard let address = displayAddress else { return }
            if let url = URL(string: "https://mempool.space/address/\(address)") {
                UIApplication.shared.open(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Explorer")
                    .foregroundStyle(.secondary)
                HStack(alignment: .center) {
                    HStack {
                        Image(systemName: "square.bottomhalf.filled")
                            .font(.body)
                        Text("mempool.space")
                            .foregroundColor(.primary)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "arrow.up.right")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .padding(.vertical, 8)
        .buttonStyle(.plain)
        .disabled(displayAddress == nil)
    }
}

private struct SlotNavigationRow: View {
    let slotPositionText: String
    let card: SatsCardInfo
    let viewModel: SatsCardDetailViewModel
    let priceStore: PriceStore

    var body: some View {
        NavigationLink {
            SlotsRowListView(
                totalSlots: card.totalSlots ?? UInt8(clamping: viewModel.slots.count),
                slots: viewModel.slots,
                card: card,
                viewModel: viewModel,
                priceStore: priceStore
            )
            .navigationTitle("All Slots")
            .navigationBarTitleDisplayMode(.inline)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Slot")
                        .foregroundStyle(.secondary)
                    Text(slotPositionText)
                        .foregroundColor(.primary)
                }
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .foregroundColor(.secondary)
        .padding(.vertical, 8)
        .disabled(card.totalSlots == nil)
    }
}

private struct RefreshRow: View {
    let refreshTimestampText: String
    let isScanning: Bool
    let onRefresh: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
            onRefresh()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Card Refresh")
                    .foregroundStyle(.secondary)
                HStack(alignment: .center) {
                    Text(refreshTimestampText)
                        .foregroundColor(.primary)

                    Spacer(minLength: 12)

                    if isScanning {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "wave.3.up")
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .padding(.vertical, 8)
        .buttonStyle(.plain)
        .disabled(isScanning)
    }
}

// MARK: - Helpers

private struct ReceiveSheetState: Identifiable {
    let id = UUID()
    let address: String
}

extension ActiveSlotView {
    fileprivate var receiveAddress: String? {
        guard slot.isReadyToReceive else { return nil }
        return slot.receiveAddress ?? normalizedAddress(card.address)
    }

    fileprivate var exhaustedReceiveMessage: String? {
        guard card.isExhausted else { return nil }
        return ""
    }

    fileprivate var explorerAddress: String? {
        slot.normalizedAddress ?? normalizedAddress(card.address)
    }

    fileprivate var displayPubkey: String {
        slot.pubkey ?? card.pubkey
    }

    fileprivate var slotPositionText: String {
        if let slotProgressText = card.displaySlotProgressText {
            return slotProgressText
        }

        if let totalSlots = card.totalSlots {
            return "\(slot.displaySlotNumber)/\(totalSlots)"
        }

        return "--/--"
    }

    fileprivate var refreshTimestampText: String {
        card.dateScanned.formatted(date: .abbreviated, time: .shortened)
    }

    private func normalizedAddress(_ address: String?) -> String? {
        guard let address = address?.trimmingCharacters(in: .whitespacesAndNewlines),
            !address.isEmpty
        else {
            return nil
        }

        return address
    }
}

// MARK: - Preview

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
            pubkey: slot.pubkey
                ?? "03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c",
            activeSlot: 1,
            totalSlots: 10,
            slots: [slot],
            isActive: true
        )
        ActiveSlotView(
            slot: slot,
            card: card,
            isLoading: false,
            viewModel: SatsCardDetailViewModel(),
            priceStore: PriceStore(),
            isScanning: false,
            onRefresh: {},
            onSetupNextSlot: nil,
            onSweepBalance: {},
            canSweepBalance: true,
            isSweepButtonHidden: .constant(false)
        )
        .padding()
    }
#endif
