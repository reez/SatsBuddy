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
    @State private var pubkeyCopied = false
    @State private var addressCopied = false
    private let footer: Footer

    init(slot: SlotInfo, @ViewBuilder footer: () -> Footer) {
        self.slot = slot
        self.footer = footer()
    }

    var body: some View {
        SlotCard {
            VStack(alignment: .leading, spacing: 18) {
                SlotSummaryHeader(slot: slot, showsChevron: false, showsSlotTitle: false)

                if slot.isActive || slot.balance != nil {
                    balanceRow
                }

                if slot.isUsed {
                    addressRow
                    explorerRow

                    if slot.pubkey != nil {
                        pubkeyRow
                    }

                    footer
                } else {
                    unusedRow
                }
            }
        }
    }
}

#Preview {
    SlotRowView(
        slot: .init(
            slotNumber: UInt8(1),
            isActive: true,
            isUsed: true,
            pubkey: "03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c",
            pubkeyDescriptor: nil,
            address: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            balance: 21_000
        )
    )
    .padding()
}

extension SlotRowView where Footer == EmptyView {
    init(slot: SlotInfo) {
        self.init(slot: slot) { EmptyView() }
    }
}

extension SlotRowView {
    fileprivate var addressRow: some View {
        Group {
            if let address = slot.address, !address.isEmpty {
                Button {
                    UIPasteboard.general.string = address
                    addressCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        addressCopied = false
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        label("Address")

                        HStack(spacing: 12) {
                            Text(address)
                                .font(.body)
                                .fontDesign(.monospaced)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer(minLength: trailingAccessoryMinWidth)

                            Image(systemName: addressCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(addressCopied ? .green : .blue)
                                .symbolEffect(.bounce, value: addressCopied)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: addressCopied) { _, newValue in newValue }
            } else {
                fallbackRow(title: "Address", value: "No address available")
            }
        }
    }

    fileprivate var balanceRow: some View {
        Group {
            if let balance = slot.balance {
                VStack(alignment: .leading, spacing: 4) {
                    label("Balance")
                    HStack(spacing: 8) {
                        Image(systemName: "bitcoinsign")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(balance.formatted(.number.grouping(.automatic)))
                            .font(.body)
                            .fontWeight(.medium)
                    }
                }
            } else if !slot.isUsed {
                fallbackRow(title: "Balance", value: "No balance yet")
            } else {
                fallbackRow(title: "Balance", value: "Loading…", italic: true)
            }
        }
    }

    @ViewBuilder
    fileprivate var explorerRow: some View {
        if let address = slot.address, !address.isEmpty,
            let url = URL(string: "https://mempool.space/address/\(address)")
        {
            Button {
                UIApplication.shared.open(url)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    label("Explorer")
                    HStack {
                        Image(systemName: "square.bottomhalf.filled")
                            .foregroundStyle(.blue)
                            .font(.body)
                        Text("mempool.space")
                            .font(.body)
                        Spacer(minLength: trailingAccessoryMinWidth)
                        //                        Image(systemName: "square.bottomhalf.filled")
                        //                            .foregroundStyle(.blue)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            fallbackRow(title: "Explorer", value: "Explorer unavailable")
        }
    }

    fileprivate var pubkeyRow: some View {
        Group {
            if let pubkey = slot.pubkey, !pubkey.isEmpty {
                Button {
                    UIPasteboard.general.string = pubkey
                    pubkeyCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        pubkeyCopied = false
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        label("Pubkey")

                        HStack(spacing: 12) {
                            Text(pubkey)
                                .font(.body)
                                .fontDesign(.monospaced)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer(minLength: trailingAccessoryMinWidth)

                            Image(systemName: pubkeyCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(pubkeyCopied ? .green : .blue)
                                .symbolEffect(.bounce, value: pubkeyCopied)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: pubkeyCopied) { _, newValue in newValue }
            } else {
                fallbackRow(title: "Pubkey", value: "No pubkey available")
            }
        }
    }

    fileprivate var unusedRow: some View {
        fallbackRow(
            title: "Status",
            value: "This slot has not been used yet",
            italic: true
        )
    }

    fileprivate func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    fileprivate var trailingAccessoryMinWidth: CGFloat { 80 }

    fileprivate func fallbackRow(
        title: String,
        value: String,
        italic: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label(title)
            Text(value)
                .font(.body)
                .foregroundStyle(.tertiary)
                .italic(italic)
        }
    }
}

extension Text {
    fileprivate func italic(_ apply: Bool) -> Text {
        apply ? self.italic() : self
    }
}

private struct SlotCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                shape
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.45))
            )
            .overlay(
                shape
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .clipShape(shape)
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
