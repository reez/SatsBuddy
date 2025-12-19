//
//  Price.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 12/10/25.
//

import Foundation

struct Price: Codable, Equatable {
    let time: Int
    let usd: Double
    let eur: Double
    let gbp: Double
    let cad: Double
    let chf: Double
    let aud: Double
    let jpy: Double

    enum CodingKeys: String, CodingKey {
        case time
        case usd = "USD"
        case eur = "EUR"
        case gbp = "GBP"
        case cad = "CAD"
        case chf = "CHF"
        case aud = "AUD"
        case jpy = "JPY"
    }

    static let supportedCurrencyCodes: Set<String> = [
        "USD",
        "EUR",
        "GBP",
        "CAD",
        "CHF",
        "AUD",
        "JPY",
    ]

    func value(for currencyCode: String) -> Double? {
        switch currencyCode.uppercased() {
        case "USD": return usd
        case "EUR": return eur
        case "GBP": return gbp
        case "CAD": return cad
        case "CHF": return chf
        case "AUD": return aud
        case "JPY": return jpy
        default: return nil
        }
    }

    func preferredCurrencyCode(locale: Locale = .current) -> String {
        let localeCode = locale.currency?.identifier.uppercased()
        if let code = localeCode, Price.supportedCurrencyCodes.contains(code) {
            return code
        }
        return "USD"
    }

    func preferredRate(locale: Locale = .current) -> (code: String, rate: Double?) {
        let code = preferredCurrencyCode(locale: locale)
        let rate = value(for: code) ?? usd
        return (code, rate)
    }
}

#if DEBUG
    let currentPriceMock = Price(
        time: 1_734_000_000,
        usd: 89_000,
        eur: 82_000,
        gbp: 70_000,
        cad: 120_000,
        chf: 80_000,
        aud: 130_000,
        jpy: 13_700_000
    )
    let currentPriceMockZero = Price(
        time: 1_734_000_000,
        usd: 0,
        eur: 82_000,
        gbp: 70_000,
        cad: 120_000,
        chf: 80_000,
        aud: 130_000,
        jpy: 13_700_000
    )
#endif
