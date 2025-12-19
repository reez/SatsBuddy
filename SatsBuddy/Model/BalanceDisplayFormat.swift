//
//  BalanceDisplayFormat.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 11/21/25.
//

import Foundation

enum BalanceDisplayFormat: String, CaseIterable, Codable {
    case bitcoin = "btc"
    case sats = "sats"
    case fiat = "fiat"
    case bip177 = "bip177"

    var showsBitcoinSymbol: Bool {
        switch self {
        case .bitcoin, .bip177:
            return true
        case .sats, .fiat:
            return false
        }
    }

    func displayPrefix(price: Price?) -> String {
        switch self {
        case .bitcoin, .bip177:
            return "₿"
        case .sats:
            return ""
        case .fiat:
            return currencySymbol(for: price?.preferredCurrencyCode() ?? "USD")
        }
    }

    func displayText(price: Price?) -> String {
        switch self {
        case .sats:
            return "sats"
        case .bitcoin, .bip177:
            return ""
        case .fiat:
            return price?.preferredCurrencyCode() ?? "USD"
        }
    }

    func formatted(_ btcAmount: UInt64, price: Price?) -> String {
        switch self {
        case .sats:
            return btcAmount.formatted(.number)
        case .bitcoin:
            return String(format: "%.8f", Double(btcAmount) / 100_000_000)
        case .fiat:
            let rate = price?.preferredRate().rate
            guard let rate else { return "n/a" }
            let fiatValue = (Double(btcAmount) / 100_000_000) * rate
            return formattedFiatValue(fiatValue)
        case .bip177:
            return btcAmount.formattedBip177()
        }
    }

    private func formattedFiatValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func currencySymbol(for currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = .current
        return formatter.currencySymbol ?? currencyCode
    }
}

extension BalanceDisplayFormat {
    var index: Int {
        BalanceDisplayFormat.allCases.firstIndex(of: self) ?? 0
    }
}
