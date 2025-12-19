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
    let isDetailLoading: Bool

    @State private var showingDetail = false

    var body: some View {
        HStack(spacing: 16) {

            Image("satscard.logo")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                if let customLabel = card.label?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !customLabel.isEmpty
                {
                    Text(customLabel)
                        .font(.body)
                        .fontWeight(.semibold)
                        .truncationMode(.middle)
                        .lineLimit(1)
                } else if !card.pubkey.isEmpty {
                    Text(card.pubkey)
                        .font(.body)
                        .fontWeight(.semibold)
                        .fontDesign(.monospaced)
                        .truncationMode(.middle)
                        .lineLimit(1)
                } else {
                    Text("SATSCARD")
                        .font(.body)
                        .fontWeight(.medium)
                }

                if let activeSlot = card.activeSlot, let totalSlots = card.totalSlots {
                    Text("Slot \(activeSlot)/\(totalSlots)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let cardIdent = card.cardIdent, !cardIdent.isEmpty {
                    Text(cardIdent)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if isDetailLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

#if DEBUG
    #Preview {
        let sampleCard = SatsCardInfo(
            version: "1.0.3",
            birth: 1,
            address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            pubkey: "02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9388",
            cardIdent: "ABCDE-FGHJK-LMNOP-QRSTU",
            activeSlot: 2,
            totalSlots: 10,
            isActive: true
        )

        SatsCardView(
            card: sampleCard,
            onRemove: {
            },
            cardViewModel: SatsCardViewModel(
                ckTapService: .mock,
                cardsStore: .mock,
                priceClient: .mock
            ),
            isDetailLoading: false
        )
        .padding()
    }
#endif
