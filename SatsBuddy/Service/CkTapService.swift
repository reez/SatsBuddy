//
//  CkTapService.swift
//  SatsBuddy
//
//  A DI-friendly CKTap-facing service (live + mock).
//

import BitcoinDevKit
import CKTap
import Foundation

private struct CkTapService {
    let impl: CkTapCardService
    init(bdk: BdkClient, network: Network = .bitcoin) {
        self.impl = CkTapCardService(addressDeriver: bdk, network: network)
    }
    func readCardInfo(transport: CkTransport) async throws -> SatsCardInfo {
        try await impl.readCardInfo(transport: transport)
    }
}

struct CkTapClient {
    let readCardInfo: (CkTransport) async throws -> SatsCardInfo
    private init(readCardInfo: @escaping (CkTransport) async throws -> SatsCardInfo) {
        self.readCardInfo = readCardInfo
    }
}

extension CkTapClient {
    static func live(bdk: BdkClient) -> CkTapClient {
        let service = CkTapService(bdk: bdk, network: .bitcoin)
        return .init(readCardInfo: { transport in
            try await service.readCardInfo(transport: transport)
        })
    }

    static let mock: CkTapClient = {
        .init(readCardInfo: { _ in
            let sampleSlots: [SlotInfo] = [
                SlotInfo(
                    slotNumber: 0,
                    isActive: false,
                    isUsed: true,
                    pubkey: "02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f",
                    pubkeyDescriptor:
                        "wpkh(02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f)",
                    address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
                    balance: nil
                ),
                SlotInfo(
                    slotNumber: 1,
                    isActive: true,
                    isUsed: true,
                    pubkey: "03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c",
                    pubkeyDescriptor:
                        "wpkh(03389ffce9cd9ae88dcc0631e88a821ffdbe9bfe26018eb2b4ad5b5db35ca9a5c)",
                    address: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
                    balance: 100000
                ),
            ]
            return SatsCardInfo(
                version: "1.0.3",
                birth: 1,
                address: "bc1qrp33g013ahg3pq0ny9kxwj42yl4xpr3xz4fzqc",
                activeSlot: 1,
                totalSlots: 10,
                slots: sampleSlots,
                isActive: true
            )
        })
    }()
}
