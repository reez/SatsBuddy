//
//  ActiveSlotView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/25/25.
//

import SwiftUI
import UIKit

//import CoreImage
//import CoreImage.CIFilterBuiltins

struct ActiveSlotView: View {
    let slot: SlotInfo
    let card: SatsCardInfo
    let isLoading: Bool
    let viewModel: SatsCardDetailViewModel
    let isScanning: Bool
    let onRefresh: () -> Void

    @State private var copied = false
    @State private var isPubkeyCopied = false
    @State private var receiveSheetState: ReceiveSheetState?
    @State private var isPreparingReceiveSheet = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 32) {
                HStack {
                    Image(systemName: "bitcoinsign")
                        .font(.title)
                        .fontWeight(.regular)
                        .foregroundStyle(.secondary)
                    Text(slot.balance?.formatted(.number.grouping(.automatic)) ?? "1,234")
                        .redacted(reason: slot.balance == nil ? .placeholder : [])
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 20, height: 20)
                        .opacity(isLoading ? 1 : 0)
                        .accessibilityHidden(!isLoading)
                    Spacer()
                }
                .font(.largeTitle)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .padding()

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
            }

            Spacer()

            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Receive")
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(displayAddress ?? "No address")
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer(minLength: 80)

                            if isPreparingReceiveSheet {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard let address = displayAddress else { return }

                        isPreparingReceiveSheet = true
                        receiveSheetState = ReceiveSheetState(address: address)
                        print("tapped receive!")
                    }

                    // Pubkey row
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pubkey")
                            .foregroundStyle(.secondary)
                        Button {
                            UIPasteboard.general.string = displayPubkey
                            isPubkeyCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                isPubkeyCopied = false
                            }
                        } label: {
                            HStack {
                                Text(displayPubkey)
                                    .truncationMode(.middle)
                                    .lineLimit(1)

                                Spacer(minLength: 80)

                                Image(systemName: isPubkeyCopied ? "checkmark" : "doc.on.doc")
                                    .font(.caption)
                                    .foregroundStyle(isPubkeyCopied ? .green : .blue)
                                    .symbolEffect(.bounce, value: isPubkeyCopied)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .disabled(displayPubkey.isEmpty)
                    }

                    Button {
                        guard let address = displayAddress else { return }
                        if let url = URL(string: "https://mempool.space/address/\(address)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Explorer")
                                    .foregroundStyle(.secondary)
                                Text("Verify on mempool.space")
                                    .foregroundColor(.primary)
                            }

                            Spacer()

                            Image(systemName: "globe")
                                .foregroundStyle(.tint)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(displayAddress == nil)
                }

                Section {
                    // Slot row
                    NavigationLink {
                        SlotsRowListView(
                            totalSlots: card.totalSlots ?? UInt8(clamping: viewModel.slots.count),
                            slots: viewModel.slots
                        )
                        .navigationTitle("All Slots")
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Slot")
                                .foregroundStyle(.secondary)
                            Text(slotPositionText)
                                .foregroundColor(.primary)
                        }
                    }
                    .disabled(card.totalSlots == nil)

                    Button(action: onRefresh) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Card Refresh")
                                    .foregroundStyle(.secondary)
                                Text(refreshTimestampText)
                                    .foregroundColor(.primary)
                            }

                            Spacer()

                            if isScanning {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "wave.3.up")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(isScanning)
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .animation(.smooth, value: isLoading)
            .sheet(
                item: $receiveSheetState,
                onDismiss: {
                    isPreparingReceiveSheet = false
                }
            ) { sheetState in
                ReceiveView(
                    address: sheetState.address,
                    isCopied: $copied
                )
                .onAppear {
                    isPreparingReceiveSheet = false
                }
            }

            Spacer()
        }
    }
}

#if DEBUG
    #Preview {
        let slot = SlotInfo(
            slotNumber: 1,
            isActive: true,
            isUsed: true,
            pubkey: "03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c",
            pubkeyDescriptor:
                "wpkh(03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c)",
            address: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            balance: 50_000
        )

        let card = SatsCardInfo(
            version: "1.0.3",
            address: slot.address,
            pubkey: slot.pubkey
                ?? "03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c",
            activeSlot: 1,
            totalSlots: 10,
            slots: [slot],
            isActive: true
        )

        return ActiveSlotView(
            slot: slot,
            card: card,
            isLoading: false,
            viewModel: SatsCardDetailViewModel(),
            isScanning: false,
            onRefresh: {}
        )
        .padding()
    }
