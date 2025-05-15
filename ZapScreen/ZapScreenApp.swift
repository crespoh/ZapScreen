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
    
    func handleRoleSelection(_ role: UserRole) {
        appState.selectedRole = role
        if role == .child || role == .myself {
            Task {
                do {
                    try await center.requestAuthorization(for: role == .child ? .child : .individual)
                    print("✅ FamilyControls permission granted.")
                    appState.isAuthorized = true
                } catch {
                    print("Failed to get authorization: \(error)")
                    appState.isAuthorized = false
                }
            }
        } else {
            appState.isAuthorized = true // Parent skips authorization
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.selectedRole == nil {
                    SelectionView { (role: UserRole) in
                        handleRoleSelection(role)
                    }
                } else if appState.isAuthorized {
                    RootView()
                        .environmentObject(appState)
                } else {
                    VStack {
                        ProgressView()
                        Text("Authorizing...")
                    }
                }
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
    @Published var selectedRole: UserRole? = nil
    @Published var isAuthorized: Bool = false
}
