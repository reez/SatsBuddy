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

    init(slot: SlotInfo, @ViewBuilder footer: () -> Footer) {
        self.slot = slot
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            //            if slot.isActive {
            //                Text("Active")
            //                    .font(.headline)
            //                    .foregroundStyle(.secondary)
            //            }

            if slot.isActive || slot.balance != nil, let balance = slot.balance {
                HStack(spacing: 8) {
                    Image(systemName: "bitcoinsign")
                        //                        .font(.body)
                        .foregroundStyle(.secondary)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(balance.formatted(.number.grouping(.automatic)))
                        //                        .font(.body)
                        .foregroundStyle(.primary)
                        .font(.title)
                        .fontWeight(.semibold)

                }
            }

            if slot.isUsed, let address = slot.address, !address.isEmpty {
                //                Button {
                //                    UIPasteboard.general.string = address
                //                    addressCopied = true
                //                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                //                        addressCopied = false
                //                    }
                //                } label: {
                HStack {
                    Text(address)
                        .font(.body)
                        .fontDesign(.monospaced)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.primary)  //.foregroundStyle(addressCopied ? .green : .primary)

                    //                        if addressCopied {
                    //                            Image(systemName: "checkmark")
                    //                                .font(.body)
                    //                                .foregroundStyle(.green)
                    //                                .symbolEffect(.bounce, value: addressCopied)
                    //                        }

                    Spacer(minLength: 80)
                }
                //                    .frame(maxWidth: .infinity, alignment: .leading)
                //                }
                //                .buttonStyle(.plain)
                //                .sensoryFeedback(.success, trigger: addressCopied) { _, newValue in newValue }
            }

            if slot.isActive {
                //                Text("Active")
                //                    .font(.headline)
                //                    .foregroundStyle(.secondary)
                SlotBadge(text: "Active", tint: .green)
                    .padding(.top, 10)
            }

            footer
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
