//
//  SatsCardListView.swift
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
                        Section("SATSCARDs") {
                            ForEach(viewModel.scannedCards) { card in
                                NavigationLink {
                                    SatsCardDetailView(
                                        card: card,
                                        viewModel: .init(),
                                        cardViewModel: viewModel
                                    )
                                } label: {
                                    SatsCardView(
                                        card: card,
                                        onRemove: {
                                            viewModel.removeCard(card)
                                        },
                                        cardViewModel: viewModel
                                    )
                                }
                                .listRowBackground(Color.clear)
                                .buttonStyle(PlainButtonStyle())
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    viewModel.removeCard(viewModel.scannedCards[index])
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                Spacer()
            }
            .navigationTitle("SatsBuddy".uppercased())
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
                }
            }
            .toolbarBackground(.visible, for: .bottomBar)
            .toolbarBackground(.ultraThinMaterial, for: .bottomBar)
        }
    }
}

#if DEBUG
    #Preview {
        let vm = SatsCardViewModel(ckTapService: .mock, cardsStore: .mock)
        vm.scannedCards = [
            SatsCardInfo(
                version: "1.0.3",
                birth: 1,
                address: "bc1qrp33g013ahg3pq0ny9kxwj42yl4xpr3xz4fzqc",
                pubkey: "02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9388",
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
#endif
