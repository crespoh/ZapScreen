//
//  ShieldCustomView.swift
//  ZapScreen
//
//  Created by tongteknai on 13/5/25.
//
import SwiftUI
import FamilyControls

struct ShieldCustomView: View {
    @State var selection = FamilyActivitySelection()
    @StateObject private var shieldManager = ShieldManager.shared
    @State private var errorMessage: String? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack {
            HStack {
                Button("Cancel") {
                    onDismiss?()
                }
                Spacer()
                Button("Save") {
                    // Add save logic here if needed
                    shieldManager.discouragedSelections.applicationTokens = selection.applicationTokens
                    shieldManager.discouragedSelections.categoryTokens = selection.categoryTokens
                    shieldManager.discouragedSelections.webDomainTokens = selection.webDomainTokens
                    shieldManager.shieldActivities()
                    onDismiss?()
                }
            }
            .padding()

            FamilyActivityPicker(selection: $selection)
            
            Text(errorMessage ?? "")
            Spacer()
        }
        .onChange(of: selection) { newSelection in
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
