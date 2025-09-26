//
//  ReceiveView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/26/25.
//

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    Group {
                        if let image = qrImage {
                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .padding()
                            //                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        } else {
                            Rectangle()  //RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .frame(width: 200, height: 200)
                                .overlay { ProgressView() }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Address")
                            .foregroundStyle(.secondary)

                        Button {
                            UIPasteboard.general.string = address
                            isCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                isCopied = false
                            }
                        } label: {
                            HStack {
                                Text(address)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                    .foregroundColor(isCopied ? .green : .secondary)
                                    .font(.caption)
                                    .symbolEffect(.bounce, value: isCopied)
                            }
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.success, trigger: isCopied)

                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
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
        .task {
            guard !isGeneratingQR else { return }
            isGeneratingQR = true
            let image = await Task.detached(priority: .utility) {
                QRGenerator.generate(from: address)
            }.value
            await MainActor.run {
                qrImage = image
                isGeneratingQR = false
            }
        }
    }
}

#Preview {
    ReceiveView(address: "", isCopied: .constant(false))
}

private struct QRGenerator {
    static let context = CIContext()
    static func generate(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")

        guard let outputImage = filter.outputImage,
            let cgImage = context.createCGImage(outputImage, from: outputImage.extent)
        else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
