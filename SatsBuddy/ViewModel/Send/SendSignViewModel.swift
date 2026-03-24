//
//  SendSignViewModel.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 11/26/25.
//

import BitcoinDevKit
import CKTap
import CoreNFC
import Foundation
import Observation
import os

@MainActor
@Observable
final class SendSignViewModel: NSObject, @MainActor NFCTagReaderSessionDelegate {
    enum State {
        case idle
        case preparingPsbt
        case ready
        case tapping
        case unsealed
        case done
        case error(String)
    }

    private enum SlotAccessResult {
        case dumped(SlotDetails)
        case unsealed(SlotDetails)

        var detail: SlotDetails {
            switch self {
            case .dumped(let detail), .unsealed(let detail):
                return detail
            }
        }
    }

    private struct PendingInvalidationOutcome {
        let phase: StatusPhase
        let state: State
    }

    private enum StatusPhase {
        case preparingSweep
        case readyToSignAndBroadcast
        case stillPreparing
        case enterCvc
        case nfcUnavailable
        case waitingForCard
        case checkingCard
        case waitingForSecurityDelay(seconds: Int)
        case readingSlotDetails
        case unsealingActiveSlot
        case signingTransaction
        case broadcastingTransaction
        case broadcasted(txid: String?)
        case nfcCancelled
        case noTagFound
        case connectionFailed
        case unsupportedTag
        case raw(String)
        case failed(String)

        var screenMessage: String {
            switch self {
            case .preparingSweep:
                return "Preparing sweep transaction…"
            case .readyToSignAndBroadcast:
                return "Transaction ready. Enter CVC and tap your card to sign and broadcast."
            case .stillPreparing:
                return "Still preparing transaction…"
            case .enterCvc:
                return "Enter CVC to continue."
            case .nfcUnavailable:
                return "NFC not available on this device."
            case .waitingForCard:
                return "Hold your iPhone near the SATSCARD."
            case .checkingCard:
                return "Checking SATSCARD status…"
            case .waitingForSecurityDelay(let seconds):
                return SendSignViewModel.securityDelayMessage(seconds: seconds)
            case .readingSlotDetails:
                return "Reading slot details…"
            case .unsealingActiveSlot:
                return "Unsealing active slot…"
            case .signingTransaction:
                return "Finalizing signed transaction…"
            case .broadcastingTransaction:
                return "Broadcasting transaction…"
            case .broadcasted:
                return "Transaction broadcasted successfully."
            case .nfcCancelled:
                return "NFC cancelled."
            case .noTagFound:
                return "No SATSCARD detected. Hold your iPhone near the card and try again."
            case .connectionFailed:
                return
                    "Lost connection to the SATSCARD. Keep it near the top of your iPhone and try again."
            case .unsupportedTag:
                return "This tag is not a supported SATSCARD. Try the original card again."
            case .raw(let message):
                return message
            case .failed(let message):
                return "Sign and broadcast failed: \(message)"
            }
        }

        var nfcAlertMessage: String? {
            switch self {
            case .waitingForCard:
                return "Hold your iPhone near the SATSCARD."
            case .checkingCard:
                return "Checking SATSCARD status…"
            case .waitingForSecurityDelay(let seconds):
                return "Cooling off: \(seconds)s remaining…"
            case .readingSlotDetails:
                return "Reading slot details…"
            case .unsealingActiveSlot:
                return "Unsealing active slot…"
            case .signingTransaction:
                return "Finalizing signed transaction…"
            case .broadcastingTransaction:
                return "Broadcasting transaction…"
            case .broadcasted:
                return "Transaction broadcasted successfully"
            default:
                return nil
            }
        }
    }

    let address: String
    let feeRate: Int
    let slot: SlotInfo
    let expectedCardIdentifier: String
    let network: Network
    private let bdkClient: BdkClient

