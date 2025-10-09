//
//  FooterView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 9/25/25.
//

import SwiftUI

struct FooterView: View {
    let updatedCard: SatsCardInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SATSCARD • Version \(updatedCard.version) • Made in ".uppercased())
                + Text("Canada".uppercased()).foregroundColor(.red)
            Text("SATSBUDDY • Version 0 • Made in ".uppercased())
                + Text("Nashville".uppercased()).foregroundColor(.blue)
        }
        .foregroundStyle(.secondary)
        .fontDesign(.monospaced)
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    FooterView(
        updatedCard: .init(
            version: "1.0.3",
            pubkey: "02e493dbf1c10d80f3581e4904930b1404cc6c13900ee0758474fa94abe8c4cd1351"
        )
    )
}
