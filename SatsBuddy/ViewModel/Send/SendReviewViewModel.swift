//
//  SendReviewViewModel.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 11/21/25.
//

import BitcoinDevKit
import Foundation

@MainActor
@Observable
class SendReviewViewModel {
    //    let bdkClient: BDKClient

    var buildTransactionViewError: AppError?
    var calculateFee: String?
    var psbt: Psbt?
    var showingBuildTransactionViewErrorAlert = false

    //    init(
    //        bdkClient: BDKClient = .live
    //    ) {
    //        self.bdkClient = bdkClient
    //    }

    func buildTransaction(address: String, amount: UInt64, feeRate: UInt64) {

    }

    func extractTransaction() -> BitcoinDevKit.Transaction? {
        return nil
    }

    func getCalulateFee(tx: BitcoinDevKit.Transaction) {

    }

    func send(address: String, amount: UInt64, feeRate: UInt64) {
    }

}
