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
    @State private var viewModel: SlotHistoryViewModel
    @State private var slotDetails: SlotInfo

    init(
        slot: SlotInfo,
        network: Network = .bitcoin,
        viewModel: SlotHistoryViewModel = SlotHistoryViewModel()
    ) {
        self.slot = slot
        self.network = network
        _slotDetails = State(initialValue: slot)
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SlotRowView(slot: slotDetails)

                TransactionsSectionView(
                    slot: slotDetails,
                    network: network,
                    viewModel: viewModel,
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
    let onOpenMempool: (String) -> Void

    var body: some View {
        HistoryCard {
            //            HStack(alignment: .center, spacing: 16) {
            //                Circle()
            //                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.6))
            //                    .frame(width: 36, height: 36)
            //                    .overlay(
            //                        Image(systemName: iconName)
            //                            .font(.footnote.weight(.semibold))
            //                            .foregroundStyle(iconColor)
            //                    )

            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.bottom)

                TransactionAmountView(amount: transaction.amount)

                Text(truncatedTxid)
                    .font(.callout)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(timestampLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "square.bottomhalf.filled")
                        .font(.caption.weight(.semibold))
                    //                            .foregroundStyle(.blue)
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

            //                Spacer()
            //
            //                TransactionAmountView(amount: transaction.amount)

            //            }
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

    var body: some View {
        HStack(spacing: 4) {
            Text(prefix)
            //                .font(.callout.weight(.semibold))
            Image(systemName: "bitcoinsign")
                //                .font(.caption.weight(.semibold))
                .font(.caption)
            Text(valueString)
            //                .font(.callout.weight(.semibold))
        }
        .fontWeight(.semibold)
    }

    private var prefix: String {
        amount > 0 ? "+" : amount < 0 ? "−" : ""
    }

    private var valueString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = Locale.current.groupingSeparator
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: abs(amount))) ?? "\(abs(amount))"
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

        return NavigationStack {
            SlotHistoryView(
                slot: slot,
                viewModel: SlotHistoryViewModel.previewMock()
            )
        }
    }
    #Preview {
        TransactionAmountView(amount: Int64(2500))
    }
#endif
