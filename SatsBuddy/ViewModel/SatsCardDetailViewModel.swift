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

    init(bdkClient: BdkClient = .live) {
        self.bdkClient = bdkClient
    }

    @MainActor
    func loadSlotDetails(for card: SatsCardInfo) {
        isLoading = true
        defer { isLoading = false }

        // Load slots immediately from NFC scan data - this shows the UI instantly
        slots = card.slots

        // Start balance fetching in completely detached background task
        Task.detached { [weak self] in
            await self?.fetchBalanceForActiveSlot(card: card)
        }
    }

    @MainActor
    private func fetchBalanceForActiveSlot(card: SatsCardInfo) async {
        guard let activeSlotIndex = self.slots.firstIndex(where: { $0.isActive }),
              let cardAddress = card.address else {
            Log.cktap.debug("No active slot or card address found for balance fetching. Active slots: \(self.slots.filter { $0.isActive }.count, privacy: .public)")
            return
        }

        Log.cktap.debug("Fetching balance for active slot \(activeSlotIndex, privacy: .public) using card address: \(cardAddress, privacy: .public)")

        do {
            let balance = try await self.bdkClient.getBalanceFromAddress(cardAddress, .bitcoin)

            // Update only the balance for the active slot
            self.slots[activeSlotIndex].balance = balance.total.toSat()
            Log.cktap.debug("Successfully fetched balance for active slot: \(balance.total.toSat(), privacy: .public)")
        } catch {
            Log.cktap.error("Failed to fetch balance for active slot: \(error.localizedDescription, privacy: .public)")
            self.errorMessage = "Failed to fetch balance: \(error.localizedDescription)"
            self.slots[activeSlotIndex].balance = 0
        }
    }
}
