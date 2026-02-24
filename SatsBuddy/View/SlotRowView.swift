//
//  SlotRowView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/8/25.
//

import SwiftUI

struct SlotSummaryRowView: View {
    let slot: SlotInfo

    var body: some View {
        SlotSummaryHeader(slot: slot, showsChevron: true)
    }
}

struct SlotRowView<Footer: View>: View {
    let slot: SlotInfo
    //    @State private var addressCopied = false
    private let footer: Footer
    @AppStorage("balanceDisplayFormat") private var balanceFormat: BalanceDisplayFormat = .bip177
    @State private var isAddressCopied: Bool = false
    let price: Price?

    init(slot: SlotInfo, price: Price?, @ViewBuilder footer: () -> Footer) {
        self.slot = slot
        self.price = price
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            if slot.isActive || slot.balance != nil, let balance = slot.balance {
                balanceRow(balance: balance)
            }

            if slot.isUsed, let address = slot.address, !address.isEmpty {

                Button {
                    UIPasteboard.general.string = address
                    isAddressCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isAddressCopied = false
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Address")
                            .foregroundStyle(.secondary)
                        HStack(alignment: .center) {
                            Text(address)
                                .font(.body)
                                .fontDesign(.monospaced)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.primary)

                            Spacer(minLength: 80)

                            Image(systemName: isAddressCopied ? "checkmark" : "doc.on.doc")
                                .font(.footnote)
                                .fontWeight(.bold)
                                .foregroundStyle(isAddressCopied ? .green : .blue)
                                .symbolEffect(.bounce, value: isAddressCopied)
                        }
                    }
                }
                .padding(.vertical, 8)
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: isAddressCopied) { _, newValue in
                    newValue
                }
            }

            if slot.isActive {
                SlotBadge(text: "Active", tint: .green)
                    .padding(.top, 10)
            }

            footer
        }
    }
}

extension SlotRowView {
    @ViewBuilder
    fileprivate func balanceRow(balance: UInt64) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            let prefix = balanceFormat.displayPrefix(price: price)
            if !prefix.isEmpty {
                Text(prefix)
                    .foregroundStyle(.secondary)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Text(balanceFormat.formatted(balance, price: price))
                .foregroundStyle(.primary)
                .font(.title)
                .fontWeight(.semibold)

            let displayText = balanceFormat.displayText(price: price)
            if !displayText.isEmpty {
                Text(displayText)
                    .foregroundStyle(.secondary)
                    .font(.title2)
                    .fontWeight(.light)
            }
        }
    }
}

#Preview {
    let price = Price(
        time: 1_734_000_000,
        usd: 89_000,
        eur: 82_000,
        gbp: 70_000,
        cad: 120_000,
        chf: 80_000,
        aud: 130_000,
        jpy: 13_700_000
    )
    SlotRowView(
        slot: .init(
            slotNumber: UInt8(1),
            isActive: true,
            isUsed: true,
            pubkey: "03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c",
            pubkeyDescriptor: nil,
            address: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            balance: 21_000
        ),
        price: price
    )
    .padding()
}

extension SlotRowView where Footer == EmptyView {
    init(slot: SlotInfo, price: Price?) {
        self.init(slot: slot, price: price) { EmptyView() }
    }
}

private struct SlotCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
    }
}

private struct SlotSummaryHeader: View {
    let slot: SlotInfo
    let showsChevron: Bool
    let showsSlotTitle: Bool

    init(slot: SlotInfo, showsChevron: Bool, showsSlotTitle: Bool = true) {
        self.slot = slot
        self.showsChevron = showsChevron
        self.showsSlotTitle = showsSlotTitle
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if showsSlotTitle {
                Text("Slot \(slot.slotNumber)")
                    .font(.body)
                    .fontWeight(.medium)
            }

            SlotStatusBadges(slot: slot)

            Spacer()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct SlotStatusBadges: View {
    let slot: SlotInfo

    var body: some View {
        HStack(spacing: 8) {
            if slot.isActive {
                SlotBadge(text: "Active", tint: .green)
            } else if !slot.isUsed {
                SlotBadge(text: "Unused", tint: .secondary)
            } else {
                SlotBadge(text: "Inactive", tint: .secondary)
            }
        }
    }
}

private struct SlotBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}
