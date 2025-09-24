//
//  ContentView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 8/6/25.
//

import SwiftUI

struct ContentView: View {
    @State var viewModel: SatsCardViewModel

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.scannedCards.isEmpty {
                    ContentUnavailableView(
                        "No Cards",
                        systemImage: "creditcard",
                        description: Text("Tap + to scan your first SatsCard")
                    )
                } else {
                    List {
                        ForEach(viewModel.scannedCards) { card in
                            SatsCardView(
                                card: card,
                                onRemove: {
                                    viewModel.removeCard(card)
                                },
                                cardViewModel: viewModel
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.removeCard(viewModel.scannedCards[index])
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                Spacer()
            }
            .navigationTitle("SatsBuddy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button {
                        viewModel.beginNFCSession()
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.medium)
                    }
                    //                    .buttonStyle(.borderedProminent)
                }
            }
            .toolbarBackground(.visible, for: .bottomBar)
            .toolbarBackground(.ultraThinMaterial, for: .bottomBar)
        }
    }
}

#Preview {
    let vm = SatsCardViewModel(ckTapService: .mock)
    vm.scannedCards = [
        SatsCardInfo(
            version: "1.0.3",
            birth: 1,
            address: "bc1qrp33g013ahg3pq0ny9kxwj42yl4xpr3xz4fzqc",
            activeSlot: 1,
            totalSlots: 10,
            slots: [
                SlotInfo(
                    slotNumber: 0,
                    isActive: false,
                    isUsed: true,
                    pubkey: "02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f",
                    pubkeyDescriptor:
                        "wpkh(02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f)",
                    address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
                    balance: nil
                ),
                SlotInfo(
                    slotNumber: 1,
                    isActive: true,
                    isUsed: true,
                    pubkey: "03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c",
                    pubkeyDescriptor:
                        "wpkh(03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c)",
                    address: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
                    balance: 50000
                ),
            ],
            isActive: true
        )
    ]
    return ContentView(viewModel: vm)
}
