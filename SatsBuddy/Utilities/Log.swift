//
//  Log.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/2/25.
//

import Foundation
import os

enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.matthewramsden.SatsBuddy"

    static let nfc = Logger(subsystem: subsystem, category: "NFC")
    static let cktap = Logger(subsystem: subsystem, category: "CKTap")
    static let ui = Logger(subsystem: subsystem, category: "UI")
}
