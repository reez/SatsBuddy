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
        XCTAssertEqual(card.displaySlotProgressText, "3/10")
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
        XCTAssertTrue(slot.requiresUnsealBeforeSweep)
        XCTAssertTrue(slot.shouldActivateNextSlotAfterSweep)
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
        XCTAssertFalse(slot.requiresUnsealBeforeSweep)
        XCTAssertTrue(slot.shouldActivateNextSlotAfterSweep)
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
        XCTAssertFalse(slot.requiresUnsealBeforeSweep)
        XCTAssertFalse(slot.shouldActivateNextSlotAfterSweep)
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
        XCTAssertFalse(slot.requiresUnsealBeforeSweep)
        XCTAssertFalse(slot.shouldActivateNextSlotAfterSweep)
    }

    func testSlotBadgeCopyUsesCurrentAndCoinkiteLifecycleTerms() {
        let currentSealed = makeSlotInfo(
            isActive: true,
            isUsed: true,
            address: "bc1qready",
            state: nil
        )
        let currentUnused = makeSlotInfo(
            isActive: true,
            isUsed: true,
            address: nil,
            state: nil
        )
        let historical = makeSlotInfo(
            isActive: false,
            isUsed: true,
            address: "bc1qhistory",
            state: nil
        )
        let unused = makeSlotInfo(
            isActive: false,
            isUsed: false,
            address: nil,
            state: nil
        )

        XCTAssertTrue(currentSealed.showsCurrentBadge)
        XCTAssertEqual(currentSealed.lifecycleBadgeText, "Sealed")
        XCTAssertTrue(currentUnused.showsCurrentBadge)
        XCTAssertEqual(currentUnused.lifecycleBadgeText, "Unused")
        XCTAssertFalse(historical.showsCurrentBadge)
        XCTAssertEqual(historical.lifecycleBadgeText, "Unsealed")
        XCTAssertFalse(unused.showsCurrentBadge)
        XCTAssertEqual(unused.lifecycleBadgeText, "Unused")
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
        XCTAssertEqual(exhaustedCard.displaySlotProgressText, "10/10")
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

    func testSweepBalanceEnabledWhenConfirmedAndPendingFundsBothExist() {
        XCTAssertFalse(
            Self.makeBalance(totalSats: 30_000, confirmedSats: 15_000).sweepBalanceDisabled
        )
    }

    func testSweepBalanceDisabledMessageExplainsPendingConfirmationState() {
        XCTAssertEqual(
            Self.makeBalance(totalSats: 15_000, confirmedSats: 0).sweepBalanceDisabledMessage,
            "Pending confirmation"
        )
    }

    func testSweepBalanceDisabledMessageIsNilWhenFundsAreSweepable() {
        XCTAssertNil(
            Self.makeBalance(totalSats: 15_000, confirmedSats: 15_000)
                .sweepBalanceDisabledMessage
        )
    }

    func testSendReviewSweepDisclosureMentionsUnsealAndNextSlotForCurrentSlot() {
        let disclosure = SendReviewView.sweepDisclosure(
            for: 3,
            requiresUnsealBeforeSweep: true,
            activatesNextSlotAfterSweep: true
        )

        XCTAssertEqual(
            disclosure,
            "Continuing will permanently unseal Slot 3 and move this SATSCARD to the next slot."
        )
        XCTAssertEqual(
            SendReviewView.nextSlotSetupDisclosure,
            "If another slot is available, SatsBuddy will activate it automatically so the card is ready to receive again."
        )
    }

    func testSendReviewSweepDisclosureForActiveSlotThatAlreadyNeedsSetupStillAdvances() {
        let disclosure = SendReviewView.sweepDisclosure(
            for: 3,
            requiresUnsealBeforeSweep: false,
            activatesNextSlotAfterSweep: true
        )

        XCTAssertEqual(
            disclosure,
            "Slot 3 is already unsealed. Continuing will sweep funds from that slot and move this SATSCARD to the next slot."
        )
    }

    func testSendReviewSweepDisclosureForHistoricalSlotDoesNotMentionAdvancingCard() {
        let disclosure = SendReviewView.sweepDisclosure(
            for: 3,
            requiresUnsealBeforeSweep: false,
            activatesNextSlotAfterSweep: false
        )

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
                    [
                        SlotTransaction(
                            txid: "pending-txid",
                            amount: 15_000,
                            fee: 120,
                            timestamp: Date(),
                            confirmed: false,
                            direction: .incoming
                        )
                    ]
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
        XCTAssertEqual(
            viewModel.sweepBalanceDisabledMessage,
            "Pending confirmation"
        )
        XCTAssertEqual(
            viewModel.sweepBalanceDisabledLinkURL,
            URL(string: "https://mempool.space/tx/pending-txid")
        )
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
        XCTAssertNil(viewModel.sweepBalanceDisabledMessage)
        XCTAssertNil(viewModel.sweepBalanceDisabledLinkURL)
    }

    @MainActor
    func testDetailViewModelKeepsSweepEnabledWhenConfirmedFundsRemainAlongsidePending() async {
        let slot = makeSlotInfo(balance: nil)
        let card = makeSatsCard(slots: [slot])
        let viewModel = SatsCardDetailViewModel(
            bdkClient: BdkClient(
                deriveAddress: { descriptor, _ in descriptor },
                getBalanceFromAddress: { _, _ in
                    Self.makeBalance(totalSats: 30_000, confirmedSats: 15_000)
                },
                warmUp: {},
                getTransactionsForAddress: { _, _, _ in
                    [
                        SlotTransaction(
                            txid: "pending-txid",
                            amount: 15_000,
                            fee: 120,
                            timestamp: Date(),
                            confirmed: false,
                            direction: .incoming
                        )
                    ]
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

        XCTAssertEqual(viewModel.slots.first?.balance, 30_000)
        XCTAssertFalse(viewModel.isSweepBalanceButtonDisabled)
        XCTAssertNil(viewModel.sweepBalanceDisabledMessage)
        XCTAssertNil(viewModel.sweepBalanceDisabledLinkURL)
    }

    @MainActor
    func testDetailViewModelFetchesBalanceForLastUsedSlotWhenCardIsExhausted() async {
        let olderSlot = makeSlotInfo(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            slotNumber: 8,
            isActive: false,
            isUsed: true,
            address: "bc1qoldslot",
            balance: nil,
            state: .historical
        )
        let finalSlot = makeSlotInfo(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
            slotNumber: 9,
            isActive: false,
            isUsed: true,
            address: "bc1qfinalslot",
            balance: nil,
            state: .historical
        )
        let card = makeSatsCard(
            address: nil,
            activeSlot: 10,
            totalSlots: 10,
            slots: [olderSlot, finalSlot]
        )
        let viewModel = SatsCardDetailViewModel(
            bdkClient: BdkClient(
                deriveAddress: { descriptor, _ in descriptor },
                getBalanceFromAddress: { address, _ in
                    XCTAssertEqual(address, "bc1qfinalslot")
                    return Self.makeBalance(totalSats: 12_500, confirmedSats: 12_500)
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

        XCTAssertEqual(viewModel.slots.last?.balance, 12_500)
        XCTAssertFalse(viewModel.isSweepBalanceButtonDisabled)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testDetailViewModelApplyPostBroadcastWarningShowsWarningWhenNoOtherErrorExists() {
        let viewModel = SatsCardDetailViewModel()

        viewModel.applyPostBroadcastWarning("Next slot activation failed.")

        XCTAssertEqual(viewModel.errorMessage, "Next slot activation failed.")
    }

    @MainActor
    func testDetailViewModelApplyPostBroadcastWarningPreservesBalanceError() {
        let viewModel = SatsCardDetailViewModel()
        viewModel.errorMessage = "Failed to fetch balance: timeout"

        viewModel.applyPostBroadcastWarning(
            "Next slot was activated, but SatsBuddy could not refresh the card details. Refresh the card before trying again."
        )

        XCTAssertEqual(
            viewModel.errorMessage,
            """
            Next slot was activated, but SatsBuddy could not refresh the card details. Refresh the card before trying again.
            Failed to fetch balance: timeout
            """
        )
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
