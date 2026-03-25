import CKTap
import XCTest

@testable import SatsBuddy

final class SatsCardAuthenticityVerifierTests: XCTestCase {
    func testInvalidRootCertificateMapsToNotGenuine() {
        let error = SatsCardAuthenticityError(
            certsError: .InvalidRootCert(msg: "root mismatch")
        )

        XCTAssertEqual(error, .notGenuine)
        XCTAssertEqual(error.alertMessage, "Verification failed.")
        XCTAssertEqual(
            error.errorDescription,
            "This SATSCARD did not verify as genuine. Do not send funds to this card or sign with it."
        )
    }

    func testTransportFailureMapsToConnectionLost() {
        let error = SatsCardAuthenticityError(
            certsError: .CkTap(err: .Transport(msg: "timed out"))
        )

        XCTAssertEqual(error, .transportInterrupted)
        XCTAssertEqual(error.alertMessage, "Connection lost.")
        XCTAssertEqual(
            error.errorDescription,
            "Lost connection while verifying this SATSCARD. Keep the original card steady near the top of your iPhone and try again."
        )
    }

    func testKeyFailureMapsToRetryableVerificationFailure() {
        let error = SatsCardAuthenticityError(
            certsError: .Key(err: .KeyFromSlice(msg: "bad key"))
        )

        XCTAssertEqual(error, .verificationFailed)
        XCTAssertEqual(error.alertMessage, "Verification failed.")
        XCTAssertEqual(
            error.errorDescription,
            "Couldn't verify this SATSCARD as genuine. Keep the original card steady near the top of your iPhone and try again."
        )
    }
}
