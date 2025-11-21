//
//  FeeService.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 11/21/25.
//

import Foundation

private struct FeeService {
    func fees() async throws -> RecommendedFees {
        guard let url = URL(string: "https://mempool.space/api/v1/fees/recommended") else {
            throw FeeServiceError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
            200...299 ~= httpResponse.statusCode
        else { throw FeeServiceError.invalidServerResponse }
        let jsonDecoder = JSONDecoder()
        let jsonObject = try jsonDecoder.decode(RecommendedFees.self, from: data)
        return jsonObject
    }
}

struct FeeClient {
    let fetchFees: () async throws -> RecommendedFees
    private init(fetchFees: @escaping () async throws -> RecommendedFees) {
        self.fetchFees = fetchFees
    }
}

extension FeeClient {
    static let live = Self(fetchFees: { try await FeeService().fees() })
}

enum FeeServiceError: Error {
    case invalidServerResponse
    case invalidURL
    case serialization
}

#if DEBUG
    extension FeeClient {
        static let mock = Self(fetchFees: { currentFeesMock })
    }
#endif
