import XCTest

@testable import SatsBuddy

final class CardsStoreTests: XCTestCase {
    func testUpsertAppendsNewCardAndReturnsFalse() {
        var cards = [makeSatsCard(cardIdent: "CARD-1")]
        let newCard = makeSatsCard(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
            pubkey: "pubkey-2",
            cardIdent: "CARD-2"
        )

        let didUpdate = CardsStore.upsert(&cards, with: newCard)

        XCTAssertFalse(didUpdate)
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards.last?.cardIdentifier, "CARD-2")
    }

    func testUpsertReplacesMatchingCardAndKeepsIndex() {
        var cards = [
            makeSatsCard(cardIdent: "CARD-1", label: "Old"),
            makeSatsCard(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
                pubkey: "pubkey-2",
                cardIdent: "CARD-2"
            ),
        ]
        let replacement = makeSatsCard(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
            version: "2.0.0",
            pubkey: "updated-pubkey",
            cardIdent: "CARD-1",
            label: "Updated"
        )

        let didUpdate = CardsStore.upsert(&cards, with: replacement)

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards[0].version, "2.0.0")
        XCTAssertEqual(cards[0].label, "Updated")
        XCTAssertEqual(cards[0].pubkey, "updated-pubkey")
        XCTAssertEqual(cards[1].cardIdentifier, "CARD-2")
    }
}
