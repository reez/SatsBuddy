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
            Text("SATSCARD • Made in ") + Text("Canada").foregroundColor(.red) + Text(" • Version \(updatedCard.version)".uppercased())
            Text("SATSBUDDY • Made in ") + Text("Nashville").foregroundColor(.blue) + Text(" • Version 0".uppercased())
        }
        .foregroundStyle(.secondary)
        .fontDesign(.monospaced)
        .font(.caption)
    }
}

#Preview {
    FooterView(updatedCard: .init(version: "1.0.3"))
}
