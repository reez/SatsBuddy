import CKTap
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
            priceClient: PriceClient(fetchPrice: { expectedPrice })
        )

        viewModel.priceErrorMessage = "stale error"
        viewModel.refreshPrice()

        await waitUntil {
            viewModel.price == expectedPrice && viewModel.priceErrorMessage == nil
        }
    }

    func testRefreshPriceFailureStoresLocalizedErrorMessage() async {
        let viewModel = makeViewModel(
            priceClient: PriceClient(fetchPrice: {
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

    func testApplyCardSnapshotMergesRefreshedCardAndPersistsResult() {
        let existingCard = makeSatsCard(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000099")!,
            address: "bc1qold",
            pubkey: "pubkey-existing",
            cardIdent: "CARD-EXISTING",
            activeSlot: 0,
            totalSlots: 10,
            slots: [
                makeSlotInfo(
                    slotNumber: 0,
                    isActive: true,
                    isUsed: true,
                    address: "bc1qold",
                    balance: 21_000
                )
            ],
            label: "Travel Card"
        )
        let refreshedCard = makeSatsCard(
            address: nil,
            pubkey: "pubkey-existing",
            cardIdent: "CARD-EXISTING",
            activeSlot: 1,
            totalSlots: 10,
            slots: [
                makeSlotInfo(
                    slotNumber: 0,
                    isActive: false,
                    isUsed: true,
                    address: "bc1qold"
                ),
                makeSlotInfo(
                    slotNumber: 1,
                    isActive: true,
                    isUsed: true,
                    address: nil
                ),
            ],
            label: nil
        )
        let recorder = CardsStoreRecorder(loadedCards: [existingCard])
        let viewModel = makeViewModel(cardsStoreRecorder: recorder)

        let mergedCard = viewModel.applyCardSnapshot(refreshedCard)

        XCTAssertEqual(mergedCard.id, existingCard.id)
        XCTAssertEqual(mergedCard.label, existingCard.label)
        XCTAssertEqual(mergedCard.activeSlot, 1)
        XCTAssertNil(mergedCard.address)
        XCTAssertEqual(mergedCard.slots.count, 2)
        XCTAssertEqual(viewModel.scannedCards.first?.id, existingCard.id)
        XCTAssertEqual(viewModel.scannedCards.first?.label, existingCard.label)
        XCTAssertEqual(viewModel.scannedCards.first?.activeSlot, 1)
        XCTAssertEqual(recorder.savedSnapshots.count, 1)
        XCTAssertEqual(recorder.savedSnapshots.first?.first?.id, existingCard.id)
        XCTAssertEqual(recorder.savedSnapshots.first?.first?.activeSlot, 1)
    }

    func testValidatedRefreshCardInfoRejectsWrongCardIdentifier() {
        let viewModel = makeViewModel()
        let scannedCard = makeSatsCard(cardIdent: "CARD-1")
        let wrongCard = makeSatsCard(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000022")!,
            pubkey: "other-pubkey",
            cardIdent: "CARD-2"
        )

        XCTAssertThrowsError(
            try viewModel.validatedRefreshCardInfo(
                wrongCard,
                expectedCardIdentifier: scannedCard.cardIdentifier
            )
        ) { error in
            XCTAssertEqual(error as? SatsCardViewModel.RefreshCardError, .wrongCard)
        }
    }

    func testSetupNextSlotInvalidStateMapsToNotReadyWhenSlotsRemain() {
        let viewModel = makeViewModel()

        let error = CkTapError.Card(err: CardError.InvalidState)
        let mapped = viewModel.setupNextSlotError(
            from: error,
            authDelay: nil,
            activeSlot: 4,
            totalSlots: 10
        )

        XCTAssertEqual(mapped, SatsCardViewModel.SetupNextSlotError.cardNotReadyForNextSlot)
    }

    func testSetupNextSlotInvalidStateMapsToNoUnusedSlotsWhenCardIsExhausted() {
        let viewModel = makeViewModel()

        let error = CkTapError.Card(err: CardError.InvalidState)
        let mapped = viewModel.setupNextSlotError(
            from: error,
            authDelay: nil,
            activeSlot: 10,
            totalSlots: 10
        )

        XCTAssertEqual(mapped, SatsCardViewModel.SetupNextSlotError.noUnusedSlots)
    }

    private func makeViewModel(
        cardsStoreRecorder: CardsStoreRecorder = CardsStoreRecorder(),
        priceClient: PriceClient = PriceClient(fetchPrice: { currentPriceMock })
    ) -> SatsCardViewModel {
        let cardsStore = CardsKeychainClient(
            loadCards: {
                cardsStoreRecorder.loadedCards
            },
            saveCards: { cards in
                cardsStoreRecorder.savedSnapshots.append(cards)
            },
            deleteCards: {}
        )

        return SatsCardViewModel(
            ckTapService: .mock,
            cardsStore: cardsStore,
            priceClient: priceClient
        )
    }
}
