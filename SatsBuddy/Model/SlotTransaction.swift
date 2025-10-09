//
//  SlotTransaction.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 10/10/25.
//

import Foundation

struct SlotTransaction: Identifiable, Codable, Equatable {
    enum Direction: String, Codable {
        case incoming
        case outgoing
    }

    let id: String
    let txid: String
    let amount: Int64
    let fee: UInt64?
    let timestamp: Date?
    let confirmed: Bool
    let direction: Direction

    init(
        txid: String,
        amount: Int64,
        fee: UInt64?,
        timestamp: Date?,
        confirmed: Bool,
        direction: Direction
    ) {
        self.id = txid
        self.txid = txid
        self.amount = amount
        self.fee = fee
        self.timestamp = timestamp
        self.confirmed = confirmed
        self.direction = direction
    }
}