#endif

private struct ReceiveSheetState: Identifiable {
    let id = UUID()
    let address: String
}

extension ActiveSlotView {
    fileprivate var displayAddress: String? {
        slot.address ?? card.address
    }

    fileprivate var displayPubkey: String {
        slot.pubkey ?? card.pubkey
    }

    fileprivate var slotPositionText: String {
        if let activeSlot = card.activeSlot,
            let totalSlots = card.totalSlots
        {
            return "\(activeSlot)/\(totalSlots)"
        }

        if let totalSlots = card.totalSlots {
            return "\(slot.slotNumber)/\(totalSlots)"
        }

        return "--/--"
    }

    fileprivate var refreshTimestampText: String {
        card.dateScanned.formatted(date: .abbreviated, time: .shortened)
    }
}

//
//    @Environment(\.dismiss) private var dismiss
////    private let context = CIContext()
////    private let filter = CIFilter.qrCodeGenerator()
//
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 24) {
//
//                    // QR
////                    qrCodeView
//
//                    VStack(alignment: .leading, spacing: 12) {
//
//                        // Address
////                        section(title: "Address") {
////                            copyButton(text: address)
////                        }
//
//                        // Pubkey
////                        section(title: "Pubkey") {
////                            Text(pubkey)
////                                .font(.system(.footnote, design: .monospaced))
////                                .foregroundStyle(.primary)
////                                .lineLimit(2)
////                                .truncationMode(.middle)
////                                .frame(maxWidth: .infinity, alignment: .leading)
////                        }
//
//                        // Mempool button
////                        Button {
////                            if let url = URL(string: "https://mempool.space/address/\(address)") {
////                                UIApplication.shared.open(url)
////                            }
////                        } label: {
////                            HStack {
////                                Text("Verify on mempool.space")
////                                Spacer()
////                                Image(systemName: "arrow.up.right")
////                            }
////                            .font(.body.weight(.medium))
////                        }
////                        .buttonStyle(.bordered)
////                        .frame(maxWidth: .infinity, alignment: .leading)
//
//
//                    }
//                    .padding()
//                }
//                .padding()
//            }
//            .navigationTitle("Receive")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .confirmationAction) {
//                    Button("Done", action: dismiss.callAsFunction)
//                }
//            }
//        }
//    }
//
//    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
//        VStack(alignment: .leading, spacing: 6) {
//            Text(title.uppercased())
//                .font(.caption)
//                .foregroundStyle(.secondary)
//            content()
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//    }
//
//    private func copyButton(text: String) -> some View {
//        Button {
//            UIPasteboard.general.string = text
//            isCopied = true
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//                isCopied = false
//            }
//        } label: {
//            HStack {
//                Text(text)
//                    .font(.system(.footnote, design: .monospaced))
//                    .lineLimit(2)
//                    .truncationMode(.middle)
//                Spacer()
//                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
//                    .foregroundColor(isCopied ? .green : .secondary)
//                    .symbolEffect(.bounce, value: isCopied)
//            }
//            .padding()
//            .background(
//                RoundedRectangle(cornerRadius: 20, style: .continuous)
//                    .fill(Color(.secondarySystemGroupedBackground))
//            )
//        }
//        .buttonStyle(.plain)
//    }
//
////    private var qrCodeView: some View {
////        Group {
////            if let image = qrImage(from: address) {
////                Image(uiImage: image)
////                    .interpolation(.none)
////                    .resizable()
////                    .scaledToFit()
////                    .frame(width: 180, height: 180)
////                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
////                    .padding(.top)
////            } else {
////                ProgressView()
////                    .frame(width: 180, height: 180)
////            }
////        }
////    }
//
////    private func qrImage(from string: String) -> UIImage? {
////        let data = Data(string.utf8)
////        filter.setValue(data, forKey: "inputMessage")
////
////        guard let outputImage = filter.outputImage,
////            let cgImage = context.createCGImage(outputImage, from: outputImage.extent)
////        else {
////            return nil
////        }
////
////        return UIImage(cgImage: cgImage)
////    }
//}
