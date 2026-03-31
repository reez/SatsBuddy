import BitcoinDevKit
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

    func testSlotStateDefaultsToActiveReadyWhenActiveSlotHasAddress() {
        let slot = makeSlotInfo(
            isActive: true,
            isUsed: true,
            address: "bc1qready",
            state: nil
        )

        XCTAssertEqual(slot.state, .activeReady)
        XCTAssertEqual(slot.receiveAddress, "bc1qready")
        XCTAssertTrue(slot.isReadyToReceive)
        XCTAssertFalse(slot.needsSetupToReceive)
    }

    func testSlotStateDefaultsToActiveNeedsSetupWhenActiveSlotHasNoAddress() {
        let slot = makeSlotInfo(
            isActive: true,
            isUsed: true,
            address: nil,
            state: nil
        )

        XCTAssertEqual(slot.state, .activeNeedsSetup)
        XCTAssertNil(slot.receiveAddress)
        XCTAssertFalse(slot.isReadyToReceive)
        XCTAssertTrue(slot.needsSetupToReceive)
    }

    func testReceiveAddressIsHiddenWhenActiveSlotNeedsSetupEvenIfAddressExists() {
        let slot = makeSlotInfo(
            isActive: true,
            isUsed: true,
            address: "bc1qoldslot",
            state: .activeNeedsSetup
        )

        XCTAssertNil(slot.receiveAddress)
        XCTAssertFalse(slot.isReadyToReceive)
        XCTAssertTrue(slot.needsSetupToReceive)
    }

    func testSlotStateDefaultsToHistoricalForUsedNonActiveSlot() {
        let slot = makeSlotInfo(
            isActive: false,
            isUsed: true,
            address: "bc1qhistory",
            state: nil
        )

        XCTAssertEqual(slot.state, .historical)
        XCTAssertNil(slot.receiveAddress)
        XCTAssertFalse(slot.isReadyToReceive)
        XCTAssertFalse(slot.needsSetupToReceive)
    }

    func testSlotStateDefaultsToUnusedWhenSlotHasNotBeenUsed() {
        let slot = makeSlotInfo(
            isActive: false,
            isUsed: false,
            address: nil,
            state: nil
        )

        XCTAssertEqual(slot.state, .unused)
        XCTAssertNil(slot.receiveAddress)
        XCTAssertFalse(slot.isReadyToReceive)
        XCTAssertFalse(slot.needsSetupToReceive)
    }

    func testSlotDecodingBackfillsMissingStateForPersistedCards() throws {
        let payload = """
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "slotNumber": 0,
              "isActive": true,
              "isUsed": true,
              "pubkey": "slot-pubkey",
              "pubkeyDescriptor": "wpkh(slot-pubkey)",
              "address": null,
              "balance": 21000
            }
            """.data(using: .utf8)!

        let slot = try JSONDecoder().decode(SlotInfo.self, from: payload)

        XCTAssertEqual(slot.state, .activeNeedsSetup)
        XCTAssertTrue(slot.needsSetupToReceive)
    }

    func testDisplayActiveSlotNumberIsNilWhenCardIsExhausted() {
        let exhaustedCard = makeSatsCard(activeSlot: 10, totalSlots: 10)

        XCTAssertTrue(exhaustedCard.isExhausted)
        XCTAssertNil(exhaustedCard.displayActiveSlotNumber)
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

    func testSweepBalanceDisabledWhenTotalBalanceIsZero() {
        XCTAssertTrue(Self.makeBalance(totalSats: 0, confirmedSats: 0).sweepBalanceDisabled)
    }

    func testSweepBalanceDisabledWhenOnlyPendingFundsRemain() {
        XCTAssertTrue(Self.makeBalance(totalSats: 15_000, confirmedSats: 0).sweepBalanceDisabled)
    }

    func testSweepBalanceEnabledWhenConfirmedFundsRemain() {
        XCTAssertFalse(
            Self.makeBalance(totalSats: 15_000, confirmedSats: 15_000).sweepBalanceDisabled
        )
    }

    func testSendReviewSweepDisclosureMentionsUnsealAndNextSlotForCurrentSlot() {
        let disclosure = SendReviewView.sweepDisclosure(for: 3, advancesToNextSlot: true)

        XCTAssertEqual(
            disclosure,
            "Continuing will permanently unseal Slot 3 and move this SATSCARD to the next slot."
        )
        XCTAssertEqual(
            SendReviewView.nextSlotSetupDisclosure,
            "If another slot is available, SatsBuddy will activate it automatically so the card is ready to receive again."
        )
    }

    func testSendReviewSweepDisclosureForHistoricalSlotDoesNotMentionAdvancingCard() {
        let disclosure = SendReviewView.sweepDisclosure(for: 3, advancesToNextSlot: false)

        XCTAssertEqual(
            disclosure,
            "Slot 3 is already unsealed. Continuing will sweep funds from that slot without changing the SATSCARD's current slot."
        )
    }

    @MainActor
    func testDetailViewModelDisablesSweepWhenOnlyPendingFundsRemain() async {
        let slot = makeSlotInfo(balance: nil)
        let card = makeSatsCard(slots: [slot])
        let viewModel = SatsCardDetailViewModel(
            bdkClient: BdkClient(
                deriveAddress: { descriptor, _ in descriptor },
                getBalanceFromAddress: { _, _ in
                    Self.makeBalance(totalSats: 15_000, confirmedSats: 0)
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

        viewModel.loadSlotDetails(for: card, traceID: "TEST")

        await waitUntil {
            !viewModel.isLoading
        }

        XCTAssertEqual(viewModel.slots.first?.balance, 15_000)
        XCTAssertTrue(viewModel.isSweepBalanceButtonDisabled)
    }

    @MainActor
    func testDetailViewModelRefreshBalanceCompletesWithUpdatedBalance() async {
        let slot = makeSlotInfo(balance: nil)
        let card = makeSatsCard(slots: [slot])
        let viewModel = SatsCardDetailViewModel(
            bdkClient: BdkClient(
                deriveAddress: { descriptor, _ in descriptor },
                getBalanceFromAddress: { _, _ in
                    try? await Task.sleep(for: .milliseconds(50))
                    return Self.makeBalance(totalSats: 21_000, confirmedSats: 21_000)
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

        await viewModel.refreshBalance(for: card, traceID: "TEST")

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.slots.first?.balance, 21_000)
        XCTAssertFalse(viewModel.isSweepBalanceButtonDisabled)
    }

    private static func makeBalance(totalSats: UInt64, confirmedSats: UInt64) -> Balance {
        let total = Amount.fromSat(satoshi: totalSats)
        let confirmed = Amount.fromSat(satoshi: confirmedSats)
        let zero = Amount.fromSat(satoshi: 0)

        return Balance(
            immature: zero,
            trustedPending: zero,
            untrustedPending: zero,
            confirmed: confirmed,
            trustedSpendable: confirmed,
            total: total
        )
    }
}
