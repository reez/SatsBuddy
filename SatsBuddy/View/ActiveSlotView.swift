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

    @State private var copied = false
    @State private var showingReceiveSheet = false
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

                if isLoading && slot.balance == nil {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            Spacer()

            if let address = slot.address,
                let activeSlot = card.activeSlot,
                let totalSlots = card.totalSlots
            {
                let pubkey = card.pubkey
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Receive")
                                .foregroundStyle(.secondary)
                            Button {
                                isPreparingReceiveSheet = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showingReceiveSheet = true
                                }
                                print("tapped receive!")
                            } label: {
                                HStack {
                                    Text("Show receive options")
                                        .foregroundColor(.primary)

                                    Spacer()

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
                            .buttonStyle(.plain)
                        }

                        // Pubkey row
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pubkey")
                                .foregroundStyle(.secondary)
                            Text(pubkey)
                                .truncationMode(.middle)
                                .lineLimit(1)
                        }

                        // Verify button row
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Explorer")
                                .foregroundStyle(.secondary)
                            Button {
                                if let url = URL(string: "https://mempool.space/address/\(address)")
                                {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("View on mempool.space")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Section {
                        // Slot row
                        NavigationLink {
                            SlotsRowListView(
                                totalSlots: totalSlots,
                                slots: viewModel.slots
                            )
                            .navigationTitle("All Slots")
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Slot")
                                    .foregroundStyle(.secondary)
                                Text("\(activeSlot)/\(totalSlots)")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollDisabled(true)
                .sheet(
                    isPresented: $showingReceiveSheet,
                    onDismiss: {
                        isPreparingReceiveSheet = false
                    }
                ) {
                    ReceiveView(  //ReceiveOptionsSheet(
                        address: address,
                        //                        pubkey: pubkey,
                        isCopied: $copied
                    )
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
            viewModel: SatsCardDetailViewModel()
        )
        .padding()
    }
#endif

//private struct ReceiveOptionsSheet: View {
//    let address: String
//    let pubkey: String
//    @Binding var isCopied: Bool
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
////                                Text("View on mempool.space")
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
//                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
