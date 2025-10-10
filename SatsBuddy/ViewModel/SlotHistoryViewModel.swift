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
    var slotBalance: UInt64?
    var isLoading = false
    var errorMessage: String?

    init(bdkClient: BdkClient = .live) {
        self.bdkClient = bdkClient
    }

    @MainActor
    func loadHistory(for slot: SlotInfo, network: Network = .bitcoin) async {
        slotBalance = slot.balance
        let slotNumber = slot.slotNumber

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
        Log.cktap.info(
            "[\(traceID)] Loading history for slot \(slotNumber) address \(address, privacy: .private(mask: .hash))"
        )

        do {
            let fetched = try await bdkClient.getTransactionsForAddress(
                address,
                network,
                25
            )

            guard currentTaskID == taskID else { return }

            transactions = fetched
            Log.cktap.info(
                "[\(traceID)] Loaded \(fetched.count) transactions for slot \(slotNumber) address \(address, privacy: .private(mask: .hash))"
            )

            do {
                let balance = try await bdkClient.getBalanceFromAddress(address, network)
                guard currentTaskID == taskID else { return }
                slotBalance = balance.total.toSat()
                Log.cktap.info(
                    "[\(traceID)] Loaded balance for slot \(slotNumber): \(balance.total.toSat(), privacy: .private) sats"
                )
            } catch {
                Log.cktap.error(
                    "[\(traceID)] Failed to fetch balance: \(error.localizedDescription, privacy: .public)"
                )
            }

            isLoading = false
        } catch {
            guard currentTaskID == taskID else { return }

            Log.cktap.error(
                "[\(traceID)] Failed to fetch transactions: \(error.localizedDescription, privacy: .public)"
            )
            errorMessage = "Unable to load transactions."
            do {
                let balance = try await bdkClient.getBalanceFromAddress(address, network)
                guard currentTaskID == taskID else { return }
                slotBalance = balance.total.toSat()
                Log.cktap.info(
                    "[\(traceID)] Loaded balance for slot \(slotNumber) despite transaction error: \(balance.total.toSat(), privacy: .private) sats"
                )
            } catch {
                Log.cktap.error(
                    "[\(traceID)] Failed to fetch balance after transaction error: \(error.localizedDescription, privacy: .public)"
                )
            }
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
            viewModel.slotBalance = 125_000
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
