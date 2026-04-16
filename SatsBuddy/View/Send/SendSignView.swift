//
//  SendSignView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 11/21/25.
//

import BitcoinUI
import SwiftUI

struct SendSignView: View {
    @State var viewModel: SendSignViewModel
    let onDone: @MainActor (SendCompletionResult) async -> Void
    @FocusState private var cvcFocused: Bool
    @State private var didFinishFlow = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Sign and broadcast")
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Expected card ID")
                    //                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(viewModel.expectedCardIdentifier)
                    .font(.caption.monospaced())
                    //                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Destination")
                        .foregroundStyle(.secondary)
                    Text(viewModel.address)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Fee rate")
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.feeRate) sat/vB")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                Text("CVC")
                    .font(.headline)
                TextField("Enter card CVC", text: $viewModel.cvc)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .autocorrectionDisabled()
                    .focused($cvcFocused)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let psbtError = viewModel.psbtError {
                    Text(psbtError)
                        .font(.callout)
                        .foregroundColor(.red)
                } else {
                    Text(viewModel.statusMessage)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                if let txid = viewModel.signedTxid {
                    Text("TXID: \(txid)")
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                }

                if let txHex = viewModel.txHex {
                    Text("Raw tx hex (truncated):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(txHex)
                        .font(.caption2.monospaced())
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            if viewModel.isBroadCasted {
                Button {
                    Task { @MainActor in
                        await onDone(viewModel.completionResult)
                    }
                } label: {
                    Text("Done")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(
                    BitcoinOutlined(
                        tintColor: .primary,
                        isCapsule: true
                    )
                )
            } else {
                Button {
                    cvcFocused = false
                    viewModel.startNfc()
                } label: {
                    HStack {
                        if viewModel.isBusy {
                            ProgressView()
                        }
                        Text("Send")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                }
                .buttonStyle(
                    BitcoinFilled(
                        tintColor: .primary,
                        textColor: Color(uiColor: .systemBackground),
                        isCapsule: true
                    )
                )
                .disabled(viewModel.isBusy || !viewModel.canStartNfc)
            }
        }
        .padding()
        .navigationTitle("Sign")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.runPreflightIfNeeded()
        }
        .onChange(of: viewModel.isBroadCasted) { _, isBroadCasted in
            guard isBroadCasted, !didFinishFlow else { return }
            didFinishFlow = true
            cvcFocused = false

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                await onDone(viewModel.completionResult)
            }
        }
    }
}

#Preview {
    SendSignView(
        viewModel: SendSignViewModel(
            address: "bc1qexample",
            feeRate: 10,
            slot: SlotInfo(
                slotNumber: 0,
                isActive: true,
                isUsed: true,
                pubkey: "02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f",
                pubkeyDescriptor: nil,
                address: "bc1qexample",
                balance: 10_000
            ),
            expectedCardIdentifier: "DEMO-CARD-12345-67890",
            network: .bitcoin
        ),
        onDone: { _ in }
    )
}

#Preview("Accessibility 3") {
    SendSignView(
        viewModel: SendSignViewModel(
            address: "bc1pxg0lakl0x4jee73f38m334qsma7mn2yv764x9an5ylht6tx8ccdsxtktrt",
            feeRate: 10,
            slot: SlotInfo(
                slotNumber: 0,
                isActive: true,
                isUsed: true,
                pubkey: "02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f",
                pubkeyDescriptor: nil,
                address: "bc1pxg0lakl0x4jee73f38m334qsma7mn2yv764x9an5ylht6tx8ccdsxtktrt",
                balance: 10_000
            ),
            expectedCardIdentifier: "DEMO-CARD-12345-67890-LONG",
            network: .bitcoin
        ),
        onDone: { _ in }
    )
    .dynamicTypeSize(.accessibility3)
}
