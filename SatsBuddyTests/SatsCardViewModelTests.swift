//
//  SatsCardViewModelTests.swift
//  SatsBuddyTests
//
//  Created by Chase Lewis on 1/1/26.
//

import Foundation
import Testing
@testable import SatsBuddy

func eventually(
    timeout: Duration = .seconds(1),
    pollEvery: Duration = .milliseconds(20),
    _ predicate: @escaping () -> Bool
) async throws {
    let deadline = ContinuousClock().now.advanced(by: timeout)
    while ContinuousClock().now < deadline {
        if predicate() { return }
        try await Task.sleep(for: pollEvery)
    }
    #expect(predicate(), "Condition not satisfied before timeout.")
}

struct TestError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class CardsStoreSpy {
    var loaded: [SatsCardInfo] = []
    var savedSnapshots: [[SatsCardInfo]] = []
    var deleteCalls = 0

    func makeClient() -> CardsKeychainClient {
        .testing(
            loadCards: { [loaded] in loaded },
            saveCards: { [weak self] cards in self?.savedSnapshots.append(cards) },
            deleteCards: { [weak self] in self?.deleteCalls += 1 }
        )
    }
}

func makeCard(
    id: UUID = UUID(),
    cardIdent: String? = nil,
    pubkey: String = "02" + String(repeating: "0", count: 64),
    label: String? = nil
) -> SatsCardInfo {
    SatsCardInfo(
        id: id,
        version: "1.0.3",
        birth: 1,
        address: "bc1qtestaddress",
        pubkey: pubkey,
        cardIdent: cardIdent,
        activeSlot: 1,
        totalSlots: 10,
        slots: [],
        isActive: true,
        dateScanned: Date(),
        label: label
    )
}

@Suite("SatsCardViewModel")
struct SatsCardViewModelTests {

    @Test("init loads persisted cards")
    func initLoadsPersistedCards() throws {
        let spy = CardsStoreSpy()
        let a = makeCard(cardIdent: "A")
        let b = makeCard(cardIdent: "B")
        spy.loaded = [a, b]

        let vm = SatsCardViewModel(
            ckTapService: .mock,
            cardsStore: spy.makeClient(),
            priceClient: .mock
        )

        #expect(vm.scannedCards.map(\.cardIdent) == [a.cardIdent, b.cardIdent])
    }

    @Test("refreshPrice sets price and clears error on success")
    func refreshPriceSuccess() async throws {
        let expected = currentPriceMock

        let vm = SatsCardViewModel(
            ckTapService: .mock,
            cardsStore: .mock,
            priceClient: .testing(fetchPrice: { expected })
        )

        vm.priceErrorMessage = "old"
        vm.refreshPrice()

        try await eventually { vm.price != nil }

        #expect(vm.price == expected)
        #expect(vm.priceErrorMessage == nil)
    }

    @Test("refreshPrice sets error on failure")
    func refreshPriceFailure() async throws {
        let vm = SatsCardViewModel(
            ckTapService: .mock,
            cardsStore: .mock,
            priceClient: .testing(fetchPrice: { throw TestError(message: "Network down") })
        )

        vm.refreshPrice()
        try await eventually { vm.priceErrorMessage != nil }

        #expect(vm.price == nil)
        #expect(vm.priceErrorMessage == "Network down")
    }

    @Test("removeCard removes by id and persists")
    func removeCardPersists() throws {
        let spy = CardsStoreSpy()
        let vm = SatsCardViewModel(
            ckTapService: .mock,
            cardsStore: spy.makeClient(),
            priceClient: .mock
        )

        let a = makeCard(cardIdent: "A")
        let b = makeCard(cardIdent: "B")
        vm.scannedCards = [a, b]

        vm.removeCard(a)

        #expect(vm.scannedCards.map(\.id) == [b.id])
        #expect(spy.savedSnapshots.count == 1)
        #expect(spy.savedSnapshots.last?.map(\.id) == [b.id])
    }

    @Test("moveCards reorders and persists")
    func moveCardsPersists() throws {
        let spy = CardsStoreSpy()
        let vm = SatsCardViewModel(
            ckTapService: .mock,
            cardsStore: spy.makeClient(),
            priceClient: .mock
        )

        let a = makeCard(cardIdent: "A")
        let b = makeCard(cardIdent: "B")
        let c = makeCard(cardIdent: "C")
        vm.scannedCards = [a, b, c]

        vm.moveCards(from: IndexSet(integer: 1), to: 3)

        #expect(vm.scannedCards.map(\.cardIdent) == ["A", "C", "B"])
        #expect(spy.savedSnapshots.count == 1)
        #expect(spy.savedSnapshots.last?.map(\.cardIdent) == ["A", "C", "B"])
    }

    @Test("updateLabel trims and persists when changed")
    @MainActor
    func updateLabelTrimsAndPersists() throws {
        let spy = CardsStoreSpy()
        let vm = SatsCardViewModel(
            ckTapService: .mock,
            cardsStore: spy.makeClient(),
            priceClient: .mock
        )

        let card = makeCard(cardIdent: "CARD-1", label: nil)
        vm.scannedCards = [card]

        vm.updateLabel(for: card, to: "  My Card  ")

        #expect(vm.scannedCards[0].label == "My Card")
        #expect(spy.savedSnapshots.count == 1)
    }

    @Test("updateLabel empty becomes nil")
    @MainActor
    func updateLabelEmptyBecomesNil() throws {
        let spy = CardsStoreSpy()
        let vm = SatsCardViewModel(
            ckTapService: .mock,
            cardsStore: spy.makeClient(),
            priceClient: .mock
        )

        let card = makeCard(cardIdent: "CARD-1", label: "Existing")
        vm.scannedCards = [card]

        vm.updateLabel(for: card, to: "   ")

        #expect(vm.scannedCards[0].label == nil)
        #expect(spy.savedSnapshots.count == 1)
    }

    @Test("updateLabel does not persist if unchanged")
    @MainActor
    func updateLabelNoopWhenUnchanged() throws {
        let spy = CardsStoreSpy()
        let vm = SatsCardViewModel(
            ckTapService: .mock,
            cardsStore: spy.makeClient(),
            priceClient: .mock
        )

        let card = makeCard(cardIdent: "CARD-1", label: "Same")
        vm.scannedCards = [card]

        vm.updateLabel(for: card, to: "Same")

        #expect(spy.savedSnapshots.isEmpty)
    }

    @Test("startSetupNextSlot empty CVC sets status message")
    func startSetupNextSlotEmptyCVC() throws {
        let vm = SatsCardViewModel(
            ckTapService: .mock,
            cardsStore: .mock,
            priceClient: .mock
        )

        let card = makeCard(cardIdent: "CARD-1")
        vm.startSetupNextSlot(for: card, cvc: "   ")

        #expect(vm.lastStatusMessage == "Enter CVC to set up next slot.")
    }
}
