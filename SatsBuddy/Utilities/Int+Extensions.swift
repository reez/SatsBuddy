//
//  Int+Extensions.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 2/3/25.
//

import Foundation

extension UInt64 {
    private var numberFormatter: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.usesGroupingSeparator = true
        numberFormatter.groupingSeparator = ","
        numberFormatter.generatesDecimalNumbers = false

        return numberFormatter
    }

    func formattedSatoshis() -> String {
        if self == 0 {
            return "0.00 000 000"
        }

        let btcValue = Double(self) / 100_000_000.0
        let btcString = String(format: "%.8f", btcValue)
        let parts = btcString.split(separator: ".")
        guard parts.count == 2 else { return btcString }

        let wholePart = String(parts[0])
        let decimalPart = String(parts[1])
        let paddedDecimal = decimalPart.padding(toLength: 8, withPad: "0", startingAt: 0)

        let first = paddedDecimal.prefix(2)
        let second = paddedDecimal.dropFirst(2).prefix(3)
        let third = paddedDecimal.dropFirst(5).prefix(3)

        let formattedBalance = "\(wholePart).\(first) \(second) \(third)"

        return formattedBalance
    }

    func formattedBip177() -> String {
        if self != .zero && self >= 1_000_000 && self % 1_000_000 == .zero {
            return "\(self / 1_000_000)M"

        } else if self != .zero && self % 1_000 == 0 {
            return "\(self / 1_000)K"
        }

        return numberFormatter.string(from: NSNumber(value: self)) ?? "0"
    }
}

extension Int64 {
    func nonNegativeValue() -> Int64 {
        self < .zero ? self * -1 : self
    }

    func toUInt64() -> UInt64 {
        UInt64(truncatingIfNeeded: self)
    }
}
