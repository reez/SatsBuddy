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
    let onDone: () -> Void
    @FocusState private var cvcFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Text("Prepare to sign")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Destination: \(viewModel.address)")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Fee rate: \(viewModel.feeRate) sat/vB")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                Text("CVC")
                    .font(.headline)
                SecureField("Enter card CVC", text: $viewModel.cvc)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
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

                if let psbt = viewModel.psbtBase64 {
                    Text("PSBT (base64, truncated):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(psbt)
                        .font(.caption2.monospaced())
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                if let txid = viewModel.signedTxid {
                    Text("Txid: \(txid)")
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
                    onDone()
                } label: {
                    Text("Done, broadcasted")
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
                        Text("Start NFC")
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
            network: .bitcoin
        ),
        onDone: {}
    )
}
