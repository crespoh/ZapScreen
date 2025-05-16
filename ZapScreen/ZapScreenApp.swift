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
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
