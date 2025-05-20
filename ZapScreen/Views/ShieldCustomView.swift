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
        let saveDisabled = false
        VStack {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    // Instead of saving immediately, show the name prompt
                    showNamePrompt = true
                }
                .disabled(saveDisabled)
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
                        let dataBase = DataBase()
                        dataBase.addApplicationProfile(applicationProfile)
                        
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
