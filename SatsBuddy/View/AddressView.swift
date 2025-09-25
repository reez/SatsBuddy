//
//  AddressView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/25/25.
//

import SwiftUI
import UIKit

struct AddressView: View {
    let address: String
    let activeSlot: UInt8
    let totalSlots: UInt8
    let pubkey: String

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Slot \(activeSlot)/\(totalSlots)")
            
            Text("\(pubkey)")
                .truncationMode(.middle)
                .lineLimit(1)

            Button {
                UIPasteboard.general.string = address
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copied = false
                }
            } label: {
                HStack {
                    Text(address)
                        .truncationMode(.middle)
                        .lineLimit(1)

                    if copied {
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                            .symbolEffect(.bounce, value: copied)
                    }
                }
            }
            .sensoryFeedback(.success, trigger: copied)

            Button {
                if let url = URL(string: "https://mempool.space/address/\(address)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Verify on mempool.space")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .font(.callout)

    }
}

#if DEBUG
    #Preview {
        AddressView(
            address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            activeSlot: 1,
            totalSlots: 10,
            pubkey: "pubkey"
        )
        .padding()
    }
#endif
