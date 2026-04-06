//
//  ReceiveView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/26/25.
//

import BitcoinUI
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct ReceiveView: View {
    let address: String
    @Binding var isCopied: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: UIImage?
    @State private var isGeneratingQR = false
    @State private var isQRLoading = true
    @State private var copyResetTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    VStack {
                        ZStack {
                            BitcoinUI.QRCodeView(qrCodeType: .bitcoin(address), cornerRadius: 20)
                                .opacity(isQRLoading ? 0 : 1)
                                .onAppear {
                                    DispatchQueue.main.async {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isQRLoading = false
                                        }
                                    }
                                }

                            if isQRLoading {
                                Rectangle()
                                    .fill(Color(.secondarySystemGroupedBackground))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        ProgressView()
                                    }
                                    .transition(.opacity)
                            }
                        }
                        .padding()

                        Divider()
                            .padding(.horizontal)

                        BitcoinUI.AddressFormattedView(address: address, columns: 4)
                            .padding(.top)
                    }

                    Divider()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Address")
                            .foregroundStyle(.secondary)

                        Button {
                            copyAddress()
                        } label: {
                            HStack {
                                Text(address)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 80)
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                    .foregroundColor(isCopied ? .green : .blue)
                                    .font(.caption)
                                    .symbolEffect(.bounce, value: isCopied)
                            }
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.success, trigger: isCopied) { _, newValue in newValue }

                    }
                    .padding(.horizontal)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        copyAddress()
                    } label: {
                        Label(
                            isCopied ? "Copied" : "Copy address",
                            systemImage: isCopied ? "checkmark" : "doc.on.doc"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .background(Color(uiColor: .label), in: .capsule)
                    .padding(.top, 8)

                }
                .padding()
            }
            .onDisappear {
                copyResetTask?.cancel()
            }
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }

    }

    private func copyAddress() {
        UIPasteboard.general.string = address
        isCopied = true

        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))

            guard !Task.isCancelled else { return }
            isCopied = false
        }
    }
}

#Preview {
    ReceiveView(
        address: "bc1pxg0lakl0x4jee73f38m334qsma7mn2yv764x9an5ylht6tx8ccdsxtktrt",
        isCopied: .constant(false)
    )
}

#Preview("Accessibility 3") {
    ReceiveView(
        address: "bc1pxg0lakl0x4jee73f38m334qsma7mn2yv764x9an5ylht6tx8ccdsxtktrt",
        isCopied: .constant(false)
    )
    .dynamicTypeSize(.accessibility3)
}