    var cvc: String = ""
    var statusMessage: String = StatusPhase.preparingSweep.screenMessage
    var psbtBase64: String?
    var signedTxid: String?
    var psbtError: String?
    var txHex: String?
    var state: State = .idle
    var isBusy: Bool {
        switch state {
        case .preparingPsbt, .tapping:
            return true
        default:
            return false
        }
    }
    var canStartNfc: Bool {
        if case .ready = state {
            return hasPreparedPsbt
        }
        return false
    }
    var isBroadCasted = false

    private var session: NFCTagReaderSession?
    private var psbt: Psbt?
    private var didRunPreflight = false
    private var pendingInvalidationOutcome: PendingInvalidationOutcome?
    private var latestAuthDelaySeconds: Int?
    private var hasPreparedPsbt: Bool {
        psbt != nil && psbtError == nil
    }

    init(
        address: String,
        feeRate: Int,
        slot: SlotInfo,
        expectedCardIdentifier: String,
        network: Network,
        bdkClient: BdkClient = .live
    ) {
        self.address = address
        self.feeRate = feeRate
        self.slot = slot
        self.expectedCardIdentifier = expectedCardIdentifier
        self.network = network
        self.bdkClient = bdkClient
        self.state = .preparingPsbt
        self.statusMessage = StatusPhase.preparingSweep.screenMessage
    }

    // MARK: - NFC

