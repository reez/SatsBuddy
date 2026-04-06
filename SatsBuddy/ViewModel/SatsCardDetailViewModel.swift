//
//  SatsCardDetailViewModel.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/3/25.
//

import BitcoinDevKit
import Foundation
import Observation
import os

@Observable
class SatsCardDetailViewModel {
    var slots: [SlotInfo] = []
    var isLoading = false
    var errorMessage: String?
    var isSweepBalanceButtonDisabled = true
    var sweepBalanceDisabledMessage: String?
    var sweepBalanceDisabledLinkURL: URL?
    private let bdkClient: BdkClient
    private var currentFetchToken: UUID?
    private var balanceFetchTask: Task<Void, Never>?

    init(bdkClient: BdkClient = .live) {
        self.bdkClient = bdkClient
    }

    @MainActor
    func loadSlotDetails(for card: SatsCardInfo) {
        startBalanceFetch(for: card)
    }

    @MainActor
    func refreshBalance(for card: SatsCardInfo) async {
        let task = startBalanceFetch(for: card)
        await task?.value
    }

    @MainActor
    func applyPostBroadcastWarning(_ warningMessage: String?) {
        guard
            let warningMessage = warningMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
            !warningMessage.isEmpty
        else {
            return
        }

        guard
            let existingErrorMessage = errorMessage?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            !existingErrorMessage.isEmpty
        else {
            errorMessage = warningMessage
            return
        }

        if existingErrorMessage.contains(warningMessage) {
            errorMessage = existingErrorMessage
            return
        }

        errorMessage = "\(warningMessage)\n\(existingErrorMessage)"
    }

    @MainActor
    @discardableResult
    private func startBalanceFetch(for card: SatsCardInfo) -> Task<Void, Never>? {
        errorMessage = nil
        isLoading = true
        isSweepBalanceButtonDisabled = true
        sweepBalanceDisabledMessage = nil
        sweepBalanceDisabledLinkURL = nil

        slots = card.slots

        balanceFetchTask?.cancel()
        let fetchToken = UUID()
        currentFetchToken = fetchToken

        // Kick off balance fetching on a background task so navigation isn't blocked.
        let task = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.fetchBalanceForDisplayedSlot(
                card: card,
                fetchToken: fetchToken
            )
        }
        balanceFetchTask = task
        return task
    }

    private func fetchBalanceForDisplayedSlot(
        card: SatsCardInfo,
        fetchToken: UUID
    ) async {
        let shouldStart = await MainActor.run { () -> Bool in
            self.currentFetchToken == fetchToken
        }
        guard shouldStart else { return }
        defer {
            Task { @MainActor in
                if self.currentFetchToken == fetchToken {
                    self.balanceFetchTask = nil
                }
            }
        }

        guard let balanceAddress = balanceFetchAddress(for: card) else {
            await MainActor.run {
                if self.currentFetchToken == fetchToken {
                    self.isLoading = false
                    self.isSweepBalanceButtonDisabled = true
                    self.sweepBalanceDisabledMessage = nil
                    self.sweepBalanceDisabledLinkURL = nil
                }
            }
            return
        }

        do {
            let balance = try await bdkClient.getBalanceFromAddress(balanceAddress, .bitcoin)
            let pendingConfirmationLinkURL = await pendingConfirmationLinkURL(
                for: balanceAddress,
                balance: balance
            )

            if Task.isCancelled { return }
            let didUpdate = await MainActor.run { () -> Bool in
                guard self.currentFetchToken == fetchToken else {
                    self.isLoading = false
                    self.isSweepBalanceButtonDisabled = true
                    return false
                }

                let displayedSlotIndex =
                    if let displayedSlotNumber = self.displayedSlot(for: card)?.slotNumber {
                        self.slots.firstIndex(where: { $0.slotNumber == displayedSlotNumber })
                    } else if card.isExhausted {
                        self.slots.lastIndex(where: { $0.isUsed })
                    } else {
                        self.slots.firstIndex(where: { $0.isActive })
                    }

                if let displayedSlotIndex {
                    self.slots[displayedSlotIndex].balance = balance.total.toSat()
                }
                self.isLoading = false
                self.isSweepBalanceButtonDisabled = balance.sweepBalanceDisabled
                self.sweepBalanceDisabledMessage = balance.sweepBalanceDisabledMessage
                self.sweepBalanceDisabledLinkURL = pendingConfirmationLinkURL
                return displayedSlotIndex != nil
            }

            guard didUpdate else { return }
        } catch {
            Log.cktap.error("Balance fetch failed: \(error.localizedDescription, privacy: .public)")
            if Task.isCancelled { return }
            await MainActor.run {
                guard self.currentFetchToken == fetchToken else { return }
                self.errorMessage = "Failed to fetch balance: \(error.localizedDescription)"
                self.isLoading = false
                self.isSweepBalanceButtonDisabled = true
                self.sweepBalanceDisabledMessage = nil
                self.sweepBalanceDisabledLinkURL = nil
            }
        }
    }

    func balance(for slot: SlotInfo) -> UInt64 {
        slots.first(where: { $0.slotNumber == slot.slotNumber })?.balance ?? .zero
    }

    func getBalance(for address: String, network: Network) async {
        do {
            let balance = try await bdkClient.getBalanceFromAddress(address, network)
            await MainActor.run {
                if let index = self.slots.firstIndex(where: { $0.address == address }) {
                    self.slots[index].balance = balance.total.toSat()
                }
            }
        } catch {
            Log.cktap.error(
                "getBalance failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func balanceFetchAddress(for card: SatsCardInfo) -> String? {
        if let slotAddress = displayedSlot(for: card)?.address?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !slotAddress.isEmpty
        {
            return slotAddress
        }

        if let cardAddress = card.address?.trimmingCharacters(in: .whitespacesAndNewlines),
            !cardAddress.isEmpty
        {
            return cardAddress
        }

        return nil
    }

    private func displayedSlot(for card: SatsCardInfo) -> SlotInfo? {
        if let activeSlot = card.slots.first(where: { $0.isActive }) {
            return activeSlot
        }

        guard card.isExhausted else { return nil }
        return card.slots.last(where: { $0.isUsed })
    }

    private func pendingConfirmationLinkURL(
        for address: String,
        balance: Balance
    ) async -> URL? {
        guard balance.sweepBalanceDisabledMessage != nil else { return nil }

        do {
            let transactions = try await bdkClient.getTransactionsForAddress(address, .bitcoin, 25)
            let pendingTransaction =
                transactions.first(where: {
                    !$0.confirmed && $0.direction == .incoming
                }) ?? transactions.first(where: { !$0.confirmed })

            guard let txid = pendingTransaction?.txid else { return nil }
            return URL(string: "https://mempool.space/tx/\(txid)")
        } catch {
            Log.cktap.error(
                "Failed to fetch pending transaction link: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}
