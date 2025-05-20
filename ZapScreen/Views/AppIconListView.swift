//
//  AppIconListView.swift
//  ZapScreen
//
//  Created by tongteknai on 18/5/25.
//

import Foundation
import SwiftUI
import ManagedSettings
import ManagedSettingsUI

struct AppIconListView: View {
    @EnvironmentObject var appIconStore: AppIconStore

    var body: some View {
        NavigationView {
            List {
                ForEach(appIconStore.apps, id: \.id) { app in
                    HStack {
                        if let uiImage = app.image {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 40, height: 40)
                                .cornerRadius(8)
                        } else {
                            Color.gray
                                .frame(width: 40, height: 40)
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.app_name)
                                .font(.headline)
                            Text(app.bundle_id ?? "No Bundle ID")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}
