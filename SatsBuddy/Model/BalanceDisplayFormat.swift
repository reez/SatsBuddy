//
//  BalanceDisplayFormat.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 2/3/25.
//

import Foundation

enum BalanceDisplayFormat: String, CaseIterable, Codable {
    case bitcoin = "btc"
    case sats = "sats"
    case bip177 = "bip177"

    var displayPrefix: String {
        switch self {
        case .bitcoin, .bip177:
            return "₿"
        case .sats:
            return ""
        }
    }

    var displayText: String {
        switch self {
        case .sats:
            return "sats"
        case .bitcoin, .bip177:
            return ""
        }
    }

    func formatted(_ btcAmount: UInt64) -> String {
        switch self {
        case .sats:
            return btcAmount.formatted(.number)
        case .bitcoin:
            return String(format: "%.8f", Double(btcAmount) / 100_000_000)
        case .bip177:
            return btcAmount.formattedBip177()
        }
    }
}

extension BalanceDisplayFormat {
    var index: Int {
        BalanceDisplayFormat.allCases.firstIndex(of: self) ?? 0
    }
}
