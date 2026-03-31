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

    func testSetupNextSlotAuthenticityFailurePreservesVerificationMessage() {
        let viewModel = makeViewModel()
        let authenticityError = SatsCardAuthenticityError.notGenuine

        let mapped = viewModel.setupNextSlotError(
            from: authenticityError,
            authDelay: nil
        )

        XCTAssertEqual(
            mapped,
            .raw(
                "This SATSCARD did not verify as genuine. Do not send funds to this card or sign with it."
            )
        )
    }

    func testSetupNextSlotSkipsAuthenticityVerificationWhenActiveSlotHasNoAddress() {
        XCTAssertFalse(
            SatsCardViewModel.shouldVerifyAuthenticityDuringSetup(activeSlotAddress: nil)
        )
        XCTAssertFalse(
            SatsCardViewModel.shouldVerifyAuthenticityDuringSetup(activeSlotAddress: "")
        )
        XCTAssertTrue(
            SatsCardViewModel.shouldVerifyAuthenticityDuringSetup(
                activeSlotAddress: "bc1qexampleaddress"
            )
        )
    }

    func testRefreshCardStateAfterBroadcastAutoActivatesThenRefreshes() async {
        let viewModel = makeSendSignViewModel()
        var events: [String] = []
        let refreshedCard = makeSatsCard(activeSlot: 1)

        let result = await viewModel.refreshCardStateAfterBroadcast(
            autoActivateNextSlot: true,
            activateNextSlot: {
                events.append("activate")
            },
            refreshCardSnapshot: {
                events.append("refresh")
                return refreshedCard
            }
        )

        XCTAssertEqual(events, ["activate", "refresh"])
        XCTAssertEqual(result.refreshedCardInfo?.activeSlot, refreshedCard.activeSlot)
        XCTAssertNil(result.warningMessage)
    }

    func testRefreshCardStateAfterBroadcastSkipsActivationForHistoricalSweeps() async {
        let viewModel = makeSendSignViewModel()
        var events: [String] = []

        let result = await viewModel.refreshCardStateAfterBroadcast(
            autoActivateNextSlot: false,
            activateNextSlot: {
                events.append("activate")
            },
            refreshCardSnapshot: {
                events.append("refresh")
                return nil
            }
        )

        XCTAssertEqual(events, ["refresh"])
        XCTAssertNil(result.warningMessage)
    }

    func testRefreshCardStateAfterBroadcastStillRefreshesWhenActivationFails() async {
        let viewModel = makeSendSignViewModel()
        var events: [String] = []
        let refreshedCard = makeSatsCard(activeSlot: 0)

        let result = await viewModel.refreshCardStateAfterBroadcast(
            autoActivateNextSlot: true,
            activateNextSlot: {
                events.append("activate")
                throw CkTapError.Transport(msg: "connection lost")
            },
            refreshCardSnapshot: {
                events.append("refresh")
                return refreshedCard
            }
        )

        XCTAssertEqual(events, ["activate", "refresh"])
        XCTAssertEqual(result.refreshedCardInfo?.cardIdentifier, refreshedCard.cardIdentifier)
        XCTAssertEqual(
            result.warningMessage,
            SatsCardViewModel.SetupNextSlotError.transportInterrupted.errorDescription
        )
    }

    func testRefreshCardStateAfterBroadcastWarnsWhenRefreshFailsAfterAdvancingSlot() async {
        let viewModel = makeSendSignViewModel()
        var events: [String] = []

        let result = await viewModel.refreshCardStateAfterBroadcast(
            autoActivateNextSlot: true,
            activateNextSlot: {
                events.append("activate")
            },
            refreshCardSnapshot: {
                events.append("refresh")
                return nil
            }
        )

        XCTAssertEqual(events, ["activate", "refresh"])
        XCTAssertNil(result.refreshedCardInfo)
        XCTAssertEqual(
            result.warningMessage,
            SatsCardViewModel.SetupNextSlotError.slotAdvancedRefreshRequired.errorDescription
        )
    }

    private func makeViewModel(
        cardsStoreRecorder: CardsStoreRecorder = CardsStoreRecorder()
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
            cardsStore: cardsStore
        )
    }

    private func makeSendSignViewModel() -> SendSignViewModel {
        SendSignViewModel(
            address: "bc1qdestination",
            feeRate: 5,
            slot: makeSlotInfo(),
            expectedCardIdentifier: "CARD-IDENTIFIER",
            network: .bitcoin,
            bdkClient: BdkClient(
                deriveAddress: { descriptor, _ in descriptor },
                getBalanceFromAddress: { _, _ in
                    throw TestError.expected("getBalanceFromAddress not used in this test")
                },
                warmUp: {},
                getTransactionsForAddress: { _, _, _ in
                    []
                },
                buildPsbt: { _, _, _, _ in
                    throw TestError.expected("buildPsbt not used in this test")
                },
                broadcast: { _, _ in }
            )
        )
    }
}
