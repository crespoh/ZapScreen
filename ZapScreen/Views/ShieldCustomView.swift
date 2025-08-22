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
    @StateObject private var passcodeManager = PasscodeManager.shared
    @State private var errorMessage: String? = nil
    @State private var showNamePrompt = false
    @State private var enteredAppName: String = ""
    @State private var selectedAppIcon: UIImage? = nil
    
    // Function to dismiss keyboard
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var body: some View {
        Group {
            if passcodeManager.isPasscodeEnabled && passcodeManager.isLocked {
                // Show passcode prompt if device is locked
                PasscodePromptView()
            } else {
                // Show normal shield management UI
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
                        .disabled(selection.applicationTokens.isEmpty || errorMessage != nil)
                    }
                    .padding()

                    FamilyActivityPicker(selection: $selection)
                    
                    Text(errorMessage ?? "")
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear() {
        }
        .onChange(of: selection) { _, newSelection in
            
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
                // Check if the selected app is already shielded
                if let selectedToken = apps.first {
                    // Check if this ApplicationToken is already in the shielded list
                    let isAlreadyShielded = shieldManager.shieldedApplications.contains { shieldedApp in
                        shieldedApp.applicationToken.hashValue == selectedToken.hashValue
                    }
                    
                    if isAlreadyShielded {
                        errorMessage = "This app is already shielded."
                    } else {
                        errorMessage = nil
                    }
                } else {
                    errorMessage = nil
                }
            }
        
        }
        // Enhanced Name Entry Sheet
        .sheet(isPresented: $showNamePrompt) {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with better guidance
                    VStack(spacing: 8) {
                        Text("Confirm App Selection")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    // Display the selected ApplicationToken for comparison
                    if let selectedToken = selection.applicationTokens.first {
                        VStack(spacing: 12) {
                            // Large app icon display
                            VStack(spacing: 16) {
                                // Large app icon - try different sizing approach
                                Label(selectedToken)
                                    .labelStyle(.iconOnly)
                                    .scaleEffect(3.0) // Scale the icon to 3x size
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Error message display
                    if let error = errorMessage, !error.isEmpty {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                    }
                    
                    // App name input with enhanced styling
                    VStack(alignment: .leading, spacing: 8) {
//                        Text("App Name")
//                            .font(.headline)
//                            .foregroundColor(.primary)
                        
                        TextField("Start typing app name...", text: $enteredAppName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                            .disableAutocorrection(false)
                            .onChange(of: enteredAppName) { _, newValue in
                                // Clear selected icon when user types
                                selectedAppIcon = nil
                            }
                    }
                    .padding(.horizontal)
                    
                    // Enhanced app suggestions - Always show when typing
                    if enteredAppName.count >= 2 {
                        let systemRegion = Locale.current.region?.identifier ?? "US"
                        let filteredApps = appIconStore.apps.filter { app in
                            (app.region == nil || app.region?.isEmpty == true || app.region?.lowercased() == systemRegion.lowercased()) &&
                            app.app_name.lowercased().contains(enteredAppName.lowercased())
                        }
                        
                        if !filteredApps.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
//                                Text("Suggestions")
//                                    .font(.headline)
//                                    .foregroundColor(.primary)
                                
                                LazyVStack(spacing: 8) {
                                    ForEach(filteredApps.prefix(8), id: \.id) { app in
                                        Button(action: {
                                            enteredAppName = app.app_name
                                            selectedAppIcon = app.image
                                            dismissKeyboard() // Dismiss keyboard
                                        }) {
                                            HStack {
                                                if let image = app.image {
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .frame(width: 32, height: 32)
                                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 32, height: 32)
                                                }
                                                
                                                Text(app.app_name)
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                                
                                                if enteredAppName == app.app_name {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(enteredAppName == app.app_name ? Color.blue.opacity(0.1) : Color.clear)
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Visual confirmation of selected app
                    if let icon = selectedAppIcon {
                        VStack(spacing: 8) {
                            Text("Selected App")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(uiImage: icon)
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                VStack(alignment: .leading) {
                                    Text(enteredAppName)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text("Ready to shield")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.1))
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Action buttons
                    HStack {
                        Button("Cancel") {
                            showNamePrompt = false
                            enteredAppName = ""
                            selectedAppIcon = nil
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Save") {
                            let token = selection.applicationTokens.first
                            let applicationProfile = ApplicationProfile(applicationToken: token!, applicationName: enteredAppName)
                            
                            // Use the new ShieldManager method to add app to shield
                            shieldManager.addApplicationToShield(applicationProfile)
                            
                            // Apply shield immediately
                            shieldManager.shieldActivities()
                            
                            print("[ShieldCustomView] Save App Token Successfully")
                            showNamePrompt = false
                            enteredAppName = ""
                            selectedAppIcon = nil
                            
                            // Clear the picker selection for next use
                            selection = FamilyActivitySelection()
                            
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(enteredAppName.isEmpty || selectedAppIcon == nil)
                    }
                    .padding()
                }
                .padding()
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }
    
}
