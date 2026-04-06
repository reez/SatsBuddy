//
//  SendReviewView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 11/21/25.
//

import BitcoinUI
import SwiftUI

struct SendReviewView: View {
    @Environment(\.colorScheme) var colorScheme
    let address: String
    let amount: String
    let sweptBalance: UInt64?
    let slotDisplayNumber: Int
    let requiresUnsealBeforeSweep: Bool
    let activatesNextSlotAfterSweep: Bool
    let fee: Int
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)

            VStack {
                Spacer()

                VStack(spacing: 20) {
                    Spacer()

                    VStack(spacing: 40) {
                        Text("Review sweep")
                            .font(.title2)
                            .fontWeight(.semibold)

                        VStack(spacing: 0) {
                            HStack {
                                Text("Destination")
                                Spacer()
                                Text(address)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.bottom, 8)

                            Divider().background(Color(uiColor: .systemGray6))

                            HStack {
                                Text("Fee rate")
                                Spacer()
                                Text("\(fee) sat/vB")
                            }
                            .padding(.vertical, 8)

                            Divider().background(Color(uiColor: .systemGray6))

                            HStack {
                                Text("Amount")
                                Spacer()
                                Text(displayAmount)
                                    .minimumScaleFactor(0.25)
                            }
                            .padding(.top, 8)
                            .fontWeight(.semibold)
                        }
                        .padding()
                        .background(
                            Color(uiColor: .secondarySystemBackground)
                                .opacity(colorScheme == .dark ? 0.5 : 0.2)
                        )
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    Color(uiColor: .systemGray6),
                                    lineWidth:
                                        1
                                )
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Final amount sent is current slot balance minus network fee.")
                            Text(
                                Self.sweepDisclosure(
                                    for: slotDisplayNumber,
                                    requiresUnsealBeforeSweep: requiresUnsealBeforeSweep,
                                    activatesNextSlotAfterSweep: activatesNextSlotAfterSweep
                                )
                            )
                            if activatesNextSlotAfterSweep {
                                Text(Self.nextSlotSetupDisclosure)
                            }
                        }
                        .font(.footnote)
                        .minimumScaleFactor(0.25)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()

                    Spacer()

                    Button {
                        onContinue()
                    } label: {
                        Text("Continue")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.all, 8)
                    }
                    .buttonStyle(
                        BitcoinFilled(
                            tintColor: .primary,
                            textColor: Color(uiColor: .systemBackground),
                            isCapsule: true
                        )
                    )
                    .padding()
                    .accessibilityLabel("Continue to sign")
                }
            }
            .padding()
            .navigationTitle("Transaction")
        }
    }
}

extension SendReviewView {
    static let nextSlotSetupDisclosure =
        "If another slot is available, SatsBuddy will activate it automatically so the card is ready to receive again."

    static func sweepDisclosure(
        for slotDisplayNumber: Int,
        requiresUnsealBeforeSweep: Bool,
        activatesNextSlotAfterSweep: Bool
    ) -> String {
        guard activatesNextSlotAfterSweep else {
            return
                "Slot \(slotDisplayNumber) is already unsealed. Continuing will sweep funds from that slot without changing the SATSCARD's current slot."
        }

        guard requiresUnsealBeforeSweep else {
            return
                "Slot \(slotDisplayNumber) is already unsealed. Continuing will sweep funds from that slot and move this SATSCARD to the next slot."
        }

        return
            "Continuing will permanently unseal Slot \(slotDisplayNumber) and move this SATSCARD to the next slot."
    }

    fileprivate var displayAmount: String {
        guard let sweptBalance else { return amount }
        return "\(amount) (\(sweptBalance.formatted(.number)) sats)"
    }
}

#Preview {
    SendReviewView(
        address:
            "tb1pxg0lakl0x4jee73f38m334qsma7mn2yv764x9an5ylht6tx8ccdsxtktrt",
        amount: "ALL",
        sweptBalance: 100_000,
        slotDisplayNumber: 3,
        requiresUnsealBeforeSweep: true,
        activatesNextSlotAfterSweep: true,
        fee: 17,
        onContinue: {}
    )
}

#Preview("Accessibility 3") {
    SendReviewView(
        address:
            "tb1pxg0lakl0x4jee73f38m334qsma7mn2yv764x9an5ylht6tx8ccdsxtktrt",
        amount: "ALL",
        sweptBalance: 1_250_000,
        slotDisplayNumber: 10,
        requiresUnsealBeforeSweep: true,
        activatesNextSlotAfterSweep: true,
        fee: 17,
        onContinue: {}
    )
    .dynamicTypeSize(.accessibility3)
}
