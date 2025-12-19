//
//  SlotHistoryView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 10/10/25.
//

import BitcoinDevKit
import Observation
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct SlotHistoryView: View {
    let slot: SlotInfo
    let network: Network
    let price: Price?
    @State private var viewModel: SlotHistoryViewModel
    @State private var slotDetails: SlotInfo

    init(
        slot: SlotInfo,
        network: Network = .bitcoin,
        price: Price?,
        viewModel: SlotHistoryViewModel = SlotHistoryViewModel()
    ) {
        self.slot = slot
        self.network = network
        self.price = price
        _slotDetails = State(initialValue: slot)
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SlotRowView(slot: slotDetails, price: price)

                TransactionsSectionView(
                    slot: slotDetails,
                    network: network,
                    viewModel: viewModel,
                    price: price,
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
        .navigationTitle("Slot \(slot.slotNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: slot.id) {
            await viewModel.loadHistory(for: slotDetails, network: network)
        }
        .onDisappear {
            viewModel.cancel()
        }
        .onChange(of: viewModel.slotBalance) { newValue in
            if slotDetails.balance != newValue {
                slotDetails.balance = newValue
            }
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
    let price: Price?
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
                        Button("Retry") {
                            Task {
                                await viewModel.loadHistory(for: slot, network: network)
                            }
                        }
                        .buttonStyle(.borderedProminent)
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
                                price: price,
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
    let price: Price?
    let onOpenMempool: (String) -> Void

    var body: some View {
        HistoryCard {

            VStack(alignment: .leading, spacing: 12) {

                TransactionAmountView(amount: transaction.amount, price: price)

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
    @AppStorage("balanceDisplayFormat") private var balanceFormat: BalanceDisplayFormat = .bip177
    let price: Price?

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

        return NavigationStack {
            SlotHistoryView(
                slot: slot,
                price: fiatStore,
                viewModel: SlotHistoryViewModel.previewMock()
            )
        }
    }
    #Preview {
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
        return TransactionAmountView(amount: Int64(2500), price: fiatStore)
    }
#endif
