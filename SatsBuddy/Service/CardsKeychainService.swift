//
//  CardsKeychainService.swift
//  SatsBuddy
//
//  Created by Codex CLI on 9/9/25.
//

import Foundation
import KeychainAccess

private struct CardsKeychainService {
    private let keychain: Keychain
    private let storageKey = "StoredCards"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        let serviceName = "com.matthewramsden.satsbuddy.cards"
        let keychain = Keychain(service: serviceName)
            .label(bundleName ?? "SatsBuddy")
            .synchronizable(false)
            .accessibility(.whenUnlocked)
        self.keychain = keychain
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadCards() throws -> [SatsCardInfo] {
        guard let data = try keychain.getData(storageKey) else {
            return []
        }
        return try decoder.decode([SatsCardInfo].self, from: data)
    }

    func saveCards(_ cards: [SatsCardInfo]) throws {
        let data = try encoder.encode(cards)
        keychain[data: storageKey] = data
    }

    func deleteCards() throws {
        try keychain.remove(storageKey)
    }
}

struct CardsKeychainClient {
    let loadCards: () throws -> [SatsCardInfo]
    let saveCards: ([SatsCardInfo]) throws -> Void
    let deleteCards: () throws -> Void

    private init(
        loadCards: @escaping () throws -> [SatsCardInfo],
        saveCards: @escaping ([SatsCardInfo]) throws -> Void,
        deleteCards: @escaping () throws -> Void
    ) {
        self.loadCards = loadCards
        self.saveCards = saveCards
        self.deleteCards = deleteCards
    }
}

extension CardsKeychainClient {
    static let live = Self(
        loadCards: { try CardsKeychainService().loadCards() },
        saveCards: { cards in try CardsKeychainService().saveCards(cards) },
        deleteCards: { try CardsKeychainService().deleteCards() }
    )
}

#if DEBUG
    extension CardsKeychainClient {
        static let mock = Self(
            loadCards: { [] },
            saveCards: { _ in },
            deleteCards: {}
        )
    }
#endif
