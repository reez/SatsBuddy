//
//  SendDestinationView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 11/21/25.
//

import BitcoinDevKit
import BitcoinUI
import CodeScanner
import SwiftUI

struct SendDestinationView: View {
    @State private var address: String = ""
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var isShowingScanner = false
    @State private var scannerErrorMessage: String?
    let pasteboard = UIPasteboard.general
    let onNext: (String) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Enter a destination address")
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            TextField("Bitcoin address", text: $address)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.URL)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

            HStack(spacing: 12) {
                Button("Paste") { pasteAddress() }
                    .buttonStyle(.bordered)
                Button("Scan QR") {
                    scannerErrorMessage = nil
                    isShowingScanner = true
                }
                .buttonStyle(.bordered)
                Button("Next") {
                    routeToFee(with: address)
                }
                .buttonStyle(.borderedProminent)
                .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .alert(isPresented: $isShowingAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .fullScreenCover(isPresented: $isShowingScanner) {
            ScannerOverlay(
                onScan: handleScannedString,
                onScanError: handleScannerFailure,
                onPaste: pasteAddressFromScanner,
                onDismiss: {
                    scannerErrorMessage = nil
                    isShowingScanner = false
                },
                errorMessage: scannerErrorMessage
            )
        }
    }

    private func routeToFee(with maybeAddress: String) {
        let trimmed = maybeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            alertMessage = "Please enter an address."
            isShowingAlert = true
            return
        }

        guard let validatedAddress = validatedAddress(from: trimmed) else {
            isShowingAlert = true
            return
        }

        address = validatedAddress
        onNext(validatedAddress)
    }

    private func pasteAddress() {
        guard let pasteboardContent = UIPasteboard.general.string else {
            alertMessage = "Unable to access the pasteboard. Please try copying the address again."
            isShowingAlert = true
            return
        }
        let trimmedContent = pasteboardContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            alertMessage = "The pasteboard is empty."
            isShowingAlert = true
            return
        }
        routeToFee(with: trimmedContent)
    }

    private func pasteAddressFromScanner() {
        scannerErrorMessage = nil
        pasteAddress()
        isShowingScanner = false
    }

    private func handleScannedString(_ raw: String) {
        guard let bitcoinAddress = extractedAddress(from: raw),
            isValidBitcoinMainnetAddress(bitcoinAddress)
        else {
            scannerErrorMessage =
                "That QR code did not contain a valid Bitcoin mainnet address. Try again or paste the address instead."
            return
        }

        scannerErrorMessage = nil
        routeToFee(with: bitcoinAddress)
        isShowingScanner = false
    }

    private func handleScannerFailure(_ message: String) {
        scannerErrorMessage = message
    }

    private func validatedAddress(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        guard let candidate = extractedAddress(from: trimmed), !candidate.isEmpty else {
            alertMessage = "The address is not a valid Bitcoin mainnet address."
            return nil
        }

        guard isValidBitcoinMainnetAddress(candidate) else {
            alertMessage = "The address is not a valid Bitcoin mainnet address."
            return nil
        }

        return candidate
    }

    private func extractedAddress(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "bitcoin:"

        let withoutScheme: String
        if trimmed.count >= prefix.count,
            String(trimmed.prefix(prefix.count)).caseInsensitiveCompare(prefix) == .orderedSame
        {
            withoutScheme = String(trimmed.dropFirst(prefix.count))
        } else {
            withoutScheme = trimmed
        }

        let addressOnly = withoutScheme.components(separatedBy: "?").first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let addressOnly, !addressOnly.isEmpty else {
            return nil
        }

        return addressOnly
    }

    private func isValidBitcoinMainnetAddress(_ value: String) -> Bool {
        (try? Address(address: value, network: .bitcoin)) != nil
    }
}

private struct ScannerOverlay: View {
    let onScan: (String) -> Void
    let onScanError: (String) -> Void
    let onPaste: () -> Void
    let onDismiss: () -> Void
    let errorMessage: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            CodeScannerView(
                codeTypes: [.qr],
                shouldVibrateOnSuccess: true
            ) { result in
                switch result {
                case .success(let scan):
                    onScan(scan.string)
                case .failure:
                    onScanError(
                        "Unable to read the QR code. Try again or paste the address instead."
                    )
                }
            }
            .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .font(.system(size: 20, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.top, 50)
                    .padding(.leading, 20)

                    Spacer()
                }

                Spacer()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.75))
                        .clipShape(.rect(cornerRadius: 16))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }

                Button(action: onPaste) {
                    Text("Paste Address")
                        .padding()
                        .foregroundStyle(Color(uiColor: .label))
                        .background(Color(uiColor: .systemBackground).opacity(0.5))
                        .clipShape(Capsule())
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
    }
}

#Preview {
    SendDestinationView { _ in }
}
