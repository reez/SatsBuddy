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
import UIKit
import os

@Observable
class SatsCardViewModel: NSObject, NFCTagReaderSessionDelegate {

    var tagSession: NFCTagReaderSession?
    var lastStatusMessage: String = "Tap + to scan card"
    var isScanning: Bool = false
    var scannedCards: [SatsCardInfo] = []
    var detailLoadingCardIdentifier: String?

    let ckTapClient: CkTapClient
    private let cardsStore: CardsKeychainClient
    private var currentNFCReadTask: Task<Void, Never>?
    private var currentNFCReadTaskToken: UUID?
    private var currentOperation: Operation = .scan

    override init() {
        let bdkClient = BdkClient.live
        self.ckTapClient = .live(bdk: bdkClient)
        self.cardsStore = .live
        super.init()
        loadPersistedCards()
    }

    init(ckTapService: CkTapClient, cardsStore: CardsKeychainClient = .live) {
        self.ckTapClient = ckTapService
        self.cardsStore = cardsStore
        super.init()
        loadPersistedCards()
    }

    enum Operation {
        case scan
        case setupNextSlot(card: SatsCardInfo, cvc: String)
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
        currentNFCReadTask?.cancel()
        currentNFCReadTask = nil
        currentNFCReadTaskToken = nil
        currentOperation = .scan
        Task { @MainActor in
            if let nfcError = error as? NFCReaderError,
                nfcError.code == .readerSessionInvalidationErrorUserCanceled
            {
                self.lastStatusMessage = "Scan cancelled."
                Haptics.error()
            } else if let nfcError = error as? NFCReaderError,
                nfcError.code == .readerSessionInvalidationErrorSessionTerminatedUnexpectedly
            {
                self.lastStatusMessage = "Session terminated."
                Haptics.error()
            } else {
                self.lastStatusMessage = "NFC Error: \(error.localizedDescription)"
                Haptics.error()
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

            self.currentNFCReadTask?.cancel()
            self.currentNFCReadTask = nil
            self.currentNFCReadTaskToken = nil

            if let error = error {
                Log.nfc.error("Tag connect error: \(error.localizedDescription, privacy: .public)")
                session.invalidate(errorMessage: "Connection failed.")
                Task { @MainActor in
                    self.lastStatusMessage = "Connection failed."
                    Haptics.error()
                }
                return
            }

            Log.nfc.info("Connected to tag")
            let taskToken = UUID()
            self.currentNFCReadTaskToken = taskToken
            let task = Task {
                defer {
                    Task { @MainActor [weak self] in
                        guard
                            let self,
                            self.currentNFCReadTaskToken == taskToken
                        else { return }
                        self.currentNFCReadTaskToken = nil
                        self.currentNFCReadTask = nil
                    }
                }

                if Task.isCancelled { return }

                guard case .iso7816(let iso7816Tag) = firstTag else {
                    Log.nfc.error("Tag is not ISO7816 compatible")
                    await MainActor.run { [weak self] in
                        self?.lastStatusMessage = "Card not compatible."
                    }
                    if !Task.isCancelled {
                        session.invalidate(errorMessage: "Card not compatible.")
                    }
                    return
                }

                if Task.isCancelled { return }

                await MainActor.run { [weak self] in
                    self?.lastStatusMessage = "Card connected, getting status..."
                }

                do {
                    if Task.isCancelled { return }
                    let transport = NFCTransport(tag: iso7816Tag)
                    if Task.isCancelled { return }
                    let cardInfo: SatsCardInfo
                    switch self.currentOperation {
                    case .scan:
                        cardInfo = try await self.ckTapClient.readCardInfo(transport)
                    case .setupNextSlot(let target, let cvc):
                        Log.cktap.info(
                            "Starting new slot setup for card \(target.cardIdentifier, privacy: .private(mask: .hash))"
                        )
                        cardInfo = try await self.ckTapClient.setupNextSlot(transport, cvc)
                    }
                    if Task.isCancelled { return }

                    await MainActor.run {
                        let mergedCard = self.mergeCardInfo(with: cardInfo)
                        let updated = CardsStore.upsert(&self.scannedCards, with: mergedCard)
                        switch self.currentOperation {
                        case .scan:
                            self.lastStatusMessage =
                                updated ? "Card updated with latest data 🔄" : "New card added ✅"
                        case .setupNextSlot:
                            self.lastStatusMessage = "Next slot ready ✅"
                        }
                        self.isScanning = false
                        self.persistCards()
                        self.currentOperation = .scan
                        Haptics.success()
                    }

                    if !Task.isCancelled {
                        session.invalidate()
                    }

                } catch {
                    if Task.isCancelled { return }

                    Log.cktap.error(
                        "CKTap error: \(error.localizedDescription, privacy: .private(mask: .hash))"
                    )
                    let message: String
                    if let localizedError = error as? LocalizedError,
                        let description = localizedError.errorDescription
                    {
                        message = description
                    } else {
                        message = "Error: \(error.localizedDescription)"
                    }
                    await MainActor.run { [weak self] in
                        self?.lastStatusMessage = message
                        Haptics.error()
                    }
                    if !Task.isCancelled {
                        session.invalidate(errorMessage: message)
                    }
                }
            }
            self.currentNFCReadTask = task
        }
    }

