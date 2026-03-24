import Foundation
import XCTest

@testable import SatsBuddy

final class ModelValueTests: XCTestCase {
    func testSatsCardDisplayNameUsesTrimmedLabel() {
        let card = makeSatsCard(pubkey: "pubkey", label: "  Travel Card  ")

        XCTAssertEqual(card.displayName, "Travel Card")
    }

    func testSatsCardDisplayNameFallsBackToPubkeyAddressThenDefault() {
        let pubkeyCard = makeSatsCard(pubkey: "pubkey-fallback", label: "   ")
        let addressCard = makeSatsCard(address: "bc1qaddress-fallback", pubkey: "", label: nil)
        let defaultCard = makeSatsCard(address: nil, pubkey: "", label: nil)

        XCTAssertEqual(pubkeyCard.displayName, "pubkey-fallback")
        XCTAssertEqual(addressCard.displayName, "bc1qaddress-fallback")
        XCTAssertEqual(defaultCard.displayName, "SATSCARD")
    }

    func testSatsCardIdentifierUsesCardIdentWhenAvailable() {
        let identifiedCard = makeSatsCard(pubkey: "pubkey", cardIdent: "CARD-123")
        let fallbackCard = makeSatsCard(pubkey: "pubkey", cardIdent: nil)

        XCTAssertEqual(identifiedCard.cardIdentifier, "CARD-123")
        XCTAssertEqual(fallbackCard.cardIdentifier, "pubkey")
    }

    func testDisplayActiveSlotNumbersAreOneBased() {
        let card = makeSatsCard(activeSlot: 2)
        let slot = makeSlotInfo(slotNumber: 4)

        XCTAssertEqual(card.displayActiveSlotNumber, 3)
        XCTAssertEqual(slot.displaySlotNumber, 5)
    }

    func testPreferredCurrencyCodeUsesSupportedLocaleCurrency() {
        let price = currentPriceMock

        XCTAssertEqual(price.preferredCurrencyCode(locale: Locale(identifier: "en_GB")), "GBP")
        XCTAssertEqual(price.preferredCurrencyCode(locale: Locale(identifier: "fr_CH")), "CHF")
    }

    func testPreferredCurrencyCodeFallsBackToUSDWhenLocaleCurrencyIsUnsupported() {
        let price = currentPriceMock

        XCTAssertEqual(price.preferredCurrencyCode(locale: Locale(identifier: "es_MX")), "USD")
    }

    func testPreferredRateFallsBackToUsdRateWhenNeeded() {
        let price = currentPriceMock
        let preferredRate = price.preferredRate(locale: Locale(identifier: "es_MX"))

        XCTAssertEqual(preferredRate.code, "USD")
        XCTAssertEqual(preferredRate.rate, price.usd)
    }
}
