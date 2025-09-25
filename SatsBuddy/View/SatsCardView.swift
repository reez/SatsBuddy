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
            Image(systemName: "square.grid.3x3.square")
                .symbolRenderingMode(.hierarchical)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.displayName)
                    .font(.body)
                    .fontWeight(.semibold)
                    .truncationMode(.middle)
                    .lineLimit(1)

                if let pubkey = card.pubkey,
                   card.displayName != pubkey
                {
                    Text(pubkey)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .truncationMode(.middle)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }

                if let activeSlot = card.activeSlot, let totalSlots = card.totalSlots {
                    Text("Slot \(activeSlot)/\(totalSlots)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    let sampleCard = SatsCardInfo(
        version: "1.0.3",
        birth: 1,
        address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
        pubkey: "02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9388",
        activeSlot: 2,
        totalSlots: 10,
        isActive: true
    )

    SatsCardView(
        card: sampleCard,
        onRemove: {
            print("Remove card")
        },
        cardViewModel: SatsCardViewModel(ckTapService: .mock, cardsStore: .mock)
    )
    .padding()
}