    func beginNFCSession() {
        guard NFCTagReaderSession.readingAvailable else {
            Log.nfc.error("NFC reading not available on this device")
            lastStatusMessage = "NFC not available on this device"
            return
        }

        currentNFCReadTask?.cancel()
        currentNFCReadTask = nil
        currentNFCReadTaskToken = nil
        tagSession?.invalidate()

        currentOperation = .scan
        tagSession = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        tagSession?.alertMessage = "Hold your iPhone near the SatsCard."
        tagSession?.begin()

        Log.nfc.info("NFC session started")
        Haptics.selection()
    }

    func startSetupNextSlot(for card: SatsCardInfo, cvc: String) {
        let trimmed = cvc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastStatusMessage = "Enter CVC to set up next slot."
            return
        }

        guard NFCTagReaderSession.readingAvailable else {
            Log.nfc.error("NFC reading not available on this device")
            lastStatusMessage = "NFC not available on this device"
            return
        }

        currentNFCReadTask?.cancel()
        currentNFCReadTask = nil
        currentNFCReadTaskToken = nil
        tagSession?.invalidate()

        currentOperation = .setupNextSlot(card: card, cvc: trimmed)
        tagSession = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        tagSession?.alertMessage = "Hold your iPhone near the SatsCard to set up next slot."
        tagSession?.begin()

        Log.nfc.info("NFC session started (setup next slot)")
    }

    func removeCard(_ card: SatsCardInfo) {
        scannedCards.removeAll { $0.id == card.id }
        persistCards()
    }

    func moveCards(from offsets: IndexSet, to destination: Int) {
        scannedCards.move(fromOffsets: offsets, toOffset: destination)
        persistCards()
        Haptics.selection()
    }

    func refreshCard(_ card: SatsCardInfo) {
        beginNFCSession()
    }

    @MainActor
    func updateLabel(for card: SatsCardInfo, to newLabel: String) {
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let index = scannedCards.firstIndex(where: { $0.cardIdentifier == card.cardIdentifier })
        else {
            return
        }

        let normalizedLabel = trimmed.isEmpty ? nil : trimmed
        if scannedCards[index].label == normalizedLabel {
            return
        }

        scannedCards[index].label = normalizedLabel
        persistCards()
    }

    private func loadPersistedCards() {
        do {
            scannedCards = try cardsStore.loadCards()
        } catch {
            Log.ui.error(
                "Failed to load stored cards: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func persistCards() {
        do {
            try cardsStore.saveCards(scannedCards)
        } catch {
            Log.ui.error("Failed to save cards: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    private func mergeCardInfo(with newCard: SatsCardInfo) -> SatsCardInfo {
        guard
            let existing = scannedCards.first(where: { $0.cardIdentifier == newCard.cardIdentifier }
            )
        else {
            return newCard
        }

        return SatsCardInfo(
            id: existing.id,
            version: newCard.version,
            birth: newCard.birth,
            address: newCard.address,
            pubkey: newCard.pubkey,
            cardIdent: newCard.cardIdent,
            cardNonce: newCard.cardNonce,
            activeSlot: newCard.activeSlot,
            totalSlots: newCard.totalSlots,
            slots: newCard.slots,
            isActive: newCard.isActive,
            dateScanned: newCard.dateScanned,
            label: newCard.label ?? existing.label
        )
    }
}

private enum Haptics {
    static func selection() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.7)
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}
