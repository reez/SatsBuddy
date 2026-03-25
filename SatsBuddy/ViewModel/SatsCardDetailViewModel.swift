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
    private let bdkClient: BdkClient
    private var currentFetchToken: UUID?
    private var balanceFetchTask: Task<Void, Never>?

    init(bdkClient: BdkClient = .live) {
        self.bdkClient = bdkClient
    }

    @MainActor
    func loadSlotDetails(for card: SatsCardInfo, traceID: String? = nil) {
        startBalanceFetch(for: card, traceID: traceID)
    }

    @MainActor
    func refreshBalance(for card: SatsCardInfo, traceID: String? = nil) async {
        let task = startBalanceFetch(for: card, traceID: traceID)
        await task?.value
    }

    @MainActor
    @discardableResult
    private func startBalanceFetch(for card: SatsCardInfo, traceID: String? = nil)
        -> Task<Void, Never>?
    {
        errorMessage = nil
        isLoading = true
        isSweepBalanceButtonDisabled = true

        slots = card.slots

        let traceID = traceID ?? String(UUID().uuidString.prefix(6))
        let loadStart = Date()
        Log.cktap.info(
            "[\(traceID)] loadSlotDetails started for card \(card.cardIdentifier, privacy: .private(mask: .hash))"
        )
        Log.cktap.debug(
            "[\(traceID)] Slots copied to detail view (count: \(card.slots.count))"
        )

        balanceFetchTask?.cancel()
        let fetchToken = UUID()
        currentFetchToken = fetchToken

        // Kick off balance fetching on a background task so navigation isn't blocked.
        let task = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.fetchBalanceForActiveSlot(
                card: card,
                loadStartedAt: loadStart,
                traceID: traceID,
                fetchToken: fetchToken
            )
        }
        balanceFetchTask = task

        Log.cktap.debug(
            "[\(traceID)] loadSlotDetails returning on main after \(String(format: "%.3f", Date().timeIntervalSince(loadStart)))s"
        )
        return task
    }

    private func fetchBalanceForActiveSlot(
        card: SatsCardInfo,
        loadStartedAt: Date,
        traceID: String,
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

        guard let activeSlotAddress = activeSlotAddress(for: card) else {
            Log.cktap.debug("[\(traceID)] Missing active slot address; skipping balance fetch")
            await MainActor.run {
                if self.currentFetchToken == fetchToken {
                    self.isLoading = false
                    self.isSweepBalanceButtonDisabled = true
                }
            }
            return
        }

        Log.cktap.debug(
            "[\(traceID)] Fetching balance for active slot address \(activeSlotAddress, privacy: .private(mask: .hash))"
        )

        do {
            let networkStart = Date()
            let balance = try await bdkClient.getBalanceFromAddress(activeSlotAddress, .bitcoin)
            let networkDuration = Date().timeIntervalSince(networkStart)
            let totalDuration = Date().timeIntervalSince(loadStartedAt)
            let networkDurationString = String(format: "%.3f", networkDuration)
            let totalDurationString = String(format: "%.3f", totalDuration)

            if Task.isCancelled { return }
            let didUpdate = await MainActor.run { () -> Bool in
                guard
                    self.currentFetchToken == fetchToken,
                    let activeSlotIndex = self.slots.firstIndex(where: { $0.isActive })
                else {
                    self.isLoading = false
                    self.isSweepBalanceButtonDisabled = true
                    return false
                }

                self.slots[activeSlotIndex].balance = balance.total.toSat()
                self.isLoading = false
                self.isSweepBalanceButtonDisabled = balance.sweepBalanceDisabled
                return true
            }

            guard didUpdate else {
                Log.cktap.debug("[\(traceID)] Active slot missing after network fetch")
                return
            }

            Log.cktap.debug(
                "[\(traceID)] Balance fetched successfully: \(balance.total.toSat(), privacy: .private) sats (network: \(networkDurationString)s, total: \(totalDurationString)s)"
            )
        } catch {
            let totalDuration = Date().timeIntervalSince(loadStartedAt)
            let totalDurationString = String(format: "%.3f", totalDuration)

            Log.cktap.error(
                "[\(traceID)] Balance fetch failed: \(error.localizedDescription, privacy: .public)"
            )
            if Task.isCancelled { return }
            await MainActor.run {
                guard self.currentFetchToken == fetchToken else { return }
                self.errorMessage = "Failed to fetch balance: \(error.localizedDescription)"
                self.isLoading = false
                self.isSweepBalanceButtonDisabled = true
            }
            Log.cktap.error(
                "[\(traceID)] Total time before failure: \(totalDurationString)s"
            )
        }
    }

    func balance(for slot: SlotInfo) -> UInt64? {
        slots.first(where: { $0.slotNumber == slot.slotNumber })?.balance
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

    private func activeSlotAddress(for card: SatsCardInfo) -> String? {
        if let slotAddress = card.slots.first(where: { $0.isActive })?.address?
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
}
