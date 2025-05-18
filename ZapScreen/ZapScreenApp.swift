//
//  ZapScreenApp.swift
//  ZapScreen
//
//  Created by tongteknai on 18/4/25.
//

import SwiftUI
import SwiftData
import FamilyControls

@main
struct ZapScreenApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appIconStore = AppIconStore()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appIconStore)
        }
    }
        
}
