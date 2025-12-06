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
final class SendSignViewModel: NSObject, NFCTagReaderSessionDelegate {
    enum State {
        case idle
        case preparingPsbt
        case ready
        case tapping
        case unsealed
        case done
        case error(String)
    }

    let address: String
    let feeRate: Int
    let slot: SlotInfo
    let network: Network
    private let bdkClient: BdkClient

    var cvc: String = ""
    var statusMessage: String = "Enter CVC and tap your card to unseal."
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
        switch state {
        case .ready, .unsealed, .done:
            return true
        default:
            return false
        }
    }

    private var session: NFCTagReaderSession?
    private var psbt: Psbt?

    init(
        address: String,
        feeRate: Int,
        slot: SlotInfo,
        network: Network,
        bdkClient: BdkClient = .live
    ) {
        self.address = address
        self.feeRate = feeRate
        self.slot = slot
        self.network = network
        self.bdkClient = bdkClient
        self.state = .ready
    }

    // MARK: - PSBT prep

    func preparePsbtIfNeeded() async {
        guard psbt == nil else { return }
        // Only pre-build if we already have a descriptor (rare); otherwise wait for unseal.
        guard let descriptor = slot.pubkeyDescriptor else {
            state = .ready
            statusMessage = "Tap Start NFC to unseal and build PSBT."
            return
        }

        state = .preparingPsbt
        statusMessage = "Building sweep PSBT…"
        do {
            // Prefer descriptor when present; otherwise use raw pubkey.
            let built = try await bdkClient.buildPsbt(
                nil,
                descriptor,
                address,
                UInt64(feeRate),
                network
            )
            psbt = built
            psbtBase64 = built.serialize()
            psbtError = nil
            state = .ready
            statusMessage = "PSBT ready. Tap Start NFC to unseal."
            Log.ui.info("[SendSign] PSBT prepared (feeRate=\(self.feeRate))")
        } catch {
            let friendly = friendlyError(for: error)
            psbtError = friendly
            state = .error(friendly)
            statusMessage = friendly
            Log.ui.error("Failed to build PSBT: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - NFC

    func startNfc() {
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
        session?.alertMessage = "Hold your iPhone near the SatsCard."
        session?.begin()

        state = .tapping
        statusMessage = "Hold near card to unseal…"
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
        if case .unsealed = state { return }

        if case let nfcError as NFCReaderError = error,
            nfcError.code == .readerSessionInvalidationErrorUserCanceled
        {
            statusMessage = "NFC cancelled."
            state = .idle
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
                    userInfo: [NSLocalizedDescriptionKey: "Only SATSCARD supported for sweep"]
                )
            }

            // If the slot is already used/unsealed, dump with CVC; otherwise unseal.
            let targetSlot = slot.slotNumber
            let pubkey: String?
            let descriptor: String?
            if slot.isUsed {
                let dump = try await satsCard.dump(slot: targetSlot, cvc: cvc)
                pubkey = dump.pubkey
                descriptor = dump.pubkeyDescriptor
                Log.nfc.info(
                    "[SendSign] Dumped slot \(targetSlot) pubkey=\(pubkey ?? "nil", privacy: .private(mask: .hash)) desc=\(descriptor ?? "nil", privacy: .private(mask: .hash))"
                )
            } else {
                let details = try await satsCard.unseal(cvc: cvc)
                pubkey = details.pubkey
                descriptor = details.pubkeyDescriptor
                Log.nfc.info(
                    "[SendSign] Unsealed slot pubkey=\(pubkey ?? "nil", privacy: .private(mask: .hash)) desc=\(descriptor ?? "nil", privacy: .private(mask: .hash))"
                )
            }

            guard pubkey != nil || descriptor != nil else {
                throw NSError(
                    domain: "SendSign",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Missing slot key/descriptor after NFC"]
                )
            }

            // Build PSBT using slot keys.
            state = .preparingPsbt
            statusMessage = "Building sweep PSBT…"
            let built = try await bdkClient.buildPsbt(
                pubkey,
                descriptor,
                address,
                UInt64(feeRate),
                network
            )
            psbt = built
            psbtBase64 = built.serialize()
            let tx = try built.extractTx()
            signedTxid = tx.computeTxid().description
            txHex = tx.serialize().map { String(format: "%02x", $0) }.joined()
            if let txid = signedTxid, let psbtBase64, let txHex {
                Log.ui.info(
                    "[SendSign] Would broadcast txid=\(txid, privacy: .private(mask: .hash)) psbt=\(psbtBase64, privacy: .private(mask: .hash)) rawTxHex=\(txHex, privacy: .private(mask: .hash))"
                )
                Log.ui.info(
                    "[SendSign] Broadcast stub: POST https://mempool.space/api/tx body=\(txHex, privacy: .private(mask: .hash))"
                )
            }
            state = .unsealed
            statusMessage = "Slot ready. PSBT built (no broadcast)."
            session?.invalidate()
        } catch {
            state = .error(error.localizedDescription)
            statusMessage = "Unseal/sign failed: \(error.localizedDescription)"
            session?.invalidate(errorMessage: "Error: \(error.localizedDescription)")
            Log.nfc.error(
                "[SendSign] handleTag error: \(error.localizedDescription, privacy: .public)"
            )
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
