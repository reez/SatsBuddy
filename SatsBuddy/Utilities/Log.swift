//
//  Log.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/2/25.
//

import Foundation
import os

#if DEBUG
    enum Log {
        static let subsystem = Bundle.main.bundleIdentifier ?? "com.matthewramsden.SatsBuddy"

        static let nfc = Logger(subsystem: subsystem, category: "NFC")
        static let cktap = Logger(subsystem: subsystem, category: "CKTap")
        static let ui = Logger(subsystem: subsystem, category: "UI")
    }
#else
    /// Release builds: use the disabled OSLog sink so all log calls are dropped at runtime
    /// while keeping the same call-site surface (privacy annotations still compile).
    enum Log {
        static let subsystem = Bundle.main.bundleIdentifier ?? "com.matthewramsden.SatsBuddy"

        static let nfc = Logger(OSLog.disabled)
        static let cktap = Logger(OSLog.disabled)
        static let ui = Logger(OSLog.disabled)
    }
#endif
