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
    var isBroadCasted = false
    
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
            
            let targetSlot = slot.slotNumber
            
            state = .preparingPsbt
            statusMessage = "Reading card status…"
            
            let liveStatus = await satsCard.status()
            Log.nfc.info(
                "[SendSign] Live status: activeSlot=\(liveStatus.activeSlot) targetSlot=\(targetSlot)"
            )
            
            guard let detail = await dumpOrUnseal(targetSlot: targetSlot, satsCard: satsCard) else {
                throw NSError(
                    domain: "SendSign",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Unseal or dump failed"]
                )
            }
            
            Log.nfc.info("[SendSign] Slot \(targetSlot) dumped/unsealed successfully, building and signing tx…")
            session?.alertMessage = "Slot unsealed! Building transaction…"
            
            statusMessage = "Building and signing transaction…"
            let signedTx = try await buildPsbtAndSign(
                detail: detail,
                targetSlot: targetSlot,
                satsCard: satsCard
            ).extractTx()
            
            signedTxid = signedTx.computeTxid().description
            txHex = signedTx.serialize().map { String(format: "%02x", $0) }.joined()
            Log.nfc.info(
                "[SendSign] Signed txid=\(self.signedTxid ?? "nil", privacy: .private(mask: .hash))"
            )
            
            statusMessage = "Broadcasting transaction…"
            try bdkClient.broadcast(signedTx)
            
            state = .done
            statusMessage = "Transaction broadcast! TXID: \(signedTxid ?? "unknown")"
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
        satsCard: SatsCard
    ) async throws -> Psbt {
        
        let psbtSigned: Psbt?
        
        let psbt = try await bdkClient.buildPsbt(
            detail.pubkey,
            address,
            UInt64(feeRate),
            network
        )
        
        let psbtSignedBase64 = try await satsCard.signPsbt(
            slot: targetSlot,
            psbt: psbt.serialize(),
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
    
    private func dumpOrUnseal(targetSlot: UInt8, satsCard: SatsCard) async -> SlotDetails? {
        do {
            statusMessage = "Dumping slot…"
            Log.nfc.info(
                "[SendSign] Dumping slot…"
            )
            let detail = try await satsCard.dump(slot: targetSlot, cvc: cvc)
            
            return detail
            
        } catch {
            Log.nfc.error(
                "[SendSign] Dump failed with error: \(error.localizedDescription). Falling back to dump."
            )
            do {
                statusMessage = "Unsealing slot…"
                Log.nfc.info(
                    "[SendSign] Unsealing slot…"
                )
                let detail = try await satsCard.unseal(cvc: cvc)
                
                return detail
                
            } catch {
                Log.nfc.error(
                    "[SendSign] Unseal failed with error: \(error.localizedDescription). Falling back to dump."
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
