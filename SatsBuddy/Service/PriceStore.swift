//
//  PriceStore.swift
//  SatsBuddy
//
//  Created on 3/25/26.
//

import Foundation
import Observation
import os

@Observable
final class PriceStore {
    var price: Price?
    var errorMessage: String?

    private let priceClient: PriceClient

    init(priceClient: PriceClient = .live) {
        self.priceClient = priceClient
    }

    func refreshPrice() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let latest = try await priceClient.fetchPrice()
                await MainActor.run {
                    self.price = latest
                    self.errorMessage = nil
                }
            } catch {
                Log.cktap.error(
                    "PriceStore.refreshPrice failed: \(error.localizedDescription, privacy: .public)"
                )
                let errorMessage = await MainActor.run {
                    NetworkRequestFailureMessage.message(
                        for: error,
                        context: .price(hasCachedPrice: self.price != nil)
                    )
                }
                await MainActor.run {
                    self.errorMessage = errorMessage
                }
            }
        }
    }
}
