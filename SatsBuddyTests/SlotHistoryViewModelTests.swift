import BitcoinDevKit
import XCTest

@testable import SatsBuddy

final class SlotHistoryViewModelTests: XCTestCase {
    func testLoadHistoryWithoutAddressResetsStateAndShowsError() async {
        let slot = makeSlotInfo(address: nil, balance: 1_234)
        let viewModel = SlotHistoryViewModel(bdkClient: .mock)

        await viewModel.loadHistory(for: slot)

        XCTAssertEqual(viewModel.errorMessage, "No address available for this slot.")
        XCTAssertEqual(viewModel.transactions, [])
        XCTAssertEqual(viewModel.slotBalance, 1_234)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.isSweepBalanceButtonDisabled)
    }

    func testLoadHistorySuccessStoresTransactionsAndBalance() async {
        let expectedTransactions = [
            SlotTransaction(
                txid: "tx-1",
                amount: 42_000,
                fee: 120,
                timestamp: Date(timeIntervalSince1970: 1_700_000_100),
                confirmed: true,
                direction: .incoming
            ),
            SlotTransaction(
                txid: "tx-2",
                amount: -10_000,
                fee: 90,
                timestamp: Date(timeIntervalSince1970: 1_700_000_200),
                confirmed: false,
                direction: .outgoing
            ),
        ]
        let slot = makeSlotInfo(address: "bc1qhistory", balance: 999)
        let viewModel = SlotHistoryViewModel(
            bdkClient: BdkClient(
                deriveAddress: { descriptor, _ in descriptor },
                getBalanceFromAddress: { _, _ in
                    Self.makeBalance(totalSats: 84_000, confirmedSats: 84_000)
                },
                warmUp: {},
                getTransactionsForAddress: { _, _, _ in
                    expectedTransactions
                },
                buildPsbt: { _, _, _, _ in
                    throw TestError.expected("buildPsbt not used in this test")
                },
                broadcast: { _, _ in }
            )
        )

        await viewModel.loadHistory(for: slot)

        XCTAssertEqual(viewModel.transactions, expectedTransactions)
        XCTAssertEqual(viewModel.slotBalance, 84_000)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isSweepBalanceButtonDisabled)
    }

    func testLoadHistoryPreservesBalanceWhenTransactionsFail() async {
        let slot = makeSlotInfo(address: "bc1qfallback", balance: 321)
        let viewModel = SlotHistoryViewModel(
            bdkClient: BdkClient(
                deriveAddress: { descriptor, _ in descriptor },
                getBalanceFromAddress: { _, _ in
                    Self.makeBalance(totalSats: 21_000, confirmedSats: 21_000)
                },
                warmUp: {},
                getTransactionsForAddress: { _, _, _ in
                    throw TestError.expected("Transaction load failed")
                },
                buildPsbt: { _, _, _, _ in
                    throw TestError.expected("buildPsbt not used in this test")
                },
                broadcast: { _, _ in }
            )
        )

        await viewModel.loadHistory(for: slot)

        XCTAssertEqual(viewModel.errorMessage, "Unable to load transactions.")
        XCTAssertEqual(viewModel.transactions, [])
        XCTAssertEqual(viewModel.slotBalance, 21_000)
        XCTAssertFalse(viewModel.isLoading)
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