    func runPreflightIfNeeded() async {
        guard !didRunPreflight else { return }
        didRunPreflight = true

        state = .preparingPsbt
        psbt = nil
        psbtBase64 = nil
        psbtError = nil
        setStatusMessage(.preparingSweep)

        do {
            let sourceDescriptor: String
            if let slotDescriptor = slot.pubkeyDescriptor?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ), !slotDescriptor.isEmpty {
                sourceDescriptor = slotDescriptor
            } else if let slotPubkey = slot.pubkey?.trimmingCharacters(in: .whitespacesAndNewlines),
                !slotPubkey.isEmpty
            {
                // Compatibility fallback for older cached slot data that predates descriptor storage.
                sourceDescriptor = "wpkh(\(slotPubkey))"
            } else {
                let message =
                    "Unable to prepare the transaction for this slot. Refresh the card and try again."
                psbtError = message
                setStatusMessage(.raw(message))
                state = .error(message)
                return
            }

            let preparedPsbt = try await bdkClient.buildPsbt(
                sourceDescriptor,
                address,
                UInt64(feeRate),
                network
            )
            psbt = preparedPsbt
            psbtBase64 = preparedPsbt.serialize()
            state = .ready
            setStatusMessage(.readyToSignAndBroadcast)
        } catch {
            let message = friendlyError(for: error)
            psbt = nil
            psbtBase64 = nil
            psbtError = message
            state = .error(message)
            setStatusMessage(.raw(message))
        }
    }

    func startNfc() {
        guard case .ready = state else {
            if case .preparingPsbt = state {
                setStatusMessage(.stillPreparing)
            }
            return
        }

        guard hasPreparedPsbt else {
            let message = psbtError ?? "Transaction not ready. Go back and try again."
            psbtError = message
            setStatusMessage(.raw(message))
            return
        }

        guard !cvc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setStatusMessage(.enterCvc)
            return
        }

        guard NFCTagReaderSession.readingAvailable else {
            setStatusMessage(.nfcUnavailable)
            return
        }

        pendingInvalidationOutcome = nil
        latestAuthDelaySeconds = nil
        let previousSession = session
        session = nil
        previousSession?.invalidate()
        session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        session?.begin()

        state = .tapping
        setStatusMessage(.waitingForCard)
        Log.nfc.info("[SendSign] NFC session started for signing")
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        Log.nfc.info("[SendSign] NFC session active")
    }

    func tagReaderSession(
        _ session: NFCTagReaderSession,
        didInvalidateWithError error: any Error
    ) {
        guard self.session === session else {
            Log.nfc.debug("[SendSign] Ignoring stale NFC invalidation")
            return
        }

        self.session = nil

        // If we already succeeded, ignore spurious invalidations.
        switch state {
        case .done, .unsealed:
            return
        default:
            break
        }

        if let pendingInvalidationOutcome {
            self.pendingInvalidationOutcome = nil
            setStatusMessage(pendingInvalidationOutcome.phase)
            state = pendingInvalidationOutcome.state
            return
        }

        if case let nfcError as NFCReaderError = error,
            nfcError.code == .readerSessionInvalidationErrorUserCanceled
        {
            setStatusMessage(.nfcCancelled)
            state = .ready
            return
        }

        setStatusMessage(.failed(error.localizedDescription))
        state = .error(error.localizedDescription)
        Log.nfc.error(
            "[SendSign] session invalidated: \(error.localizedDescription, privacy: .public)"
        )
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let first = tags.first else {
            finishAfterSessionInvalidation(
                phase: .noTagFound,
                nextState: .ready,
                alertMessage: "No SATSCARD detected."
            )
            return
        }

        session.connect(to: first) { [weak self] error in
            guard let self else { return }
            if let error = error {
                Log.nfc.error(
                    "[SendSign] connect failed: \(error.localizedDescription, privacy: .public)"
                )
                Task { @MainActor in
                    self.finishAfterSessionInvalidation(
                        phase: .connectionFailed,
                        nextState: .ready,
                        alertMessage: "Connection failed."
                    )
                }
                return
            }

            guard case .iso7816(let iso7816Tag) = first else {
                Task { @MainActor in
                    self.finishAfterSessionInvalidation(
                        phase: .unsupportedTag,
                        nextState: .ready,
                        alertMessage: "Unsupported tag."
                    )
                }
                return
            }

            Task { await self.handleTag(tag: iso7816Tag) }
        }
    }

    private func handleTag(tag: NFCISO7816Tag) async {
        do {
            let transport = NFCTransport(tag: tag)
            let cardType = try await CKTap.toCktap(transport: transport)
            guard case .satsCard(let satsCard) = cardType else {
                throw NSError(
                    domain: "SendSign",
                    code: 3,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Only SATSCARD supported for this signing flow"
                    ]
                )
            }

            let targetSlot = slot.slotNumber
            guard let preparedPsbt = psbt else {
                throw NSError(
                    domain: "SendSign",
                    code: 6,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            psbtError ?? "Transaction not prepared. Go back and try again."
                    ]
                )
            }

            state = .preparingPsbt
            setStatusMessage(.checkingCard)

            var liveStatus = await satsCard.status()
            let liveCardIdentifier =
                liveStatus.cardIdent.isEmpty ? liveStatus.pubkey : liveStatus.cardIdent
            guard liveCardIdentifier == expectedCardIdentifier else {
                Log.nfc.error(
                    "[SendSign] Wrong card detected: expected=\(self.expectedCardIdentifier, privacy: .private(mask: .hash)) actual=\(liveCardIdentifier, privacy: .private(mask: .hash))"
                )
                throw NSError(
                    domain: "SendSign",
                    code: 6,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Wrong SATSCARD detected. Tap the original card and try again."
                    ]
                )
            }

            latestAuthDelaySeconds = liveStatus.authDelay.map(Int.init)
            if let authDelay = latestAuthDelaySeconds, authDelay > 0 {
                Log.nfc.info(
                    "[SendSign] Auth delay active for \(authDelay) seconds. Waiting for cooldown…"
                )
                try await waitForSecurityDelay(satsCard: satsCard, seconds: authDelay)
                liveStatus = await satsCard.status()
                latestAuthDelaySeconds = liveStatus.authDelay.map(Int.init)
            }

            Log.nfc.info(
                "[SendSign] Live status: activeSlot=\(liveStatus.activeSlot) targetSlot=\(targetSlot)"
            )

            let slotAccess = try await dumpOrUnseal(
                targetSlot: targetSlot,
                activeSlot: liveStatus.activeSlot,
                satsCard: satsCard
            )

            let detail = slotAccess.detail
            switch slotAccess {
            case .dumped:
                Log.nfc.info(
                    "[SendSign] Slot \(targetSlot) details retrieved via dump, signing tx…"
                )
            case .unsealed:
                Log.nfc.info(
                    "[SendSign] Active slot \(targetSlot) unsealed, signing tx…"
                )
            }

            setStatusMessage(.signingTransaction)
            let signedTx = try await buildPsbtAndSign(
                detail: detail,
                targetSlot: targetSlot,
                satsCard: satsCard,
                preparedPsbt: preparedPsbt
            ).extractTx()

            signedTxid = signedTx.computeTxid().description
            txHex = signedTx.serialize().map { String(format: "%02x", $0) }.joined()
            Log.nfc.info(
                "[SendSign] Signed txid=\(self.signedTxid ?? "nil", privacy: .private(mask: .hash))"
            )

            do {
                setStatusMessage(.broadcastingTransaction)
                try await bdkClient.broadcast(signedTx, network)
            } catch {
                Log.nfc.error(
                    "[SendSign] broadcast error: \(error.localizedDescription, privacy: .public)"
                )
                handleTerminalFailure(error)
                return
            }

            cvc = ""
            state = .done
            setStatusMessage(.broadcasted(txid: signedTxid))
            session?.invalidate()
            Log.ui.info(
                "[SendSign] Broadcast success txid=\(self.signedTxid ?? "nil", privacy: .private(mask: .hash))"
            )

            isBroadCasted = true

        } catch {
            Log.nfc.error(
                "[SendSign] handleTag error: \(error.localizedDescription, privacy: .public)"
            )
            handleRecoverableFailure(error)
        }
    }

    private func buildPsbtAndSign(
        detail: SlotDetails,
        targetSlot: UInt8,
        satsCard: SatsCard,
        preparedPsbt: Psbt
    ) async throws -> Psbt {

        let psbtSigned: Psbt?
        let psbtToSign: Psbt

        if let slotDescriptor = slot.pubkeyDescriptor,
            !slotDescriptor.isEmpty,
            slotDescriptor != detail.pubkeyDescriptor
        {
            Log.nfc.error(
                "[SendSign] Preflight descriptor mismatch: slot=\(slotDescriptor, privacy: .private(mask: .hash)) detail=\(detail.pubkeyDescriptor, privacy: .private(mask: .hash))"
            )
            throw NSError(
                domain: "SendSign",
                code: 7,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Tapped card slot does not match the prepared transaction."
                ]
            )
        } else if let slotPubkey = slot.pubkey, slotPubkey != detail.pubkey {
            Log.nfc.error(
                "[SendSign] Preflight pubkey mismatch: slot=\(slotPubkey, privacy: .private(mask: .hash)) detail=\(detail.pubkey, privacy: .private(mask: .hash))"
            )
            throw NSError(
                domain: "SendSign",
                code: 7,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Tapped card slot does not match the prepared transaction."
                ]
            )
        } else {
            psbtToSign = preparedPsbt
        }

        let psbtSignedBase64 = try await satsCard.signPsbt(
            slot: targetSlot,
            psbt: psbtToSign.serialize(),
            cvc: cvc
        )

        psbtSigned = try Psbt(psbtBase64: psbtSignedBase64)
            .finalize()
            .psbt

        guard let psbtSigned else {
            throw NSError(
                domain: "SendSign",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Failed to sign PSBT with CVC / private key."]
            )
        }

        return psbtSigned
    }

    private func waitForSecurityDelay(
        satsCard: CKTap.SatsCard,
        seconds: Int
    ) async throws {
        let countdownTask = startSecurityDelayCountdown(seconds: seconds)
        defer { countdownTask.cancel() }

        setStatusMessage(.waitingForSecurityDelay(seconds: seconds))
        try await satsCard.wait()
    }

    private func startSecurityDelayCountdown(seconds: Int) -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }

            var remainingSeconds = seconds
            while !Task.isCancelled && remainingSeconds > 0 {
                await MainActor.run {
                    self.setStatusMessage(.waitingForSecurityDelay(seconds: remainingSeconds))
                }

                if remainingSeconds == 1 {
                    break
                }

                try? await Task.sleep(for: .seconds(1))
                remainingSeconds -= 1
            }
        }
    }

    private func dumpOrUnseal(
        targetSlot: UInt8,
        activeSlot: UInt8,
        satsCard: SatsCard
    ) async throws -> SlotAccessResult {
        do {
            setStatusMessage(.readingSlotDetails)
            Log.nfc.info(
                "[SendSign] Reading slot details via dump…"
            )
            let detail = try await satsCard.dump(slot: targetSlot, cvc: cvc)

            return .dumped(detail)

        } catch {
            let dumpError = error
            Log.nfc.error(
                "[SendSign] Dump failed with error: \(error.localizedDescription). Attempting unseal fallback if target slot is active."
            )
            do {
                guard targetSlot == activeSlot else {
                    Log.nfc.error(
                        "[SendSign] Not falling back to unseal: targetSlot=\(targetSlot) activeSlot=\(activeSlot)"
                    )
                    throw dumpError
                }

                setStatusMessage(.unsealingActiveSlot)
                Log.nfc.info(
                    "[SendSign] Unsealing active slot…"
                )
                let detail = try await satsCard.unseal(cvc: cvc)

                return .unsealed(detail)

            } catch {
                Log.nfc.error(
                    "[SendSign] Unseal failed with error: \(error.localizedDescription)."
                )
                throw error
            }
        }
    }

    private func friendlyError(for error: Error) -> String {
        if let createError = error as? BitcoinDevKit.CreateTxError {
            switch createError {
            case .CoinSelection(let message):
                return "No spendable funds for this slot (\(message))."
            case .InsufficientFunds(let needed, let available):
                return "Insufficient funds: need \(needed) sats, have \(available) sats."
            default:
                return "Unable to build PSBT: \(createError.localizedDescription)"
            }
        }
        return "Failed to build PSBT: \(error.localizedDescription)"
    }

    private func handleRecoverableFailure(_ error: Error) {
        clearCvcIfNeeded(for: error)
        let message = userFacingMessage(for: error, includeRetryInstruction: true)
        finishAfterSessionInvalidation(
            phase: .raw(message),
            nextState: .ready,
            alertMessage: message
        )
    }

    private func handleTerminalFailure(_ error: Error) {
        clearCvcIfNeeded(for: error)
        let message = userFacingMessage(for: error, includeRetryInstruction: false)
        finishAfterSessionInvalidation(
            phase: .failed(message),
            nextState: .error(message),
            alertMessage: message
        )
    }

    private func clearCvcIfNeeded(for error: Error) {
        guard let cktapError = cktapError(from: error) else { return }
        guard case .Card(.BadAuth) = cktapError else { return }
        cvc = ""
    }

    private func finishAfterSessionInvalidation(
        phase: StatusPhase,
        nextState: State,
        alertMessage: String
    ) {
        pendingInvalidationOutcome = PendingInvalidationOutcome(
            phase: phase,
            state: nextState
        )

        guard let session else {
            pendingInvalidationOutcome = nil
            setStatusMessage(phase)
            state = nextState
            return
        }

        session.invalidate(errorMessage: alertMessage)
    }

    private func userFacingMessage(
        for error: Error,
        includeRetryInstruction: Bool
    ) -> String {
        if let cktapError = cktapError(from: error) {
            return userFacingMessage(
                for: cktapError,
                includeRetryInstruction: includeRetryInstruction
            )
        }

        if let dumpError = error as? DumpError {
            switch dumpError {
            case .SlotSealed:
                return "This slot is still sealed. Enter the correct CVC and try again."
            case .SlotUnused:
                return
                    "This slot has not been used yet. Refresh the card details and choose a funded slot."
            case .SlotTampered:
                return
                    "This slot was already unsealed. Refresh the card details and confirm you are sending from the right slot."
            case .Key(let err):
                return "Couldn't read the slot keys: \(err.localizedDescription)"
            case .CkTap:
                break
            }
        }

        if let signPsbtError = error as? SignPsbtError {
            switch signPsbtError {
            case .SlotNotUnsealed:
                return
                    "This slot needs to be unsealed before it can sign. Enter the correct CVC and try again."
            case .PubkeyMismatch:
                return "Tapped card slot does not match the prepared transaction."
            case .MissingUtxo, .MissingPubkey, .InvalidPath, .InvalidScript, .WitnessProgram:
                return
                    "The transaction could not be signed with this slot. Go back, refresh the card details, and try again."
            case .SighashError(let msg), .SignatureError(let msg), .PsbtEncoding(let msg),
                .Base64Encoding(let msg):
                return "The card could not finish signing: \(msg)"
            case .CkTap:
                break
            }
        }

        if let nfcError = error as? NFCReaderError,
            nfcError.code == .readerSessionInvalidationErrorUserCanceled
        {
            return StatusPhase.nfcCancelled.screenMessage
        }

        return error.localizedDescription
    }

    private func userFacingMessage(
        for error: CkTapError,
        includeRetryInstruction: Bool
    ) -> String {
        switch error {
        case .Card(let cardError):
            switch cardError {
            case .BadAuth:
                return "Incorrect CVC. Check the code printed on the SATSCARD and try again."
            case .NeedsAuth:
                return "Enter the SATSCARD's CVC to continue."
            case .RateLimited:
                let seconds = max(latestAuthDelaySeconds ?? 15, 1)
                let unit = seconds == 1 ? "second" : "seconds"
                if includeRetryInstruction {
                    return
                        "Too many incorrect CVC attempts. Keep the SATSCARD near your iPhone for about \(seconds) \(unit) while it cools off, then try again with the correct CVC."
                }
                return
                    "Too many incorrect CVC attempts. The SATSCARD needs about \(seconds) \(unit) to cool off."
            case .InvalidState:
                return
                    "The SATSCARD is not in the right state for that action. Refresh the card details and try again."
            case .UnluckyNumber:
                return
                    "The card asked to retry the signature. Keep it steady near your iPhone and try again."
            case .BadArguments, .UnknownCommand, .InvalidCommand, .WeakNonce, .BadCbor,
                .BackupFirst:
                return "The SATSCARD rejected that request. Try again."
            }
        case .Transport(let msg):
            if msg.localizedCaseInsensitiveContains("no response from tag")
                || msg.localizedCaseInsensitiveContains("tag response error")
            {
                return
                    "The SATSCARD stopped responding. Keep it steady near the top of your iPhone and try again."
            }
            if msg.localizedCaseInsensitiveContains("timed out") {
                return
                    "The SATSCARD took too long to respond. Keep it steady near the top of your iPhone and try again."
            }
            if msg.localizedCaseInsensitiveContains("invalid apdu") {
                return "The SATSCARD request was invalid. Try again."
            }
            return "Lost connection to the SATSCARD. \(msg)"
        case .CborDe, .CborValue:
            return "The SATSCARD returned data the app couldn't read. Try again."
        case .UnknownCardType:
            return "Only SATSCARD is supported in this signing flow."
        }
    }

    private func cktapError(from error: Error) -> CkTapError? {
        switch error {
        case let error as CkTapError:
            return error
        case let error as DumpError:
            if case .CkTap(let cktapError) = error {
                return cktapError
            }
        case let error as SignPsbtError:
            if case .CkTap(let cktapError) = error {
                return cktapError
            }
        case let error as UnsealError:
            if case .CkTap(let cktapError) = error {
                return cktapError
            }
        default:
            break
        }

        return nil
    }

    nonisolated private static func securityDelayMessage(seconds: Int) -> String {
        "Card security delay active. Keep the SATSCARD near your iPhone for \(seconds) \(seconds == 1 ? "more second" : "more seconds") while it cools off."
    }

    private func setStatusMessage(_ phase: StatusPhase) {
        statusMessage = phase.screenMessage
        if let alertMessage = phase.nfcAlertMessage {
            session?.alertMessage = alertMessage
        }
    }
}
