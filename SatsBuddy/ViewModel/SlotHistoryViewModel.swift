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
    var canRetryCurrentError = false
    var isSweepBalanceButtonDisabled = true
    var slot: SlotInfo?

    init(bdkClient: BdkClient = .live) {
        self.bdkClient = bdkClient
    }

    func loadHistory(for slot: SlotInfo, network: Network = .bitcoin) async {
        guard let address = slot.address, !address.isEmpty else {
            await MainActor.run {
                self.currentTaskID = nil
                self.errorMessage = self.missingAddressMessage(for: slot)
                self.transactions = []
                self.slotBalance = slot.balance
                self.isLoading = false
                self.canRetryCurrentError = false
                self.isSweepBalanceButtonDisabled = true
            }
            return
        }
        self.slot = slot
        let slotNumber = slot.slotNumber
        let taskID = UUID()
        let traceID = String(UUID().uuidString.prefix(6))

        await MainActor.run {
            self.slotBalance = slot.balance
            self.currentTaskID = taskID
            self.isLoading = true
            self.errorMessage = nil
            self.canRetryCurrentError = false
            self.isSweepBalanceButtonDisabled = true
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

            await getBalance(for: address, network: network)

            await MainActor.run {
                if self.currentTaskID == taskID {
                    self.isLoading = false
                }
            }
        } catch {
            let didSetError = await MainActor.run { () -> Bool in
                guard self.currentTaskID == taskID else { return false }
                self.errorMessage = "Unable to load transactions."
                self.canRetryCurrentError = true
                self.isSweepBalanceButtonDisabled = true
                return true
            }

            guard didSetError else { return }

            Log.cktap.error(
                "[\(traceID)] Failed to fetch transactions: \(error.localizedDescription, privacy: .public)"
            )

            await getBalance(for: address, network: network)

            await MainActor.run {
                if self.currentTaskID == taskID {
                    self.isLoading = false
                }
            }
        }
    }

    func getBalance(for address: String, network: Network) async {
        do {
            let balance = try await bdkClient.getBalanceFromAddress(address, network)
            await MainActor.run {
                self.slotBalance = balance.total.toSat()
                self.isSweepBalanceButtonDisabled = balance.sweepBalanceDisabled
            }
        } catch {
            Log.cktap.error(
                "getBalance failed: \(error.localizedDescription, privacy: .public)"
            )
            await MainActor.run {
                self.isSweepBalanceButtonDisabled = true
            }
        }
    }

    func cancel() {
        currentTaskID = nil
    }

    private func missingAddressMessage(for slot: SlotInfo) -> String {
        if !slot.isUsed {
            return "This slot has not been used yet."
        }

        if slot.isActive {
            return "This slot isn't ready yet. Go back and activate it before receiving."
        }

        return "No address available for this slot."
    }
}

extension Balance {
    var sweepBalanceDisabled: Bool {
        confirmed.toSat() == .zero || total.toSat() == .zero
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
