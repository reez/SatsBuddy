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

    let address: String
    let feeRate: Int
    let slot: SlotInfo
    let expectedCardIdentifier: String
    let network: Network
    private let bdkClient: BdkClient

    var cvc: String = ""
    var statusMessage: String = "Enter CVC and tap your card to sign and broadcast."
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
        self.statusMessage = "Preparing sweep transaction…"
    }

    // MARK: - NFC

    func runPreflightIfNeeded() async {
        guard !didRunPreflight else { return }
        didRunPreflight = true

        state = .preparingPsbt
        psbt = nil
        psbtBase64 = nil
        psbtError = nil
        statusMessage = "Preparing sweep transaction…"

        guard let slotPubkey = slot.pubkey, !slotPubkey.isEmpty else {
            let message =
                "Unable to prepare the transaction for this slot. Refresh the card and try again."
            psbtError = message
            statusMessage = message
            state = .error(message)
            return
        }

        do {
            let preparedPsbt = try await bdkClient.buildPsbt(
                slotPubkey,
                address,
                UInt64(feeRate),
                network
            )
            psbt = preparedPsbt
            psbtBase64 = preparedPsbt.serialize()
            state = .ready
            statusMessage = "Transaction ready. Enter CVC and tap your card to sign and broadcast."
        } catch {
            let message = friendlyError(for: error)
            psbt = nil
            psbtBase64 = nil
            psbtError = message
            state = .error(message)
            statusMessage = message
        }
    }

    func startNfc() {
        guard case .ready = state else {
            if case .preparingPsbt = state {
                statusMessage = "Still preparing transaction…"
            }
            return
        }

        guard hasPreparedPsbt else {
            let message = psbtError ?? "Transaction not ready. Go back and try again."
            psbtError = message
            statusMessage = message
            return
        }

        guard !cvc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "Enter CVC to continue."
            return
        }

        guard NFCTagReaderSession.readingAvailable else {
            statusMessage = "NFC not available on this device."
            return
        }

        session?.invalidate()
        session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        session?.alertMessage = "Hold your iPhone near the SatsCard to sign and broadcast."
        session?.begin()

        state = .tapping
        statusMessage = "Hold near card to sign and broadcast…"
        Log.nfc.info("[SendSign] NFC session started for signing")
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        Log.nfc.info("[SendSign] NFC session active")
    }

    func tagReaderSession(
        _ session: NFCTagReaderSession,
        didInvalidateWithError error: any Error
    ) {
        // If we already succeeded, ignore spurious invalidations.
        switch state {
        case .done, .unsealed:
            return
        default:
            break
        }

        if case let nfcError as NFCReaderError = error,
            nfcError.code == .readerSessionInvalidationErrorUserCanceled
        {
            statusMessage = "NFC cancelled."
            state = .ready
            return
        }

        statusMessage = "NFC error: \(error.localizedDescription)"
        state = .error(error.localizedDescription)
        Log.nfc.error(
            "[SendSign] session invalidated: \(error.localizedDescription, privacy: .public)"
        )
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let first = tags.first else {
            session.invalidate(errorMessage: "No tag found.")
            statusMessage = "No tag found."
            state = .error("No tag found.")
            return
        }

        session.connect(to: first) { [weak self] error in
            guard let self else { return }
            if let error = error {
                Log.nfc.error(
                    "[SendSign] connect failed: \(error.localizedDescription, privacy: .public)"
                )
                session.invalidate(errorMessage: "Connection failed.")
                Task { @MainActor in
                    self.statusMessage = "Connection failed."
                    self.state = .error(error.localizedDescription)
                }
                return
            }

            guard case .iso7816(let iso7816Tag) = first else {
                session.invalidate(errorMessage: "Unsupported tag.")
                Task { @MainActor in
                    self.statusMessage = "Unsupported tag."
                    self.state = .error("Unsupported tag.")
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
            statusMessage = "Reading card status…"

            let liveStatus = await satsCard.status()
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
            Log.nfc.info(
                "[SendSign] Live status: activeSlot=\(liveStatus.activeSlot) targetSlot=\(targetSlot)"
            )

            guard
                let slotAccess = await dumpOrUnseal(
                    targetSlot: targetSlot,
                    activeSlot: liveStatus.activeSlot,
                    satsCard: satsCard
                )
            else {
                throw NSError(
                    domain: "SendSign",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to access slot details."]
                )
            }

            let detail = slotAccess.detail
            switch slotAccess {
            case .dumped:
                Log.nfc.info(
                    "[SendSign] Slot \(targetSlot) details retrieved via dump, building and signing tx…"
                )
                session?.alertMessage = "Card read. Building transaction…"
            case .unsealed:
                Log.nfc.info(
                    "[SendSign] Active slot \(targetSlot) unsealed, building and signing tx…"
                )
                session?.alertMessage = "Slot unsealed. Building transaction…"
            }

            statusMessage = "Building and signing transaction…"
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

            statusMessage = "Broadcasting transaction…"
            try bdkClient.broadcast(signedTx, network)

            cvc = ""
            state = .done
            statusMessage = "Transaction broadcast! TXID: \(signedTxid ?? "unknown")"
            session?.alertMessage = "Transaction broadcasted"
            session?.invalidate()
            Log.ui.info(
                "[SendSign] Broadcast success txid=\(self.signedTxid ?? "nil", privacy: .private(mask: .hash))"
            )

            isBroadCasted = true

        } catch {
            Log.nfc.error(
                "[SendSign] handleTag error: \(error.localizedDescription, privacy: .public)"
            )
            state = .error(error.localizedDescription)
            statusMessage = "Failed: \(error.localizedDescription)"
            session?.invalidate(errorMessage: "Error: \(error.localizedDescription)")
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

        if let slotPubkey = slot.pubkey, slotPubkey != detail.pubkey {
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

    private func dumpOrUnseal(
        targetSlot: UInt8,
        activeSlot: UInt8,
        satsCard: SatsCard
    ) async -> SlotAccessResult? {
        do {
            statusMessage = "Reading slot details…"
            Log.nfc.info(
                "[SendSign] Reading slot details via dump…"
            )
            let detail = try await satsCard.dump(slot: targetSlot, cvc: cvc)

            return .dumped(detail)

        } catch {
            Log.nfc.error(
                "[SendSign] Dump failed with error: \(error.localizedDescription). Attempting unseal fallback if target slot is active."
            )
            do {
                guard targetSlot == activeSlot else {
                    Log.nfc.error(
                        "[SendSign] Not falling back to unseal: targetSlot=\(targetSlot) activeSlot=\(activeSlot)"
                    )
                    return nil
                }

                statusMessage = "Unsealing active slot…"
                Log.nfc.info(
                    "[SendSign] Unsealing active slot…"
                )
                let detail = try await satsCard.unseal(cvc: cvc)

                return .unsealed(detail)

            } catch {
                Log.nfc.error(
                    "[SendSign] Unseal failed with error: \(error.localizedDescription)."
                )

            }

            return nil
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
}
