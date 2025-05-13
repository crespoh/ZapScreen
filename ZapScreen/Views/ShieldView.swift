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
    @Binding var isPresented: Bool
    @State private var showActivityPicker = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack {
            HStack {
                Button("Done") {
                    isPresented = false
                }
                .padding(.top)
                Spacer()
            }
            Button("Apply Shielding") {
                let apps = shieldManager.discouragedSelections.applicationTokens
                let cats = shieldManager.discouragedSelections.categoryTokens
                let webs = shieldManager.discouragedSelections.webDomainTokens
                let selectedGroups = [apps.count > 0, cats.count > 0, webs.count > 0].filter { $0 }.count
                if (apps.count > 1 || cats.count > 1 || webs.count > 1) || selectedGroups > 1 {
                    errorMessage = "Please select only one app, one category, or one website."
                } else if selectedGroups == 0 {
                    errorMessage = "Please select at least one app, category, or website."
                } else {
                    errorMessage = nil
                    shieldManager.shieldActivities()
                }
            }
            .buttonStyle(.bordered)
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.top, 12)
            }
            Button {
                showActivityPicker = true
            } label: {
                Label("Choose Activities", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
        }
        .familyActivityPicker(isPresented: $showActivityPicker, selection: $shieldManager.discouragedSelections)
        .onChange(of: shieldManager.discouragedSelections) { newSelection in
            let apps = newSelection.applicationTokens
            let cats = newSelection.categoryTokens
            let webs = newSelection.webDomainTokens
            let selectedGroups = [apps.count > 0, cats.count > 0, webs.count > 0].filter { $0 }.count
            if (apps.count > 1 || cats.count > 1 || webs.count > 1) || selectedGroups > 1 {
                errorMessage = "Please select only one app, one category, or one website."
            } else if selectedGroups == 0 {
                errorMessage = "Please select at least one app, category, or website."
            } else {
                errorMessage = nil
            }
        }
    }
}
