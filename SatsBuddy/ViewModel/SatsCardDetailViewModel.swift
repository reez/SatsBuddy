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
    private let bdkClient: BdkClient
    private var currentFetchToken: UUID?
    private var balanceFetchTask: Task<Void, Never>?

    init(bdkClient: BdkClient = .live) {
        self.bdkClient = bdkClient
    }

    @MainActor
    func loadSlotDetails(for card: SatsCardInfo, traceID: String? = nil) {
        errorMessage = nil
        isLoading = true

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
        balanceFetchTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.fetchBalanceForActiveSlot(
                card: card,
                loadStartedAt: loadStart,
                traceID: traceID,
                fetchToken: fetchToken
            )
        }

        Log.cktap.debug(
            "[\(traceID)] loadSlotDetails returning on main after \(String(format: "%.3f", Date().timeIntervalSince(loadStart)))s"
        )
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

        guard let cardAddress = card.address else {
            Log.cktap.debug("[\(traceID)] Missing card address; skipping balance fetch")
            await MainActor.run {
                if self.currentFetchToken == fetchToken {
                    self.isLoading = false
                }
            }
            return
        }

        Log.cktap.debug(
            "[\(traceID)] Fetching balance for address \(cardAddress, privacy: .private(mask: .hash))"
        )

        do {
            let networkStart = Date()
            let balance = try await bdkClient.getBalanceFromAddress(cardAddress, .bitcoin)
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
                    return false
                }

                self.slots[activeSlotIndex].balance = balance.total.toSat()
                self.isLoading = false
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
            }
            Log.cktap.error(
                "[\(traceID)] Total time before failure: \(totalDurationString)s"
            )
        }
    }
}
