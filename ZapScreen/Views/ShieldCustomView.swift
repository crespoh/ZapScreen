//
//  ShieldCustomView.swift
//  ZapScreen
//
//  Created by tongteknai on 13/5/25.
//
import UIKit
import SwiftUI
import SwiftData
import FamilyControls
import DeviceActivity
import ManagedSettings

struct ShieldCustomView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appIconStore: AppIconStore
    @State var selection = FamilyActivitySelection()
    @StateObject private var shieldManager = ShieldManager.shared
    @State private var errorMessage: String? = nil
    @State private var showNamePrompt = false
    @State private var enteredAppName: String = ""
    @StateObject var model = AppSelectionModel.shared

    var body: some View {
        VStack {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    // Only show the name prompt if the selection is valid (exactly one app, no other types).
                    // The errorMessage state is updated by the .onChange modifier.
                    // If errorMessage is nil, it means the selection is valid.
                    if errorMessage == nil {
                        showNamePrompt = true
                    }
                    // If errorMessage is not nil, the error is already displayed via Text(errorMessage ?? "")
                    // and this button action effectively does nothing, preventing the sheet from appearing.
                }
                .disabled(model.activitySelection.applicationTokens.isEmpty || errorMessage != nil)
            }
            .padding()

            FamilyActivityPicker(selection: $model.activitySelection)
            
            Text(errorMessage ?? "")
            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear() {
        }
        .onChange(of: model.activitySelection) { newSelection in
            
            let apps = newSelection.applicationTokens
            let cats = newSelection.categoryTokens
            let webs = newSelection.webDomainTokens

            if apps.count > 1 {
                errorMessage = "Please select only one app."
            } else if cats.count > 0 || webs.count > 0 {
                errorMessage = "Only app selection is allowed."
            } else if apps.count == 0 {
                errorMessage = "Please select one app."
            } else {
                errorMessage = nil
            }
        
        }
        // Name entry sheet
        .sheet(isPresented: $showNamePrompt) {
            VStack(spacing: 20) {
                Text("Enter the name of the selected app")
                    .font(.headline)
                if let error = errorMessage, !error.isEmpty {
                    Text(error)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                }
                TextField("App Name", text: $enteredAppName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                // Filtered app suggestion list
                if enteredAppName.count >= 2 {
                    let systemRegion = Locale.current.regionCode ?? "US"
                    let filteredApps = appIconStore.apps.filter { app in
                        (app.region == nil || app.region?.isEmpty == true || app.region?.lowercased() == systemRegion.lowercased()) &&
                        app.app_name.lowercased().contains(enteredAppName.lowercased())
                    }
                    if !filteredApps.isEmpty {
                        List(filteredApps, id: \ .id) { app in
                            Button(action: {
                                enteredAppName = app.app_name
                            }) {
                                HStack {
                                    if let image = app.image {
                                        Image(uiImage: image)
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    Text(app.app_name)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                HStack {
                    Button("Cancel") {
                        showNamePrompt = false
                        enteredAppName = ""
                    }
                    Spacer()
                    Button("Save") {
                        
                        let token = model.activitySelection.applicationTokens.first
                        let app = model.activitySelection.applications.first
                        let applicationProfile = ApplicationProfile(applicationToken: token!, applicationName: enteredAppName)
                        
                        // Use the new ShieldManager method to add app to shield
                        shieldManager.addApplicationToShield(applicationProfile)
                        
                        print("[ShieldCustomView] Save App Token Successfully")
                        showNamePrompt = false
                        enteredAppName = ""
                        // Now do the original save logic
                        shieldManager.discouragedSelections.applicationTokens = model.activitySelection.applicationTokens
                        shieldManager.discouragedSelections.categoryTokens = model.activitySelection.categoryTokens
                        shieldManager.discouragedSelections.webDomainTokens = model.activitySelection.webDomainTokens
                        shieldManager.shieldActivities()
                        dismiss()
                    }
                    .disabled(enteredAppName.isEmpty)
                }
                .padding()
            }
            .padding()
        }
    }
    
}
