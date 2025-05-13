//
//  ZapScreenApp.swift
//  ZapScreen
//
//  Created by tongteknai on 18/4/25.
//

import SwiftUI
import FamilyControls

@main
struct ZapScreenApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let center = AuthorizationCenter.shared
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    do {
                        try await center.requestAuthorization(for: .child)
                        print("✅ FamilyControls permission granted.")
                    } catch {
                        print("Failed to get authorization: \(error)")
                    }
                    print(AuthorizationCenter.shared.authorizationStatus)
                }
                .onOpenURL { url in
                    if url.scheme == "zapscreen" {
                        if url.host() == "selection" {
                            appState.showSelectionView = true
                        }
                    }
                }
        }
    }
}

class AppState: ObservableObject {
    @Published var showSelectionView = false
}
