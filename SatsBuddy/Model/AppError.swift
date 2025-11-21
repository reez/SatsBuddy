//
//  AppError.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 11/21/25.
//

import Foundation

enum AppError: Error, LocalizedError {
    case generic(message: String)

    var description: String? {
        switch self {
        case .generic(let message):
            return message
        }
    }
}
