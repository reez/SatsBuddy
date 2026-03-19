//
//  FeeViewModel.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 11/21/25.
//

import BitcoinDevKit
import Foundation

@MainActor
@Observable
class FeeViewModel {
    let feeClient: FeeClient
    private let manualFallbackFees = [1, 2, 5, 10]

    var feeViewError: AppError?
    var isLoadingFees = false
    var availableFees: [Int]? {
        if let fees = recommendedFees {
            return [
                fees.minimumFee,
                fees.hourFee,
                fees.halfHourFee,
                fees.fastestFee,
            ]
        }

        if feeViewError != nil {
            return manualFallbackFees
        }

        return nil
    }
    var isUsingManualFeeFallback: Bool {
        recommendedFees == nil && feeViewError != nil
    }
    var selectedFee: Int? {
        guard let fees = availableFees, fees.indices.contains(selectedFeeIndex) else {
            return nil
        }
        return fees[selectedFeeIndex]
    }
    var selectedFeeDescription: String {
        if isLoadingFees {
            return "Loading recommended fees"
        }
        if isUsingManualFeeFallback, let selectedFee {
            return "Selected manual fee: \(selectedFee) sat/vB"
        }
        guard let selectedFee = selectedFee else {
            return "Failed to load fees"
        }
        let feeText = text(for: selectedFeeIndex)
        return "Selected \(feeText) Fee: \(selectedFee) sats"
    }
    var selectedFeeIndex: Int = 2
    var recommendedFees: RecommendedFees?

    init(
        feeClient: FeeClient = .live
    ) {
        self.feeClient = feeClient
    }

    func getFees(forceRefresh: Bool = false) async {
        guard !isLoadingFees else { return }
        if !forceRefresh, recommendedFees != nil {
            return
        }

        isLoadingFees = true
        feeViewError = nil

        do {
            let recommendedFees = try await feeClient.fetchFees()
            self.recommendedFees = recommendedFees
        } catch {
            self.recommendedFees = nil
            self.feeViewError = .generic(
                message:
                    "Couldn't load recommended fee rates. Check your connection and try again."
            )
        }

        isLoadingFees = false
    }

    private func text(for index: Int) -> String {
        switch index {
        case 0:
            return "No Priority"
        case 1:
            return "Low Priority"
        case 2:
            return "Medium Priority"
        case 3:
            return "High Priority"
        default:
            return ""
        }
    }

}
