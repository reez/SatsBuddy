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

    init(
        slot: SlotInfo,
        network: Network = .bitcoin,
        viewModel: SlotHistoryViewModel = SlotHistoryViewModel()
    ) {
        self.slot = slot
        self.network = network
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Slot \(slot.slotNumber)")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let address = slot.address, !address.isEmpty {
                        HStack(spacing: 12) {
                            Text(address)
                                .font(.callout)
                                .fontDesign(.monospaced)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer(minLength: 80)
                        }
                    }
                }

                TransactionsSectionView(
                    slot: slot,
                    network: network,
                    viewModel: viewModel,
                    onOpenMempool: { openOnMempool(txid: $0) }
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .task(id: slot.id) {
            await viewModel.loadHistory(for: slot, network: network)
        }
        .refreshable {
            await viewModel.loadHistory(for: slot, network: network)
        }
        .onDisappear {
            viewModel.cancel()
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
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.transactions) { transaction in
                        Button {
                            onOpenMempool(transaction.txid)
                        } label: {
                            TransactionRowView(
                                transaction: transaction,
                                onOpenMempool: onOpenMempool
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct TransactionRowView: View {
    let transaction: SlotTransaction
    let onOpenMempool: (String) -> Void

    var body: some View {
        HistoryCard {
            HStack(alignment: .center, spacing: 16) {
                Circle()
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.6))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: iconName)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(iconColor)
                    )

                VStack(alignment: .leading, spacing: 6) {
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
                        Image(systemName: "globe")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                        Text("Verify on mempool.space")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                }

                Spacer()

                TransactionAmountView(amount: transaction.amount)
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

    var body: some View {
        HStack(spacing: 4) {
            Text(prefix)
                .font(.callout.weight(.semibold))
            Image(systemName: "bitcoinsign")
                .font(.caption.weight(.semibold))
            Text(valueString)
                .font(.callout.weight(.semibold))
        }
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
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                shape
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.45))
            )
            .overlay(
                shape
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .clipShape(shape)
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
#endif
