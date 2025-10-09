//
//  SlotHistoryViewModel.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 10/10/25.
//

import BitcoinDevKit
import Foundation
import Observation
import os

@Observable
final class SlotHistoryViewModel {
    private let bdkClient: BdkClient
    private var currentTaskID: UUID?

    var transactions: [SlotTransaction] = []
    var isLoading = false
    var errorMessage: String?

    init(bdkClient: BdkClient = .live) {
        self.bdkClient = bdkClient
    }

    @MainActor
    func loadHistory(for slot: SlotInfo, network: Network = .bitcoin) async {
        guard let address = slot.address, !address.isEmpty else {
            errorMessage = "No address available for this slot."
            transactions = []
            return
        }

        let taskID = UUID()
        currentTaskID = taskID
        isLoading = true
        errorMessage = nil

        let traceID = String(UUID().uuidString.prefix(6))
        Log.cktap.info("[\(traceID)] Loading transactions for address \(address, privacy: .public)")

        do {
            let fetched = try await bdkClient.getTransactionsForAddress(
                address,
                network,
                25
            )

            guard currentTaskID == taskID else { return }

            transactions = fetched
            isLoading = false
            Log.cktap.info(
                "[\(traceID)] Loaded \(fetched.count, privacy: .public) transactions for address \(address, privacy: .public)"
            )
        } catch {
            guard currentTaskID == taskID else { return }

            Log.cktap.error(
                "[\(traceID)] Failed to fetch transactions: \(error.localizedDescription, privacy: .public)"
            )
            errorMessage = "Unable to load transactions."
            isLoading = false
        }
    }

    func cancel() {
        currentTaskID = nil
    }
}

#if DEBUG
    extension SlotHistoryViewModel {
        static func previewMock(transactions: [SlotTransaction] = sampleTransactions())
            -> SlotHistoryViewModel
        {
            let viewModel = SlotHistoryViewModel(bdkClient: .mock)
            viewModel.transactions = transactions
            return viewModel
        }

        static func sampleTransactions() -> [SlotTransaction] {
            [
                SlotTransaction(
                    txid: "mock-tx-1",
                    amount: 42_000,
                    fee: 210,
                    timestamp: Date(),
                    confirmed: true,
                    direction: .incoming
                ),
                SlotTransaction(
                    txid: "mock-tx-2",
                    amount: -12_500,
                    fee: 180,
                    timestamp: Date().addingTimeInterval(-86_400),
                    confirmed: true,
                    direction: .outgoing
                ),
                SlotTransaction(
                    txid: "mock-tx-3",
                    amount: 0,
                    fee: 120,
                    timestamp: Date().addingTimeInterval(-172_800),
                    confirmed: false,
                    direction: .incoming
                ),
            ]
        }
    }
#endif
