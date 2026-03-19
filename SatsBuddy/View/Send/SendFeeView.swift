//
//  SendFeeView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 11/21/25.
//

import BitcoinDevKit
import BitcoinUI
import SwiftUI

struct SendFeeView: View {
    @Bindable var viewModel: FeeViewModel
    let address: String
    let amount: String
    let onNext: (Int) -> Void

    var body: some View {

        ZStack {
            Color(uiColor: .systemBackground)

            VStack {

                Spacer()

                VStack(spacing: 16) {
                    if viewModel.isLoadingFees && viewModel.availableFees == nil {
                        VStack(spacing: 12) {
                            ProgressView()

                            Text("Loading recommended fee rates...")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        if viewModel.isUsingManualFeeFallback {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Live fee estimates unavailable")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(
                                    "Choose a manual fee rate from 1, 2, 5, or 10 sat/vB, or retry the fee lookup. Lower fees may confirm slowly when the network is busy."
                                )
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    Task {
                                        await viewModel.getFees(forceRefresh: true)
                                    }
                                } label: {
                                    Text("Retry fee lookup")
                                        .bold()
                                        .frame(maxWidth: .infinity)
                                        .padding(.all, 8)
                                }
                                .buttonStyle(
                                    BitcoinOutlined(
                                        tintColor: .primary,
                                        isCapsule: true
                                    )
                                )
                                .disabled(viewModel.isLoadingFees)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        Slider(
                            value: feeSliderBinding,
                            in: 0...3,
                            step: 1
                        ) {
                            Text("Fee Priority")
                        } minimumValueLabel: {
                            Text(feeSliderEdgeLabel(for: 0))
                        } maximumValueLabel: {
                            Text(feeSliderEdgeLabel(for: 3))
                        }
                        .tint(.primary)
                        .accessibilityLabel("Select Transaction Fee")
                        .accessibilityValue(feeAccessibilityValue)

                        HStack(spacing: 8) {
                            ForEach(0..<4, id: \.self) { index in
                                VStack(spacing: 4) {
                                    feeIcon(for: index)
                                        .font(.headline)
                                    Text(feeOptionLabel(for: index))
                                        .font(.caption2)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(
                                            index == viewModel.selectedFeeIndex
                                                ? .primary : .secondary
                                        )
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }

                        if let selectedFee = viewModel.selectedFee {
                            Text(selectedFeeText(selectedFee))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    guard let selectedFee = viewModel.selectedFee else { return }
                    onNext(selectedFee)
                } label: {
                    Label(
                        title: { Text("Next") },
                        icon: { Image(systemName: "arrow.right") }
                    )
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(
                    BitcoinOutlined(
                        width: 100,
                        tintColor: .primary,
                        isCapsule: true
                    )
                )
                .disabled(viewModel.selectedFee == nil || viewModel.isLoadingFees)

            }
            .padding()
            .navigationTitle("Fee Priority")
            .task {
                await viewModel.getFees()
            }

        }
    }

}

extension SendFeeView {
    fileprivate var feeAccessibilityValue: String {
        guard let selectedFee = viewModel.selectedFee else {
            return "Recommended fees unavailable"
        }
        if viewModel.isUsingManualFeeFallback {
            return "\(selectedFee) satoshis per vbyte, manual fee"
        }
        return "\(selectedFee) satoshis per vbyte"
    }

    fileprivate var feeSliderBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.selectedFeeIndex) },
            set: { viewModel.selectedFeeIndex = Int($0.rounded()) }
        )
    }

    fileprivate func feeValue(for index: Int) -> Int {
        guard let fees = viewModel.availableFees, fees.indices.contains(index) else { return 0 }
        return fees[index]
    }

    fileprivate func feeTitle(for index: Int) -> String {
        switch index {
        case 0: return "None"
        case 1: return "Low"
        case 2: return "Medium"
        default: return "High"
        }
    }

    fileprivate func feeSliderEdgeLabel(for index: Int) -> String {
        if viewModel.isUsingManualFeeFallback {
            return "\(feeValue(for: index))"
        }
        return feeTitle(for: index)
    }

    fileprivate func feeOptionLabel(for index: Int) -> String {
        let value = feeValue(for: index)
        if viewModel.isUsingManualFeeFallback {
            return "\(value) sat/vB"
        }
        return "\(feeTitle(for: index)) • \(value)"
    }

    fileprivate func selectedFeeText(_ selectedFee: Int) -> String {
        if viewModel.isUsingManualFeeFallback {
            return "Selected: \(selectedFee) sat/vB manual fee"
        }
        return "Selected: \(selectedFee) sat/vB fee"
    }

    @ViewBuilder
    fileprivate func feeIcon(for index: Int) -> some View {
        Image(
            systemName: "bitcoinsign.gauge.chart.leftthird.topthird.rightthird",
            variableValue: Double(index) / 3.0
        )
    }
}

#if DEBUG
    #Preview("Recommended Fees") {
        SendFeeView(
            viewModel: .init(feeClient: .mock),
            address: "tb1pxg0lakl0x4jee73f38m334qsma7mn2yv764x9an5ylht6tx8ccdsxtktrt",
            amount: "50",
            onNext: { _ in }
        )
    }

    #Preview("Manual Fee Fallback") {
        SendFeeView(
            viewModel: .init(feeClient: .failingMock),
            address: "tb1pxg0lakl0x4jee73f38m334qsma7mn2yv764x9an5ylht6tx8ccdsxtktrt",
            amount: "50",
            onNext: { _ in }
        )
    }
#endif
