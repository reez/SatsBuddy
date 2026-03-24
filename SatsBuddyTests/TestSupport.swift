import Foundation
import XCTest

@testable import SatsBuddy

enum TestError: LocalizedError {
    case expected(String)

    var errorDescription: String? {
        switch self {
        case .expected(let message):
            return message
        }
    }
}

final class CardsStoreRecorder {
    var loadedCards: [SatsCardInfo]
    var savedSnapshots: [[SatsCardInfo]] = []

    init(loadedCards: [SatsCardInfo] = []) {
        self.loadedCards = loadedCards
    }
}

extension XCTestCase {
    func waitUntil(
        timeout: Duration = .seconds(1),
        pollInterval: Duration = .milliseconds(20),
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while clock.now < deadline {
            if await condition() {
                return
            }

            try? await Task.sleep(for: pollInterval)
        }

        XCTFail("Timed out waiting for condition.", file: file, line: line)
    }

    func XCTAssertSatsCardArraysEqual(
        _ lhs: [SatsCardInfo],
        _ rhs: [SatsCardInfo],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(lhs.count, rhs.count, file: file, line: line)

        for (leftCard, rightCard) in zip(lhs, rhs) {
            XCTAssertEqual(leftCard.id, rightCard.id, file: file, line: line)
            XCTAssertEqual(leftCard.version, rightCard.version, file: file, line: line)
            XCTAssertEqual(leftCard.birth, rightCard.birth, file: file, line: line)
            XCTAssertEqual(leftCard.address, rightCard.address, file: file, line: line)
            XCTAssertEqual(leftCard.pubkey, rightCard.pubkey, file: file, line: line)
            XCTAssertEqual(leftCard.cardIdent, rightCard.cardIdent, file: file, line: line)
            XCTAssertEqual(leftCard.cardNonce, rightCard.cardNonce, file: file, line: line)
            XCTAssertEqual(leftCard.activeSlot, rightCard.activeSlot, file: file, line: line)
            XCTAssertEqual(leftCard.totalSlots, rightCard.totalSlots, file: file, line: line)
            XCTAssertEqual(leftCard.isActive, rightCard.isActive, file: file, line: line)
            XCTAssertEqual(leftCard.dateScanned, rightCard.dateScanned, file: file, line: line)
            XCTAssertEqual(leftCard.label, rightCard.label, file: file, line: line)
            XCTAssertEqual(leftCard.slots.count, rightCard.slots.count, file: file, line: line)

            for (leftSlot, rightSlot) in zip(leftCard.slots, rightCard.slots) {
                XCTAssertEqual(leftSlot.id, rightSlot.id, file: file, line: line)
                XCTAssertEqual(leftSlot.slotNumber, rightSlot.slotNumber, file: file, line: line)
                XCTAssertEqual(leftSlot.isActive, rightSlot.isActive, file: file, line: line)
                XCTAssertEqual(leftSlot.isUsed, rightSlot.isUsed, file: file, line: line)
                XCTAssertEqual(leftSlot.pubkey, rightSlot.pubkey, file: file, line: line)
                XCTAssertEqual(
                    leftSlot.pubkeyDescriptor,
                    rightSlot.pubkeyDescriptor,
                    file: file,
                    line: line
                )
                XCTAssertEqual(leftSlot.address, rightSlot.address, file: file, line: line)
                XCTAssertEqual(leftSlot.balance, rightSlot.balance, file: file, line: line)
            }
        }
    }
}

func makeSlotInfo(
    id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    slotNumber: UInt8 = 0,
    isActive: Bool = true,
    isUsed: Bool = true,
    pubkey: String? = "slot-pubkey",
    pubkeyDescriptor: String? = "wpkh(slot-pubkey)",
    address: String? = "bc1qslot",
    balance: UInt64? = 21_000
) -> SlotInfo {
    SlotInfo(
        id: id,
        slotNumber: slotNumber,
        isActive: isActive,
        isUsed: isUsed,
        pubkey: pubkey,
        pubkeyDescriptor: pubkeyDescriptor,
        address: address,
        balance: balance
    )
}

func makeSatsCard(
    id: UUID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
    version: String = "1.0.0",
    birth: UInt64? = 1,
    address: String? = "bc1qcard",
    pubkey: String = "card-pubkey",
    cardIdent: String? = "CARD-IDENTIFIER",
    cardNonce: String? = "nonce",
    activeSlot: UInt8? = 0,
    totalSlots: UInt8? = 10,
    slots: [SlotInfo] = [makeSlotInfo()],
    isActive: Bool = true,
    dateScanned: Date = Date(timeIntervalSince1970: 1_700_000_000),
    label: String? = nil
) -> SatsCardInfo {
    SatsCardInfo(
        id: id,
        version: version,
        birth: birth,
        address: address,
        pubkey: pubkey,
        cardIdent: cardIdent,
        cardNonce: cardNonce,
        activeSlot: activeSlot,
        totalSlots: totalSlots,
        slots: slots,
        isActive: isActive,
        dateScanned: dateScanned,
        label: label
    )
}
