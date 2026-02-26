//
//  SendFlowView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 11/21/25.
//

import SwiftUI

struct SendFlowView: View {
    let slot: SlotInfo
    let card: SatsCardInfo
    let onBroadcastSuccess: (() -> Void)?

    private enum Step {
        case destination
        case fee(address: String)
        case review(address: String, fee: Int)
        case sign(address: String, fee: Int)
    }

    @State private var step: Step = .destination
    @Environment(\.dismiss) private var dismiss

    init(
        slot: SlotInfo,
        card: SatsCardInfo,
        onBroadcastSuccess: (() -> Void)? = nil
    ) {
        self.slot = slot
        self.card = card
        self.onBroadcastSuccess = onBroadcastSuccess
    }

    var body: some View {
        VStack {
            switch step {
            case .destination:
                SendDestinationView { address in
                    step = .fee(address: address)
                }
            case .fee(let address):
                SendFeeView(
                    viewModel: .init(feeClient: .live),
                    address: address,
                    amount: "ALL"
                ) { fee in
                    step = .review(address: address, fee: fee)
                }
            case .review(let address, let fee):
                SendReviewView(
                    address: address,
                    amount: "ALL",
                    fee: fee
                ) {
                    step = .sign(address: address, fee: fee)
                }
            case .sign(let address, let fee):
                SendSignView(
                    viewModel: SendSignViewModel(
                        address: address,
                        feeRate: fee,
                        slot: slot,
                        network: .bitcoin
                    ),
                    onDone: {
                        onBroadcastSuccess?()
                        dismiss()
                    }
                )
            }
        }
        .navigationTitle("Send")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let slot = SlotInfo(
        slotNumber: 1,
        isActive: true,
        isUsed: true,
        pubkey: "02abc",
        pubkeyDescriptor: "wpkh(02abc)",
        address: "bc1qexample",
        balance: 50_000
    )
    let card = SatsCardInfo(
        version: "1.0.3",
        address: slot.address,
        pubkey: slot.pubkey ?? "",
        cardIdent: "DEMO-CARD",
        activeSlot: slot.slotNumber,
        totalSlots: 10,
        slots: [slot],
        isActive: true
    )
    SendFlowView(slot: slot, card: card)
}
