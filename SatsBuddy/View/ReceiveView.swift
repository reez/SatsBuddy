//
//  ReceiveView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/26/25.
//

import SwiftUI
import BitcoinUI

struct ReceiveView: View {
    let address: String
    @Binding var isCopied: Bool //  should be isCopied

    var body: some View {
        VStack {
            
            // QR
            QRCodeView(qrCodeType: .bitcoin(address))

            // Address
            VStack(alignment: .leading, spacing: 4) {
                Text("Address")
                    .foregroundStyle(.secondary)
                Button {
                    UIPasteboard.general.string = address
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isCopied = false
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(address)
                                .truncationMode(.middle)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(
                                systemName: isCopied
                                ? "checkmark" : "document.on.document"
                            )
                            .font(.caption)
                            .foregroundColor(isCopied ? .green : .secondary)
                            .symbolEffect(.bounce, value: isCopied)
                        }
                    }
                }
                .sensoryFeedback(.success, trigger: isCopied)
            }
            

            
        }
    }
}

#Preview {
    ReceiveView(address: "", isCopied: .constant(false))
}
