//
//  NFCTransport.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/2/25.
//

import CKTap
import CoreNFC
import Foundation
import os

enum NFCError: Error, LocalizedError {
    case connectionFailed(String)
    case timeout(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "NFC Connection Failed: \(message)"
        case .timeout(let message):
            return "NFC Timeout: \(message)"
        }
    }
}

final class NFCTransport: NSObject, CkTransport {

    private let tag: NFCISO7816Tag

    init(tag: NFCISO7816Tag) {
        self.tag = tag
        Log.nfc.debug("NFCTransport initialized")
    }

    func transmitApdu(commandApdu: Data) throws -> Data {
        let start = Date()
        Log.nfc.debug(
            "APDU -> (len: \(commandApdu.count)) \(commandApdu.hexEncodedString(), privacy: .private(mask: .hash))"
        )

        guard let iso7816Apdu = NFCISO7816APDU(data: commandApdu) else {
            Log.nfc.error(
                "Failed to construct NFCISO7816APDU from data (len: \(commandApdu.count))"
            )
            throw NFCError.connectionFailed("Invalid APDU data")
        }

        var responseData: Data?
        var responseError: Swift.Error?
        let semaphore = DispatchSemaphore(value: 0)

        tag.sendCommand(apdu: iso7816Apdu) { (data, sw1, sw2, error) in
            if let error = error {
                Log.nfc.error("sendCommand error: \(error.localizedDescription, privacy: .public)")
                responseError = error
            } else {
                var response = data
                response.append(sw1)
                response.append(sw2)
                Log.nfc.debug(
                    "APDU <- (len: \(response.count)) \(response.hexEncodedString(), privacy: .private(mask: .hash))"
                )
                responseData = response
            }
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 15.0)

        if let error = responseError {
            throw NFCError.connectionFailed(error.localizedDescription)
        }

        guard let data = responseData else {
            throw NFCError.timeout("NFC command timed out or returned no data.")
        }

        let sw = data.suffix(2)
        if sw != Data([0x90, 0x00]) {
            Log.nfc.warning(
                "APDU SW not OK: \(sw.hexEncodedString(), privacy: .private(mask: .hash))"
            )
        }

        let elapsed = Date().timeIntervalSince(start)
        Log.nfc.debug("APDU round-trip: \(String(format: "%.2f", elapsed))s")
        return data
    }
}

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
