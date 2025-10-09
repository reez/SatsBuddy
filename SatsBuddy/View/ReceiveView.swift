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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    VStack {
                        ZStack {
                            BitcoinUI.QRCodeView(qrCodeType: .bitcoin(address))
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
                            .padding(.vertical)
                            .padding(.bottom)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Address")
                            .foregroundStyle(.secondary)

                        Button {
                            UIPasteboard.general.string = address
                            isCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                isCopied = false
                            }
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
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                }
                .padding()
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
}

#Preview {
    ReceiveView(address: "", isCopied: .constant(false))
}
