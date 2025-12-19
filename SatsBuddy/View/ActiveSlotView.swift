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
    let isScanning: Bool
    let onRefresh: () -> Void
    let price: Price?

    @AppStorage("balanceDisplayFormat") private var balanceFormat: BalanceDisplayFormat = .bip177
    @State private var copied = false
    @State private var isCardIdCopied = false
    @State private var receiveSheetState: ReceiveSheetState?
    @State private var isPreparingReceiveSheet = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 32) {
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

                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 20, height: 20)
                        .opacity(isLoading ? 1 : 0)
                        .accessibilityHidden(!isLoading)
                    Spacer()
                }
                .font(.largeTitle)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .padding()
                .animation(.smooth, value: slot.balance)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        let formats = BalanceDisplayFormat.allCases
                        balanceFormat = formats[(balanceFormat.index + 1) % formats.count]
                    }
                }
                .sensoryFeedback(.selection, trigger: balanceFormat)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
            }

            Spacer()

            List {
                Section {

                    Button {
                        guard let address = displayAddress else { return }

                        isPreparingReceiveSheet = true
                        receiveSheetState = ReceiveSheetState(address: address)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Receive")
                                .foregroundStyle(.secondary)
                            HStack(alignment: .center) {
                                Text(displayAddress ?? "No address")
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer(minLength: 80)

                                if isPreparingReceiveSheet {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "qrcode")
                                        .foregroundColor(.blue)
                                        .font(.footnote)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .buttonStyle(.plain)
                    .disabled(displayAddress == nil)

                    // Card ID row
                    Button {
                        UIPasteboard.general.string = card.cardIdentifier
                        isCardIdCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isCardIdCopied = false
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Card ID")
                                .foregroundStyle(.secondary)
                            HStack(alignment: .center) {
                                Text(card.cardIdentifier)
                                    .truncationMode(.middle)
                                    .lineLimit(1)

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
                    .disabled(card.cardIdentifier.isEmpty)

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

                                Spacer(minLength: 80)

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

                Section {
                    NavigationLink {
                        SlotsRowListView(
                            totalSlots: card.totalSlots ?? UInt8(clamping: viewModel.slots.count),
                            slots: viewModel.slots,
                            price: price
                        )
                        .navigationTitle("All Slots")
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Slot")
                                .foregroundStyle(.secondary)
                            Text(slotPositionText)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.vertical, 8)
                    .disabled(card.totalSlots == nil)

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

                                Spacer(minLength: 80)

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
            .listStyle(.plain)
            .scrollDisabled(true)
            .animation(.smooth, value: isLoading)
            .sheet(
                item: $receiveSheetState,
                onDismiss: {
                    isPreparingReceiveSheet = false
                }
            ) { sheetState in
                ReceiveView(
                    address: sheetState.address,
                    isCopied: $copied
                )
                .onAppear {
                    isPreparingReceiveSheet = false
                }
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
            pubkey: slot.pubkey
                ?? "03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c",
            activeSlot: 1,
            totalSlots: 10,
            slots: [slot],
            isActive: true
        )
        let fiatStore = Price(
            time: 1_734_000_000,
            usd: 89_000,
            eur: 82_000,
            gbp: 70_000,
            cad: 120_000,
            chf: 80_000,
            aud: 130_000,
            jpy: 13_700_000
        )

        return ActiveSlotView(
            slot: slot,
            card: card,
            isLoading: false,
            viewModel: SatsCardDetailViewModel(),
            isScanning: false,
            onRefresh: {},
            price: fiatStore
        )
        .padding()
    }
#endif

private struct ReceiveSheetState: Identifiable {
    let id = UUID()
    let address: String
}

extension ActiveSlotView {
    private var formattedBalance: String {
        let amount = slot.balance ?? 0
        return balanceFormat.formatted(amount, price: price)
    }

    fileprivate var displayAddress: String? {
        slot.address ?? card.address
    }

    fileprivate var displayPubkey: String {
        slot.pubkey ?? card.pubkey
    }

    fileprivate var slotPositionText: String {
        if let activeSlot = card.activeSlot,
            let totalSlots = card.totalSlots
        {
            return "\(activeSlot)/\(totalSlots)"
        }

        if let totalSlots = card.totalSlots {
            return "\(slot.slotNumber)/\(totalSlots)"
        }

        return "--/--"
    }

    fileprivate var refreshTimestampText: String {
        card.dateScanned.formatted(date: .abbreviated, time: .shortened)
    }
}
