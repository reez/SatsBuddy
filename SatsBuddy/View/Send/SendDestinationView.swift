//
//  SendDestinationView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 11/21/25.
//

import BitcoinUI
import CodeScanner
import SwiftUI

struct SendDestinationView: View {
    @State private var address: String = ""
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var isShowingScanner = false
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
                Button("Scan QR") { isShowingScanner = true }
                    .buttonStyle(.borderedProminent)
                Button("Next") {
                    routeToFee(with: address)
                }
                .buttonStyle(.bordered)
                .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .onAppear {
            // Pop up scanner by default; user can dismiss and paste instead.
            isShowingScanner = true
        }
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
                onPaste: pasteAddressFromScanner,
                onDismiss: { isShowingScanner = false }
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
        address = trimmed
        onNext(trimmed.lowercased())
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
        routeToFee(with: trimmedContent.lowercased())
    }

    private func pasteAddressFromScanner() {
        pasteAddress()
        isShowingScanner = false
    }

    private func handleScannedString(_ raw: String) {
        let cleaned = raw.lowercased().replacingOccurrences(of: "bitcoin:", with: "")
        let components = cleaned.components(separatedBy: "?")
        if let bitcoinAddress = components.first, !bitcoinAddress.isEmpty {
            routeToFee(with: bitcoinAddress)
            isShowingScanner = false
        } else {
            alertMessage = "The scanned QR code did not contain a valid Bitcoin address."
            isShowingAlert = true
            isShowingScanner = false
        }
    }
}

private struct ScannerOverlay: View {
    let onScan: (String) -> Void
    let onPaste: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            CodeScannerView(
                codeTypes: [.qr],
                shouldVibrateOnSuccess: true
            ) { result in
                switch result {
                case .success(let scan):
                    onScan(scan.string)
                case .failure(let error):
                    onDismiss()
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
