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

    @State private var addressCopied = false
    @State private var showCheckmark = false
    @State private var showingDetail = false

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Image(systemName: "creditcard.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title2)
                    .foregroundColor(.orange)

                Text("SATSCARD")
                    .fontWeight(.semibold)
                    .font(.caption)
                    .foregroundColor(.primary)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Version: \(card.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)

                    if let activeSlot = card.activeSlot, let totalSlots = card.totalSlots {
                        Spacer()
                        Text("Slot \(activeSlot)/\(totalSlots)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontDesign(.monospaced)
                    }
                }

                if let address = card.address {
                    HStack {
                        HStack(spacing: 4) {
                            Text("Address:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(address)
                                .font(.caption2)
                                .fontDesign(.monospaced)
                                .truncationMode(.middle)
                                .lineLimit(1)
                        }

                        Button {
                            UIPasteboard.general.string = address
                            addressCopied = true
                            showCheckmark = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                addressCopied = false
                                showCheckmark = false
                            }
                        } label: {
                            Image(systemName: showCheckmark ? "doc.on.doc.fill" : "doc.on.doc")
                                .font(.caption2)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let pubkey = card.pubkey {
                    HStack {
                        HStack(spacing: 4) {
                            Text("Pubkey:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(pubkey)
                                .font(.caption2)
                                .fontDesign(.monospaced)
                                .truncationMode(.middle)
                                .lineLimit(1)
                        }

                        Button {
                            UIPasteboard.general.string = pubkey
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Text(
                        "Scanned: \(card.dateScanned.formatted(date: .abbreviated, time: .shortened))"
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                    Spacer()

                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .stroke(.quaternary, lineWidth: 1)
        )
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            SatsCardDetailView(card: card, cardViewModel: cardViewModel)
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
