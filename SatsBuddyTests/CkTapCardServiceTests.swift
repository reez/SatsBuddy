import XCTest

@testable import SatsBuddy

final class CkTapCardServiceTests: XCTestCase {
    func testShouldVerifyAuthenticityReturnsFalseWhenActiveSlotAddressMissing() {
        XCTAssertFalse(CkTapCardService.shouldVerifyAuthenticity(activeSlotAddress: nil))
        XCTAssertFalse(CkTapCardService.shouldVerifyAuthenticity(activeSlotAddress: ""))
        XCTAssertFalse(CkTapCardService.shouldVerifyAuthenticity(activeSlotAddress: "   "))
    }

    func testShouldVerifyAuthenticityReturnsTrueWhenActiveSlotAddressPresent() {
        XCTAssertTrue(
            CkTapCardService.shouldVerifyAuthenticity(activeSlotAddress: "bc1qexampleaddress")
        )
    }
}
