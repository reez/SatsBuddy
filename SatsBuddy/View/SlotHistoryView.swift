//
//  SlotHistoryView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 10/10/25.
//

import BitcoinDevKit
import BitcoinUI
import Observation
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct SlotHistoryView: View {
    let slot: SlotInfo
    let network: Network
    let card: SatsCardInfo
    let priceStore: PriceStore
    @State private var viewModel: SlotHistoryViewModel
    @State private var slotDetails: SlotInfo
    @State private var isShowingSend = false
    @State private var isRefreshingBalanceAfterBroadcast = false

    init(
        slot: SlotInfo,
        network: Network = .bitcoin,
        viewModel: SlotHistoryViewModel = SlotHistoryViewModel(),
        card: SatsCardInfo,
        priceStore: PriceStore
    ) {
        let displaySlot =
            card.displaySlots.first(where: { $0.slotNumber == slot.slotNumber }) ?? slot

        self.slot = displaySlot
        self.network = network
        self.card = card
        self.priceStore = priceStore
        _slotDetails = State(initialValue: displaySlot)
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SlotRowView(slot: slotDetails, priceStore: priceStore)
                        .overlay(alignment: .topTrailing) {
                            if isRefreshingBalanceAfterBroadcast {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.secondary)
                                    .padding(.top, 10)
                                    .padding(.trailing, 4)
                            }
                        }

                    TransactionsSectionView(
                        slot: slotDetails,
                        network: network,
                        viewModel: viewModel,
                        priceStore: priceStore,
                        onOpenMempool: { openOnMempool(txid: $0) }
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await viewModel.loadHistory(for: slotDetails, network: network)
            }

            Button {
                isShowingSend = true
            } label: {
                Text("Sweep balance")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.all, 8)
            }
            .buttonStyle(
                BitcoinFilled(
                    tintColor: .primary,
                    textColor: Color(uiColor: .systemBackground),
                    isCapsule: true
                )
            )
            .padding()
            .accessibilityLabel("Sweep balance")
            .disabled(viewModel.isSweepBalanceButtonDisabled)
        }
        .navigationTitle("Slot \(slot.displaySlotNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: slot.id) {
            await viewModel.loadHistory(for: slotDetails, network: network)
        }
        .onDisappear {
            viewModel.cancel()
        }
        .onChange(of: viewModel.slotBalance) { _, newValue in
            if slotDetails.balance != newValue {
                slotDetails.balance = newValue
            }
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            if !isLoading {
                isRefreshingBalanceAfterBroadcast = false
            }
        }
        .navigationDestination(isPresented: $isShowingSend) {
            SendFlowView(
                slot: slotDetails,
                card: card,
                onBroadcastSuccess: { _ in
                    isRefreshingBalanceAfterBroadcast = true
                    Task {
                        await viewModel.loadHistory(for: slotDetails, network: network)
                    }
                }
            )
        }
    }
}

extension SlotHistoryView {
    fileprivate func openOnMempool(txid: String) {
        guard let url = URL(string: "\(mempoolBaseURL())/tx/\(txid)") else { return }
        #if canImport(UIKit)
            UIApplication.shared.open(url)
        #endif
    }

    fileprivate func mempoolBaseURL() -> String {
        switch network {
        case .bitcoin:
            return "https://mempool.space"
        case .testnet:
            return "https://mempool.space/testnet"
        case .testnet4:
            return "https://mempool.space/testnet4"
        case .signet:
            return "https://mempool.space/signet"
        case .regtest:
            return "http://localhost:3000"
        @unknown default:
            return "https://mempool.space"
        }
    }
}

private struct TransactionsSectionView: View {
    let slot: SlotInfo
    let network: Network
    @Bindable var viewModel: SlotHistoryViewModel
    let priceStore: PriceStore
    let onOpenMempool: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transactions")
                .font(.headline)
                .foregroundStyle(.secondary)

            if viewModel.isLoading {
                HistoryCard {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if let error = viewModel.errorMessage {
                HistoryCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(error)
                            .foregroundStyle(.red)
                        if viewModel.canRetryCurrentError {
                            Button("Retry") {
                                Task {
                                    await viewModel.loadHistory(for: slot, network: network)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            } else if viewModel.transactions.isEmpty {
                HistoryCard {
                    Text("No transactions yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.transactions.enumerated()), id: \.element.id) {
                        index,
                        transaction in
                        Button {
                            onOpenMempool(transaction.txid)
                        } label: {
                            TransactionRowView(
                                transaction: transaction,
                                priceStore: priceStore,
                                onOpenMempool: onOpenMempool
                            )
                        }
                        .buttonStyle(.plain)

                        if index < viewModel.transactions.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.06))
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding()
            }
        }
        .padding(.top)
    }
}

private struct TransactionRowView: View {
    let transaction: SlotTransaction
    let priceStore: PriceStore
    let onOpenMempool: (String) -> Void

    var body: some View {
        HistoryCard {

            VStack(alignment: .leading, spacing: 12) {

                TransactionAmountView(amount: transaction.amount, priceStore: priceStore)

                Text(timestampLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "square.bottomhalf.filled")
                        .font(.caption.weight(.semibold))
                    Text("mempool.space")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.up.forward")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundStyle(.tertiary)
                }

                Divider()
                    .padding(.top)
            }

        }
    }

    private var iconName: String {
        transaction.direction == .incoming ? "arrow.down" : "arrow.up"
    }

    private var iconColor: Color {
        .primary
    }

    private var timestampLabel: String {
        if let timestamp = transaction.timestamp {
            return timestamp.formatted(date: .abbreviated, time: .shortened)
        }
        return transaction.confirmed ? "Confirmed" : "Pending confirmation"
    }

    private var truncatedTxid: String { transaction.txid }
}

private struct TransactionAmountView: View {
    let amount: Int64
    let priceStore: PriceStore
    @AppStorage("balanceDisplayFormat") private var balanceFormat: BalanceDisplayFormat = .bip177
    private var price: Price? { priceStore.price }

    var body: some View {
        HStack(spacing: 4) {
            Text(signPrefix)
            let prefix = balanceFormat.displayPrefix(price: price)
            if !prefix.isEmpty {
                Text(prefix)
            }
            Text(valueString)
            let displayText = balanceFormat.displayText(price: price)
            if !displayText.isEmpty {
                Text(displayText)
                    .foregroundStyle(.secondary)
            }
        }
        .fontWeight(.semibold)
    }

    private var signPrefix: String {
        amount > 0 ? "+" : amount < 0 ? "−" : ""
    }

    private var valueString: String {
        balanceFormat.formatted(UInt64(abs(amount)), price: price)
    }
}

private struct HistoryCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
        //            .padding(20)
    }
}

#if DEBUG
    #Preview {
        let slot = SlotInfo(
            slotNumber: 1,
            isActive: true,
            isUsed: true,
            pubkey: "03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c",
            pubkeyDescriptor: nil,
            address: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            balance: 125_000
        )

        NavigationStack {
            SlotHistoryView(
                slot: slot,
                viewModel: SlotHistoryViewModel.previewMock(),
                card: SatsCardInfo(version: "1", pubkey: "1234"),
                priceStore: PriceStore()
            )
        }
    }
    #Preview {
        TransactionAmountView(amount: Int64(2500), priceStore: PriceStore())
    }
#endif
