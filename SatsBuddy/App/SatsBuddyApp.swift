//
//  SatsBuddyApp.swift
//  SatsBuddy
//
//  Created by Matthew Ramsden on 8/6/25.
//

import SwiftUI

@main
struct SatsBuddyApp: App {
    private let viewModel: SatsCardViewModel

    init() {
        let bdkClient = BdkClient.live
        self.viewModel = SatsCardViewModel(ckTapService: .live(bdk: bdkClient))

        Task.detached(priority: .utility) {
            await bdkClient.warmUp()
        }
    }

    var body: some Scene {
        WindowGroup {
            SatsCardListView(viewModel: viewModel)
        }
    }
}
