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

                        if sweptBalance != nil {
                            Text("Final amount sent is current slot balance minus network fee.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
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
        fee: 17,
        onContinue: {}
    )
}
