//
//  SatsCardViewModel.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/2/25.
//

import CoreNFC
import Foundation
import Observation
import SwiftUI
import os

@Observable
class SatsCardViewModel: NSObject, NFCTagReaderSessionDelegate {

    var tagSession: NFCTagReaderSession?
    var lastStatusMessage: String = "Tap + to scan card"
    var isScanning: Bool = false
    var scannedCards: [SatsCardInfo] = []

    let ckTapClient: CkTapClient

    override init() {
        self.ckTapClient = .live(bdk: .live)
        super.init()
    }

    init(ckTapService: CkTapClient) {
        self.ckTapClient = ckTapService
        super.init()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        Log.nfc.info("NFC session became active")
        DispatchQueue.main.async {
            self.lastStatusMessage = "Scanning for Card..."
            self.isScanning = true
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Swift.Error)
    {
        Log.nfc.info("Session invalidated: \(error.localizedDescription, privacy: .public)")
        Task { @MainActor in
            if let nfcError = error as? NFCReaderError,
                nfcError.code == .readerSessionInvalidationErrorUserCanceled
            {
                self.lastStatusMessage = "Scan cancelled."
            } else if let nfcError = error as? NFCReaderError,
                nfcError.code == .readerSessionInvalidationErrorSessionTerminatedUnexpectedly
            {
                self.lastStatusMessage = "Session terminated."
            } else {
                self.lastStatusMessage = "NFC Error: \(error.localizedDescription)"
            }
            self.isScanning = false
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        Log.nfc.info("Tag(s) detected: count=\(tags.count)")
        guard let firstTag = tags.first else {
            session.invalidate(errorMessage: "Could not detect tag.")
            return
        }

        Task { @MainActor in self.lastStatusMessage = "Card detected, connecting..." }

        Log.nfc.debug("Connecting to first tag…")
        session.connect(to: firstTag) { [weak self] (error: Swift.Error?) in
            guard let self = self else { return }

            if let error = error {
                Log.nfc.error("Tag connect error: \(error.localizedDescription, privacy: .public)")
                session.invalidate(errorMessage: "Connection failed.")
                Task { @MainActor in self.lastStatusMessage = "Connection failed." }
                return
            }

            Log.nfc.info("Connected to tag")
            Task {
                guard case .iso7816(let iso7816Tag) = firstTag else {
                    Log.nfc.error("Tag is not ISO7816 compatible")
                    await MainActor.run { self.lastStatusMessage = "Card not compatible." }
                    session.invalidate(errorMessage: "Card not compatible.")
                    return
                }

                await MainActor.run { self.lastStatusMessage = "Card connected, getting status..." }

                do {
                    let transport = NFCTransport(tag: iso7816Tag)
                    let cardInfo = try await self.ckTapClient.readCardInfo(transport)
                    await MainActor.run {
                        let updated = CardsStore.upsert(&self.scannedCards, with: cardInfo)
                        self.lastStatusMessage =
                            updated ? "Card updated with latest data 🔄" : "New card added ✅"
                        self.isScanning = false
                    }
                    session.invalidate()

                } catch {
                    Log.cktap.error(
                        "CKTap error: \(String(describing: error), privacy: .public)"
                    )
                    let message: String
                    if let localizedError = error as? LocalizedError,
                        let description = localizedError.errorDescription
                    {
                        message = description
                    } else {
                        message = "Error: \(error.localizedDescription)"
                    }
                    await MainActor.run {
                        self.lastStatusMessage = message
                    }
                    session.invalidate(errorMessage: message)
                }
            }
        }
    }

    func beginNFCSession() {
        guard NFCTagReaderSession.readingAvailable else {
            Log.nfc.error("NFC reading not available on this device")
            lastStatusMessage = "NFC not available on this device"
            return
        }

        tagSession?.invalidate()

        tagSession = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        tagSession?.alertMessage = "Hold your iPhone near the SatsCard."
        tagSession?.begin()

        Log.nfc.info("NFC session started")
    }

    func removeCard(_ card: SatsCardInfo) {
        scannedCards.removeAll { $0.id == card.id }
    }

    func refreshCard(_ card: SatsCardInfo) {
        beginNFCSession()
    }
}
