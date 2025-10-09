//
//  MempoolTransaction.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 10/10/25.
//

import Foundation

struct MempoolTransaction: Decodable {
    struct Status: Decodable {
        let confirmed: Bool
        let block_time: UInt64?
    }

    struct Vin: Decodable {
        struct Prevout: Decodable {
            let scriptpubkey_address: String?
            let value: UInt64?
        }

        let prevout: Prevout?
    }

    struct Vout: Decodable {
        let scriptpubkey_address: String?
        let value: UInt64
    }

    let txid: String
    let fee: UInt64?
    let status: Status
    let vin: [Vin]
    let vout: [Vout]
}
