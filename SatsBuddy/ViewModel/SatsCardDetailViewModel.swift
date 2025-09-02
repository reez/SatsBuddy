//
//  SatsCardDetailViewModel.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/3/25.
//

import Foundation
import Observation
import os

@Observable
class SatsCardDetailViewModel {
    var slots: [SlotInfo] = []
    var isLoading = false
    var errorMessage: String?

    @MainActor
    func loadSlotDetails(for card: SatsCardInfo) async {
        isLoading = true
        defer { isLoading = false }

        // Use the slot data that was already fetched during NFC scan
        slots = card.slots
    }
}
