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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Slot \(slot.slotNumber)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if slot.isActive {
                    Text("ACTIVE")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }

                if !slot.isUsed {
                    Text("UNUSED")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(4)
                }
            }

            if slot.isUsed {
                if let address = slot.address {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Address:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(address)
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .truncationMode(.middle)
                                .lineLimit(1)

                            if slot.isActive {
                                if let balance = slot.balance {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 2) {
                                            Image(systemName: "bitcoinsign")
                                                .font(.caption2)
                                                .foregroundStyle(.primary)
                                            Text("\(balance)")
                                                .font(.caption2)
                                                .foregroundStyle(.primary)
                                                .fontWeight(.medium)
                                        }

                                        Button {
                                            if let url = URL(
                                                string: "https://mempool.space/address/\(address)"
                                            ) {
                                                UIApplication.shared.open(url)
                                            }
                                        } label: {
                                            Text("View on Mempool.space")
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } else {
                                    Text("Balance: Loading...")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .fontWeight(.medium)
                                }
                            }
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Button {
                                if let url = URL(string: "https://mempool.space/address/\(address)")
                                {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Image(systemName: "link")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)

                            Button {
                                UIPasteboard.general.string = address
                                addressCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    addressCopied = false
                                }
                            } label: {
                                Image(systemName: addressCopied ? "doc.on.doc.fill" : "doc.on.doc")
                                    .font(.caption)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let pubkey = slot.pubkey {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pubkey:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(pubkey)
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .truncationMode(.middle)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            UIPasteboard.general.string = pubkey
                            pubkeyCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                pubkeyCopied = false
                            }
                        } label: {
                            Image(systemName: pubkeyCopied ? "doc.on.doc.fill" : "doc.on.doc")
                                .font(.caption)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("This slot has not been used yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
}

#Preview {
    SlotRowView(
        slot: .init(
            slotNumber: UInt8(1),
            isActive: true,
            isUsed: false,
            pubkey: "pubkey",
            pubkeyDescriptor: "pubkeyDescriptor",
            address: "address",
            balance: 21000
        )
    )
}
