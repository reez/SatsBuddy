import XCTest

@testable import SatsBuddy

@MainActor
final class FeeViewModelTests: XCTestCase {
    func testGetFeesSuccessPopulatesRecommendedFees() async {
        let expectedFees = RecommendedFees(
            fastestFee: 20,
            halfHourFee: 10,
            hourFee: 5,
            economyFee: 3,
            minimumFee: 1
        )
        let viewModel = FeeViewModel(
            feeClient: .test(fetchFees: { expectedFees })
        )

        await viewModel.getFees()

        XCTAssertEqual(viewModel.recommendedFees, expectedFees)
        XCTAssertEqual(viewModel.availableFees, [1, 5, 10, 20])
        XCTAssertEqual(viewModel.selectedFee, 10)
        XCTAssertEqual(viewModel.selectedFeeDescription, "Selected Medium Priority Fee: 10 sats")
        XCTAssertFalse(viewModel.isUsingManualFeeFallback)
        XCTAssertNil(viewModel.feeViewError)
    }

    func testGetFeesFailureUsesManualFallback() async {
        let viewModel = FeeViewModel(
            feeClient: .test(fetchFees: {
                throw TestError.expected("offline")
            })
        )

        await viewModel.getFees()

        XCTAssertNil(viewModel.recommendedFees)
        XCTAssertEqual(viewModel.availableFees, [1, 2, 5, 10])
        XCTAssertTrue(viewModel.isUsingManualFeeFallback)
        XCTAssertEqual(
            viewModel.feeViewError?.description,
            "Couldn't load recommended fee rates. Check your connection and try again."
        )
        XCTAssertEqual(viewModel.selectedFeeDescription, "Selected manual fee: 5 sat/vB")
    }

    func testGetFeesSkipsRefetchWhenCacheExistsAndRefreshNotForced() async {
        actor Probe {
            private(set) var fetchCount = 0

            func fetch() -> RecommendedFees {
                fetchCount += 1
                return RecommendedFees(
                    fastestFee: 30,
                    halfHourFee: 15,
                    hourFee: 8,
                    economyFee: 4,
                    minimumFee: 2
                )
            }
        }

        let probe = Probe()
        let viewModel = FeeViewModel(
            feeClient: .test(fetchFees: {
                await probe.fetch()
            })
        )

        await viewModel.getFees()
        await viewModel.getFees()

        let fetchCount = await probe.fetchCount
        XCTAssertEqual(fetchCount, 1)
    }

    func testGetFeesForceRefreshRefetchesEvenWhenCacheExists() async {
        actor Probe {
            private var responses: [RecommendedFees]
            private(set) var fetchCount = 0

            init(responses: [RecommendedFees]) {
                self.responses = responses
            }

            func fetch() -> RecommendedFees {
                fetchCount += 1
                return responses.removeFirst()
            }
        }

        let first = RecommendedFees(
            fastestFee: 12,
            halfHourFee: 8,
            hourFee: 4,
            economyFee: 2,
            minimumFee: 1
        )
        let second = RecommendedFees(
            fastestFee: 24,
            halfHourFee: 16,
            hourFee: 8,
            economyFee: 4,
            minimumFee: 2
        )
        let probe = Probe(responses: [first, second])
        let viewModel = FeeViewModel(
            feeClient: .test(fetchFees: {
                await probe.fetch()
            })
        )

        await viewModel.getFees()
        await viewModel.getFees(forceRefresh: true)

        let fetchCount = await probe.fetchCount
        XCTAssertEqual(fetchCount, 2)
        XCTAssertEqual(viewModel.recommendedFees, second)
        XCTAssertEqual(viewModel.availableFees, [2, 8, 16, 24])
    }
}
