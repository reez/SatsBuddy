//
//  SlotRowView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/8/25.
//

import SwiftUI

struct SlotRowView: View {
    let slot: SlotInfo
    @State private var pubkeyCopied = false
    @State private var addressCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            slotSummary

            if slot.isUsed {
                if slot.isActive {
                    balanceRow
                }

                addressRow
                explorerRow

                if slot.pubkey != nil {
                    pubkeyRow
                }
            } else {
                unusedRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 20))
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

extension SlotRowView {
    fileprivate var slotSummary: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Slot \(slot.slotNumber)")
                .font(.body)
                .fontWeight(.medium)

            statusBadges
            Spacer()
        }
    }

    fileprivate var addressRow: some View {
        Group {
            if let address = slot.address, !address.isEmpty {
                Button {
                    UIPasteboard.general.string = address
                    addressCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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
                        Text("Verify on mempool.space")
                            .font(.body)
                        Spacer(minLength: trailingAccessoryMinWidth)
                        Image(systemName: "globe")
                            .foregroundStyle(.tint)
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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

    @ViewBuilder
    fileprivate var statusBadges: some View {
        HStack(spacing: 8) {
            if slot.isActive {
                StatusBadge(text: "Active", tint: .green)
            }

            if !slot.isUsed {
                StatusBadge(text: "Unused", tint: .secondary)
            }
        }
    }

    fileprivate func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    fileprivate var trailingAccessoryMinWidth: CGFloat { 80 }

    fileprivate var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(uiColor: .secondarySystemBackground).opacity(0.45))
    }

    fileprivate var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(Color.white.opacity(0.06), lineWidth: 1)
    }

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

extension SlotRowView {
    fileprivate struct StatusBadge: View {
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
}
