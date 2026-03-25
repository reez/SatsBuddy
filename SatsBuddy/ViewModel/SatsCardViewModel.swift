//
//  SatsCardViewModel.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/2/25.
//

import CKTap
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
    var price: Price?
    var priceErrorMessage: String?

    let ckTapClient: CkTapClient
    private let priceClient: PriceClient
    private let cardsStore: CardsKeychainClient
    private var currentNFCReadTask: Task<Void, Never>?
    private var currentNFCReadTaskToken: UUID?
    private var currentOperation: Operation = .scan
    private var preserveStatusOnCurrentSessionInvalidation = false

    override init() {
        let bdkClient = BdkClient.live
        self.ckTapClient = .live(bdk: bdkClient)
        self.cardsStore = .live
        self.priceClient = .live
        super.init()
        loadPersistedCards()
    }

    init(
        ckTapService: CkTapClient,
        cardsStore: CardsKeychainClient = .live,
        priceClient: PriceClient = .live
    ) {
        self.ckTapClient = ckTapService
        self.cardsStore = cardsStore
        self.priceClient = priceClient
        super.init()
        loadPersistedCards()
    }

    func refreshPrice() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let latest = try await priceClient.fetchPrice()
                await MainActor.run {
                    self.price = latest
                    self.priceErrorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.priceErrorMessage = error.localizedDescription
                }
            }
        }
    }

    enum Operation {
        case scan
        case setupNextSlot(card: SatsCardInfo, cvc: String)
    }

    private enum SetupNextSlotError: LocalizedError {
        case wrongCard
        case incorrectCvc(cooldownSeconds: Int?)
        case rateLimited(cooldownSeconds: Int?)
        case enterCvc
        case noUnusedSlots
        case transportInterrupted
        case slotAdvancedRefreshRequired
        case raw(String)

        var errorDescription: String? {
            switch self {
            case .wrongCard:
                return "Wrong SATSCARD detected. Tap the original card and try again."
            case .incorrectCvc(let cooldownSeconds):
                if let cooldownSeconds {
                    return
                        "Incorrect CVC. Wait \(cooldownSeconds) \(cooldownSeconds == 1 ? "second" : "seconds"), then try again."
                }
                return
                    "Incorrect CVC. Check the 6-digit code on the back of your SATSCARD and try again."
            case .rateLimited(let cooldownSeconds):
                if let cooldownSeconds {
                    return
                        "Too many incorrect CVC attempts. Wait \(cooldownSeconds) \(cooldownSeconds == 1 ? "second" : "seconds"), then try again."
                }
                return
                    "Too many incorrect CVC attempts. Wait a moment, then try again."
            case .enterCvc:
                return "Enter your SATSCARD CVC to set up the next slot."
            case .noUnusedSlots:
                return "This SATSCARD has no unused slots left."
            case .transportInterrupted:
                return
                    "Connection to the SATSCARD was interrupted. Keep the card steady and try again."
            case .slotAdvancedRefreshRequired:
                return
                    "Next slot was created, but SatsBuddy could not refresh the card details. Refresh the card before trying again."
            case .raw(let message):
                return message
            }
        }
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        Log.nfc.info("NFC session became active")
        DispatchQueue.main.async {
            switch self.currentOperation {
            case .scan:
                self.lastStatusMessage = "Scanning for Card..."
            case .setupNextSlot:
                let message = "Hold your iPhone near the SATSCARD to set up the next slot."
                self.lastStatusMessage = message
                session.alertMessage = message
            }
            self.isScanning = true
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Swift.Error)
    {
        guard self.tagSession === session else {
            Log.nfc.debug("Ignoring stale NFC invalidation")
            return
        }

        Log.nfc.info("Session invalidated: \(error.localizedDescription, privacy: .public)")
        tagSession = nil
        currentNFCReadTask?.cancel()
        currentNFCReadTask = nil
        currentNFCReadTaskToken = nil
        let invalidatedOperation = currentOperation
        currentOperation = .scan
        let preserveStatus = preserveStatusOnCurrentSessionInvalidation
        preserveStatusOnCurrentSessionInvalidation = false

        Task { @MainActor in
            self.isScanning = false

            if preserveStatus {
                return
            }

            if let nfcError = error as? NFCReaderError,
                nfcError.code == .readerSessionInvalidationErrorUserCanceled
            {
                switch invalidatedOperation {
                case .scan:
                    self.lastStatusMessage = "Scan cancelled."
                case .setupNextSlot:
                    self.lastStatusMessage = "Next slot setup cancelled."
                }
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
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        Log.nfc.info("Tag(s) detected: count=\(tags.count)")
        guard let firstTag = tags.first else {
            let message = "Could not detect tag."
            Task { @MainActor in
                self.lastStatusMessage = message
                self.tagSession?.alertMessage = message
                Haptics.error()
            }
            invalidateSessionPreservingStatus(session, errorMessage: message)
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
                let message = "Connection failed."
                self.invalidateSessionPreservingStatus(session, errorMessage: message)
                Task { @MainActor in
                    self.lastStatusMessage = message
                    self.tagSession?.alertMessage = message
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
                        self?.tagSession?.alertMessage = "Card not compatible."
                    }
                    if !Task.isCancelled {
                        self.invalidateSessionPreservingStatus(
                            session,
                            errorMessage: "Card not compatible."
                        )
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
                        cardInfo = try await self.performSetupNextSlot(
                            transport: transport,
                            target: target,
                            cvc: cvc
                        )
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
                        self.invalidateSessionPreservingStatus(session)
                    }

                } catch {
                    if Task.isCancelled { return }

                    Log.cktap.error(
                        "CKTap error: \(error.localizedDescription, privacy: .private(mask: .hash))"
                    )
                    let message = self.userFacingMessage(
                        for: error,
                        operation: self.currentOperation
                    )
                    await MainActor.run { [weak self] in
                        self?.lastStatusMessage = message
                        self?.tagSession?.alertMessage = message
                        if let setupError = error as? SetupNextSlotError,
                            case .slotAdvancedRefreshRequired = setupError
                        {
                            Haptics.success()
                        } else {
                            Haptics.error()
                        }
                    }
                    if !Task.isCancelled {
                        self.invalidateSessionPreservingStatus(session, errorMessage: message)
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
        preserveStatusOnCurrentSessionInvalidation = false
        let previousSession = tagSession
        tagSession = nil
        previousSession?.invalidate()

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
            lastStatusMessage = "Enter your SATSCARD CVC to set up the next slot."
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
        preserveStatusOnCurrentSessionInvalidation = false
        let previousSession = tagSession
        tagSession = nil
        previousSession?.invalidate()

        currentOperation = .setupNextSlot(card: card, cvc: trimmed)
        tagSession = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        let message = "Hold your iPhone near the SATSCARD to set up the next slot."
        lastStatusMessage = message
        tagSession?.alertMessage = message
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

    private func performSetupNextSlot(
        transport: CkTransport,
        target: SatsCardInfo,
        cvc: String
    ) async throws -> SatsCardInfo {
        await updateStatus(
            "Checking SATSCARD status…",
            alertMessage: "Checking SATSCARD status…"
        )

        let cardType = try await CKTap.toCktap(transport: transport)
        guard case .satsCard(let satsCard) = cardType else {
            throw CkTapCardError.unsupportedCard("Only SATSCARD is supported for this flow.")
        }

        let liveStatus = await satsCard.status()
        let liveCardIdentifier =
            liveStatus.cardIdent.isEmpty ? liveStatus.pubkey : liveStatus.cardIdent
        guard liveCardIdentifier == target.cardIdentifier else {
            Log.cktap.error(
                "Wrong SATSCARD for setupNextSlot: expected=\(target.cardIdentifier, privacy: .private(mask: .hash)) actual=\(liveCardIdentifier, privacy: .private(mask: .hash))"
            )
            throw SetupNextSlotError.wrongCard
        }

        if let cooldownSeconds = Self.cooldownSeconds(from: liveStatus.authDelay) {
            try await waitForSetupCooldown(satsCard: satsCard, seconds: cooldownSeconds)
        }

        await updateStatus(
            "Setting up the next slot…",
            alertMessage: "Setting up the next slot…"
        )

        let nextSlot: UInt8
        do {
            nextSlot = try await satsCard.newSlot(cvc: cvc)
        } catch {
            let postAttemptStatus = await satsCard.status()
            throw setupNextSlotError(from: error, authDelay: postAttemptStatus.authDelay)
        }

        Log.cktap.info("newSlot completed -> next active slot \(nextSlot)")

        await updateStatus(
            "Refreshing card details…",
            alertMessage: "Refreshing card details…"
        )

        do {
            return try await ckTapClient.readCardInfo(transport)
        } catch {
            Log.cktap.error(
                "Next slot was created but refresh failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
            throw SetupNextSlotError.slotAdvancedRefreshRequired
        }
    }

    private func waitForSetupCooldown(satsCard: CKTap.SatsCard, seconds: Int) async throws {
        let countdownTask = startSetupCooldownCountdown(seconds: seconds)
        defer { countdownTask.cancel() }

        do {
            try await satsCard.wait()
            await updateStatus(
                "Cooldown complete. Setting up the next slot…",
                alertMessage: "Cooldown complete. Setting up the next slot…"
            )
        } catch {
            throw setupNextSlotError(from: error, authDelay: UInt8(seconds))
        }
    }

    private func startSetupCooldownCountdown(seconds: Int) -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }
            var remainingSeconds = seconds

            while !Task.isCancelled && remainingSeconds > 0 {
                let message = self.cooldownCountdownMessage(seconds: remainingSeconds)
                await self.updateStatus(message, alertMessage: message)

                if remainingSeconds == 1 {
                    break
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000)
                remainingSeconds -= 1
            }
        }
    }

    private func cooldownCountdownMessage(seconds: Int) -> String {
        "SATSCARD security cooldown: keep the card near your iPhone for \(seconds) \(seconds == 1 ? "more second" : "more seconds")."
    }

    private func userFacingMessage(for error: Error, operation: Operation) -> String {
        switch operation {
        case .scan:
            if let localizedError = error as? LocalizedError,
                let description = localizedError.errorDescription
            {
                return description
            }
            return "Error: \(error.localizedDescription)"

        case .setupNextSlot:
            if let setupError = error as? SetupNextSlotError,
                let description = setupError.errorDescription
            {
                return description
            }

            return setupNextSlotError(from: error, authDelay: nil).errorDescription
                ?? "Error: \(error.localizedDescription)"
        }
    }

    private func setupNextSlotError(from error: Error, authDelay: UInt8?) -> SetupNextSlotError {
        if let setupError = error as? SetupNextSlotError {
            return setupError
        }

        if let ckTapCardError = error as? CkTapCardError,
            let description = ckTapCardError.errorDescription
        {
            return .raw(description)
        }

        if let cardError = extractCardError(from: error) {
            switch cardError {
            case .BadAuth:
                return .incorrectCvc(cooldownSeconds: Self.cooldownSeconds(from: authDelay))
            case .RateLimited:
                return .rateLimited(cooldownSeconds: Self.cooldownSeconds(from: authDelay))
            case .NeedsAuth:
                return .enterCvc
            case .InvalidState:
                return .noUnusedSlots
            default:
                break
            }
        }

        if extractTransportMessage(from: error) != nil {
            return .transportInterrupted
        }

        if let localizedError = error as? LocalizedError,
            let description = localizedError.errorDescription
        {
            return .raw(description)
        }

        return .raw("Error: \(error.localizedDescription)")
    }

    private func extractCardError(from error: Error) -> CardError? {
        guard let ckTapError = extractCkTapError(from: error) else { return nil }
        if case .Card(let cardError) = ckTapError {
            return cardError
        }
        return nil
    }

    private func extractTransportMessage(from error: Error) -> String? {
        guard let ckTapError = extractCkTapError(from: error) else { return nil }
        if case .Transport(let message) = ckTapError {
            return message
        }
        return nil
    }

    private func extractCkTapError(from error: Error) -> CkTapError? {
        switch error {
        case let ckTapError as CkTapError:
            return ckTapError
        case let deriveError as DeriveError:
            if case .CkTap(let ckTapError) = deriveError {
                return ckTapError
            }
        case let statusError as StatusError:
            if case .CkTap(let ckTapError) = statusError {
                return ckTapError
            }
        default:
            break
        }

        return nil
    }

    private static func cooldownSeconds(from authDelay: UInt8?) -> Int? {
        guard let authDelay, authDelay > 0 else { return nil }
        return Int(authDelay)
    }

    private func updateStatus(_ message: String, alertMessage: String? = nil) async {
        await MainActor.run {
            self.lastStatusMessage = message
            self.tagSession?.alertMessage = alertMessage ?? message
        }
    }

    private func invalidateSessionPreservingStatus(
        _ session: NFCTagReaderSession,
        errorMessage: String? = nil
    ) {
        preserveStatusOnCurrentSessionInvalidation = true
        if let errorMessage {
            session.invalidate(errorMessage: errorMessage)
        } else {
            session.invalidate()
        }
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
