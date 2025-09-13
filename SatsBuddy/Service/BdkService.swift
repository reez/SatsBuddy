//
//  BdkService.swift
//  SatsBuddy
//

import BitcoinDevKit
import Foundation

private struct BdkService {
    func deriveAddress(descriptor: String, network: Network) throws -> String {
        let deriver = AddressDeriver()
        return try deriver.deriveAddress(from: descriptor, network: network)
    }
}

struct BdkClient {
    let deriveAddress: (String, Network) throws -> String
    private init(deriveAddress: @escaping (String, Network) throws -> String) {
        self.deriveAddress = deriveAddress
    }
}

extension BdkClient {
    static let live = Self(deriveAddress: { descriptor, network in
        try BdkService().deriveAddress(descriptor: descriptor, network: network)
    })
}

#if DEBUG
    extension BdkClient {
        static let mock = Self(deriveAddress: { descriptor, _ in
            let seed = abs(descriptor.hashValue) % 3
            switch seed {
            case 0: return "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
            case 1: return "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"
            default: return "bc1qrp33g013ahg3pq0ny9kxwj42yl4xpr3xz4fzqc"
            }
        })
    }
#endif
