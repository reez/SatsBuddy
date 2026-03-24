import Foundation
import XCTest

@testable import SatsBuddy

@MainActor
final class SatsCardViewModelTests: XCTestCase {
    func testInitializerLoadsPersistedCards() {
        let storedCards = [
            makeSatsCard(cardIdent: "CARD-1"),
            makeSatsCard(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000010")!,
                pubkey: "pubkey-2",
                cardIdent: "CARD-2"
            ),
        ]
        let recorder = CardsStoreRecorder(loadedCards: storedCards)
        let viewModel = makeViewModel(cardsStoreRecorder: recorder)

        XCTAssertSatsCardArraysEqual(viewModel.scannedCards, storedCards)
    }

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
        let viewModel = makeViewModel(
            priceClient: .test(fetchPrice: { expectedPrice })
        )

        viewModel.priceErrorMessage = "stale error"
        viewModel.refreshPrice()

        await waitUntil {
            viewModel.price == expectedPrice && viewModel.priceErrorMessage == nil
        }
    }

    func testRefreshPriceFailureStoresLocalizedErrorMessage() async {
        let viewModel = makeViewModel(
            priceClient: .test(fetchPrice: {
                throw TestError.expected("Price fetch failed")
            })
        )

        viewModel.refreshPrice()

        await waitUntil {
            viewModel.priceErrorMessage == "Price fetch failed"
        }
        XCTAssertNil(viewModel.price)
    }

    func testUpdateLabelTrimsWhitespaceAndPersistsCards() {
        let existingCard = makeSatsCard(label: nil)
        let recorder = CardsStoreRecorder(loadedCards: [existingCard])
        let viewModel = makeViewModel(cardsStoreRecorder: recorder)

        viewModel.updateLabel(for: existingCard, to: "  Travel Card  ")

        XCTAssertEqual(viewModel.scannedCards.first?.label, "Travel Card")
        XCTAssertEqual(recorder.savedSnapshots.count, 1)
        XCTAssertEqual(recorder.savedSnapshots.first?.first?.label, "Travel Card")
    }

    func testUpdateLabelClearsWhitespaceOnlyValuesAndPersistsCards() {
        let existingCard = makeSatsCard(label: "Existing Label")
        let recorder = CardsStoreRecorder(loadedCards: [existingCard])
        let viewModel = makeViewModel(cardsStoreRecorder: recorder)

        viewModel.updateLabel(for: existingCard, to: "   ")

        XCTAssertNil(viewModel.scannedCards.first?.label)
        XCTAssertEqual(recorder.savedSnapshots.count, 1)
        XCTAssertNil(recorder.savedSnapshots.first?.first?.label)
    }

    func testRemoveCardPersistsRemainingCards() {
        let firstCard = makeSatsCard(cardIdent: "CARD-1")
        let secondCard = makeSatsCard(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000011")!,
            pubkey: "pubkey-2",
            cardIdent: "CARD-2"
        )
        let recorder = CardsStoreRecorder(loadedCards: [firstCard, secondCard])
        let viewModel = makeViewModel(cardsStoreRecorder: recorder)

        viewModel.removeCard(firstCard)

        XCTAssertSatsCardArraysEqual(viewModel.scannedCards, [secondCard])
        XCTAssertEqual(recorder.savedSnapshots.count, 1)
        XCTAssertSatsCardArraysEqual(recorder.savedSnapshots.first ?? [], [secondCard])
    }

    private func makeViewModel(
        cardsStoreRecorder: CardsStoreRecorder = CardsStoreRecorder(),
        priceClient: PriceClient = .test(fetchPrice: { currentPriceMock })
    ) -> SatsCardViewModel {
        let cardsStore = CardsKeychainClient.test(
            loadCards: {
                cardsStoreRecorder.loadedCards
            },
            saveCards: { cards in
                cardsStoreRecorder.savedSnapshots.append(cards)
            }
        )

        return SatsCardViewModel(
            ckTapService: .mock,
            cardsStore: cardsStore,
            priceClient: priceClient
        )
    }
}
