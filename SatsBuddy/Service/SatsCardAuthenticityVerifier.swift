import CKTap
import Foundation
import os

enum SatsCardAuthenticityError: LocalizedError, Equatable {
    case notGenuine
    case verificationFailed
    case transportInterrupted

    init(certsError: CertsError) {
        switch certsError {
        case .InvalidRootCert:
            self = .notGenuine
        case .CkTap(let error):
            switch error {
            case .Transport:
                self = .transportInterrupted
            case .Card, .CborDe, .CborValue, .UnknownCardType:
                self = .verificationFailed
            }
        case .Key:
            self = .verificationFailed
        }
    }

    var errorDescription: String? {
        switch self {
        case .notGenuine:
            return
                "This SATSCARD did not verify as genuine. Do not send funds to this card or sign with it."
        case .verificationFailed:
            return
                "Couldn't verify this SATSCARD as genuine. Keep the original card steady near the top of your iPhone and try again."
        case .transportInterrupted:
            return
                "Lost connection while verifying this SATSCARD. Keep the original card steady near the top of your iPhone and try again."
        }
    }

    var alertMessage: String {
        switch self {
        case .notGenuine, .verificationFailed:
            return "Verification failed."
        case .transportInterrupted:
            return "Connection lost."
        }
    }
}

enum SatsCardAuthenticityVerifier {
    static func verify(_ satsCard: SatsCard) async throws {
        do {
            try await satsCard.checkCert()
        } catch let certsError as CertsError {
            Log.cktap.error(
                "SATSCARD authenticity verification failed: \(String(reflecting: certsError), privacy: .public)"
            )
            throw SatsCardAuthenticityError(certsError: certsError)
        }
    }
}
