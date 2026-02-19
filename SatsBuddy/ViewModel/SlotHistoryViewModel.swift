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
    var isSweepBalanceButtonDisabled = true

    init(bdkClient: BdkClient = .live) {
        self.bdkClient = bdkClient
    }

    func loadHistory(for slot: SlotInfo, network: Network = .bitcoin) async {
        guard let address = slot.address, !address.isEmpty else {
            await MainActor.run {
                self.errorMessage = "No address available for this slot."
                self.transactions = []
                self.slotBalance = slot.balance
            }
            return
        }

        let slotNumber = slot.slotNumber
        let taskID = UUID()
        let traceID = String(UUID().uuidString.prefix(6))

        await MainActor.run {
            self.slotBalance = slot.balance
            self.currentTaskID = taskID
            self.isLoading = true
            self.errorMessage = nil
        }

        Log.cktap.info(
            "[\(traceID)] Loading history for slot \(slotNumber) address \(address, privacy: .private(mask: .hash))"
        )

        do {
            let fetched = try await bdkClient.getTransactionsForAddress(
                address,
                network,
                25
            )

            let shouldContinue = await MainActor.run { () -> Bool in
                guard self.currentTaskID == taskID else { return false }
                self.transactions = fetched
                return true
            }

            guard shouldContinue else { return }

            Log.cktap.info(
                "[\(traceID)] Loaded \(fetched.count) transactions for slot \(slotNumber) address \(address, privacy: .private(mask: .hash))"
            )

            do {
                let balance = try await bdkClient.getBalanceFromAddress(address, network)
                await MainActor.run {
                    guard self.currentTaskID == taskID else { return }
                    self.slotBalance = balance.total.toSat()
                    isSweepBalanceButtonDisabled = balance.confirmed.toSat() == .zero
                    Log.cktap.info(
                        "[\(traceID)] Loaded balance for slot \(slotNumber): \(balance.total.toSat(), privacy: .private) sats"
                    )
                }
            } catch {
                Log.cktap.error(
                    "[\(traceID)] Failed to fetch balance: \(error.localizedDescription, privacy: .public)"
                )
            }

            await MainActor.run {
                if self.currentTaskID == taskID {
                    self.isLoading = false
                }
            }
        } catch {
            let didSetError = await MainActor.run { () -> Bool in
                guard self.currentTaskID == taskID else { return false }
                self.errorMessage = "Unable to load transactions."
                return true
            }

            guard didSetError else { return }

            Log.cktap.error(
                "[\(traceID)] Failed to fetch transactions: \(error.localizedDescription, privacy: .public)"
            )

            do {
                let balance = try await bdkClient.getBalanceFromAddress(address, network)
                await MainActor.run {
                    guard self.currentTaskID == taskID else { return }
                    self.slotBalance = balance.total.toSat()
                    Log.cktap.info(
                        "[\(traceID)] Loaded balance for slot \(slotNumber) despite transaction error: \(balance.total.toSat(), privacy: .private) sats"
                    )
                }
            } catch {
                Log.cktap.error(
                    "[\(traceID)] Failed to fetch balance after transaction error: \(error.localizedDescription, privacy: .public)"
                )
            }

            await MainActor.run {
                if self.currentTaskID == taskID {
                    self.isLoading = false
                }
            }
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
