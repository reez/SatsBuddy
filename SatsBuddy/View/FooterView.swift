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
            Text("SATSCARD • Version \(updatedCard.version) • Made in ".uppercased()) + Text("Canada".uppercased()).foregroundColor(.red)
            Text("SATSBUDDY • Version 0 • Made in ".uppercased()) + Text("Nashville".uppercased()).foregroundColor(.blue)
        }
        .foregroundStyle(.secondary)
        .fontDesign(.monospaced)
        .font(.caption)
    }
}

#Preview {
    FooterView(updatedCard: .init(version: "1.0.3"))
}
