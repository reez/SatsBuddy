//
//  SatsCardView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/2/25.
//

import SwiftUI

struct SatsCardView: View {
    let card: SatsCardInfo
    let onRemove: () -> Void
    let cardViewModel: SatsCardViewModel

    @State private var showingDetail = false

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "creditcard.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.headline)

                    Text("SATSCARD")
                        .font(.headline)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Version \(card.version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let activeSlot = card.activeSlot, let totalSlots = card.totalSlots {
                        Text("• Slot \(activeSlot)/\(totalSlots)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let address = card.address {
                    Text(address)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.tertiary)
                        .truncationMode(.middle)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            SatsCardDetailView(card: card, viewModel: .init(), cardViewModel: cardViewModel)
        }
    }
}

#Preview {
    let sampleCard = SatsCardInfo(
        version: "1.0.3",
        address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
        isActive: true
    )

    SatsCardView(
        card: sampleCard,
        onRemove: {
            print("Remove card")
        },
        cardViewModel: SatsCardViewModel(ckTapService: .mock)
    )
    .padding()
}
