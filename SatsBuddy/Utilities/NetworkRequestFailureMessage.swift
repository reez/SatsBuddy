//
//  NetworkRequestFailureMessage.swift
//  SatsBuddy
//
//  Created on 4/21/26.
//

import Foundation

enum NetworkRequestFailureMessage {
    enum Context {
        case balance
        case transactions
        case price(hasCachedPrice: Bool)
        case sweepPreparation
        case transactionBroadcast
    }

    static func shouldUseNetworkBackedMessage(for error: Error) -> Bool {
        classify(error) != nil
    }

    static func message(for error: Error, context: Context) -> String {
        let kind = classify(error)

        switch context {
        case .balance:
            switch kind {
            case .offline:
                return "Live balance unavailable while offline. Connect and pull to refresh."
            case .timeout:
                return "Live balance lookup timed out. Check your connection and pull to refresh."
            case .unavailable, .none:
                return "Live balance unavailable right now. Pull to refresh."
            }

        case .transactions:
            switch kind {
            case .offline:
                return "Transaction history unavailable while offline. Connect and try again."
            case .timeout:
                return "Transaction history lookup timed out. Check your connection and try again."
            case .unavailable, .none:
                return "Transaction history unavailable right now. Try again."
            }

        case .price(let hasCachedPrice):
            if hasCachedPrice {
                return "Live BTC price unavailable. Using the last loaded price."
            }

            switch kind {
            case .offline:
                return "Live BTC price unavailable while offline. Connect to load fiat values."
            case .timeout:
                return "Live BTC price lookup timed out. Check your connection and try again."
            case .unavailable, .none:
                return "Live BTC price unavailable right now."
            }

        case .sweepPreparation:
            switch kind {
            case .offline:
                return
                    "An internet connection is required to prepare this sweep. Reconnect and try again."
            case .timeout:
                return "Preparing this sweep timed out while reaching the network. Try again."
            case .unavailable, .none:
                return "The network-backed wallet sync is unavailable right now. Try again."
            }

        case .transactionBroadcast:
            switch kind {
            case .offline:
                return
                    "An internet connection is required to broadcast this transaction. Reconnect and try again."
            case .timeout:
                return "Broadcast timed out while reaching the network. Try again."
            case .unavailable, .none:
                return "Transaction broadcast is unavailable right now. Try again."
            }
        }
    }

    private enum Kind {
        case offline
        case timeout
        case unavailable
    }

    private static func classify(_ error: Error) -> Kind? {
        if let urlError = urlError(from: error) {
            switch urlError.code {
            case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff,
                .cannotLoadFromNetwork, .callIsActive:
                return .offline
            case .timedOut:
                return .timeout
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
                .networkConnectionLost, .resourceUnavailable, .secureConnectionFailed:
                return .unavailable
            default:
                break
            }
        }

        let description = normalizedDescription(for: error)

        if offlineMarkers.contains(where: description.contains) {
            return .offline
        }

        if timeoutMarkers.contains(where: description.contains) {
            return .timeout
        }

        if unavailableMarkers.contains(where: description.contains) {
            return .unavailable
        }

        return nil
    }

    private static func urlError(from error: Error) -> URLError? {
        if let urlError = error as? URLError {
            return urlError
        }

        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return nil }
        let code = URLError.Code(rawValue: nsError.code)
        return URLError(code)
    }

    private static func normalizedDescription(for error: Error) -> String {
        [
            error.localizedDescription,
            String(describing: error),
            String(reflecting: error),
        ]
        .joined(separator: " ")
        .lowercased()
    }

    private static let offlineMarkers = [
        "not connected to internet",
        "internet connection appears to be offline",
        "data not allowed",
        "offline",
    ]

    private static let timeoutMarkers = [
        "timed out",
        "timeout",
        "gateway timeout",
    ]

    private static let unavailableMarkers = [
        "cannot connect to host",
        "cannot find host",
        "connection refused",
        "connection reset",
        "connection lost",
        "dns lookup failed",
        "failed to lookup address information",
        "network connection was lost",
        "no route to host",
        "service unavailable",
        "temporary failure in name resolution",
        "esploraerror",
        "httpresponse",
        "statuscode",
        "minreq",
    ]
}
