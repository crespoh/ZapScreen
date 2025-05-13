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


    var body: some View {
        VStack {
            Image(systemName: "eye")
                .font(.system(size: 76.0))
                .padding()


            FamilyActivityPicker(selection: $selection)

//            Image(systemName: "hourglass")
//                .font(.system(size: 76.0))
//                .padding()
            Text(errorMessage ?? "")
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
//                shieldManager.discouragedSelections.applicationTokens = newSelection.applicationTokens
//                shieldManager.discouragedSelections.categoryTokens = newSelection.categoryTokens
//                shieldManager.discouragedSelections.webDomainTokens = newSelection.webDomainTokens
//                shieldManager.shieldActivities()
            }
        }
    }
}
