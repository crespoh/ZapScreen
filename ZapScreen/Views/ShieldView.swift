//
//  ShieldView.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import SwiftUI
import FamilyControls

struct ShieldView: View {
    
    @StateObject private var shieldManager = ShieldManager.shared
    @State private var showActivityPicker = false
    
    var body: some View {
        VStack {
            Button {
                showActivityPicker = true
            } label: {
                Label("Configure activities", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
            Button("Apply Shielding") {
                print("Apply Shielding")
                shieldManager.shieldActivities()
            }
            .buttonStyle(.bordered)
        }
        .familyActivityPicker(isPresented: $showActivityPicker, selection: $shieldManager.discouragedSelections)
    }
}
