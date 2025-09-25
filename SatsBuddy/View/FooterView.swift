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
        VStack(spacing: 12) {
            Text("SATSCARD • Made in Canada • Version \(updatedCard.version)")
            Text("SATSBUDDY • Made in Nashville • Version 0")
        }
        .foregroundStyle(.secondary)
        .fontDesign(.monospaced)
        .font(.caption)
    }
}

#Preview {
    FooterView(updatedCard: .init(version: "1.0.3"))
}
