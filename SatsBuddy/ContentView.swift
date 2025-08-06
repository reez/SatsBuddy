//
//  ContentView.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 8/6/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "bitcoinsign")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, sats buddy!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
