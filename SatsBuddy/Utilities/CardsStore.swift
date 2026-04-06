//
//  CardsStore.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/8/25.
//

import Foundation
import os

enum CardsStore {
    /// Upserts a card into the list based on `cardIdentifier`.
    /// - Returns: `true` if updated existing, `false` if inserted new.
    static func upsert(_ list: inout [SatsCardInfo], with card: SatsCardInfo) -> Bool {
        if let idx = list.firstIndex(where: { $0.cardIdentifier == card.cardIdentifier }) {
            list[idx] = card
            Log.ui.info("Card updated. index=\(idx)")
            return true
        } else {
            list.insert(card, at: 0)
            let total = list.count
            Log.ui.info("Card inserted at top. total=\(total)")
            return false
        }
    }
}
