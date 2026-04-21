import Foundation
import XCTest

@testable import SatsBuddy

@MainActor
final class PriceStoreTests: XCTestCase {
    func testRefreshPriceSuccessStoresPriceAndClearsErrorMessage() async {
        let expectedPrice = Price(
            time: 1_734_000_001,
            usd: 95_000,
            eur: 88_000,
            gbp: 75_000,
            cad: 128_000,
            chf: 84_000,
            aud: 136_000,
            jpy: 14_200_000
        )
        let store = PriceStore(
            priceClient: PriceClient(fetchPrice: { expectedPrice })
        )

        store.errorMessage = "stale error"
        store.refreshPrice()

        await waitUntil {
            store.price == expectedPrice && store.errorMessage == nil
        }
    }

    func testRefreshPriceFailureStoresLocalizedErrorMessage() async {
        let store = PriceStore(
            priceClient: PriceClient(fetchPrice: {
                throw TestError.expected("Price fetch failed")
            })
        )

        store.refreshPrice()

        await waitUntil {
            store.errorMessage == "Live BTC price unavailable right now."
        }
        XCTAssertNil(store.price)
    }

    func testRefreshPriceFailureWithCachedPriceExplainsFallback() async {
        let expectedPrice = Price(
            time: 1_734_000_002,
            usd: 96_000,
            eur: 89_000,
            gbp: 76_000,
            cad: 129_000,
            chf: 85_000,
            aud: 137_000,
            jpy: 14_300_000
        )
        let store = PriceStore(
            priceClient: PriceClient(fetchPrice: {
                throw URLError(.notConnectedToInternet)
            })
        )
        store.price = expectedPrice

        store.refreshPrice()

        await waitUntil {
            store.errorMessage == "Live BTC price unavailable. Using the last loaded price."
        }
        XCTAssertEqual(store.price, expectedPrice)
    }
}
