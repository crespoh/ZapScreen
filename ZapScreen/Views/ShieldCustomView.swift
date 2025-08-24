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
    @State private var showAppConfirmation = false
    @State private var isViewActive = false
    
    var body: some View {
        Group {
            if passcodeManager.isPasscodeEnabled && passcodeManager.isLocked && !isViewActive {
                // Show passcode prompt if device is locked AND view is not active
                VStack {
                    PasscodePromptView()
                }
                .navigationTitle("Add Activity")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                // Show simplified shield management UI
                VStack(spacing: 0) {
                    // Header with navigation
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Text("Select App")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Next") {
                            if errorMessage == nil {
                                showAppConfirmation = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selection.applicationTokens.isEmpty || errorMessage != nil)
                    }
                    .padding()
                    
                    // App Selection Picker
                    VStack(spacing: 16) {
                        FamilyActivityPicker(selection: $selection)
                            .frame(maxHeight: 500)
                        
                        // Error message display
                        if let error = errorMessage, !error.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.1))
                            )
                            .padding(.horizontal)
                        }
                        
                        // Instructions
                        VStack(spacing: 8) {
                            Text("Instructions")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• Select one app from the list above")
                                Text("• Tap 'Next' to confirm your selection")
                                Text("• Enter the app name to complete setup")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
                .navigationBarBackButtonHidden(true)
                .sheet(isPresented: $showAppConfirmation) {
                    AppConfirmationView(
                        selectedToken: selection,
                        onSave: { appName in
                            let token = selection.applicationTokens.first
                            let applicationProfile = ApplicationProfile(applicationToken: token!, applicationName: appName)
                            
                            // Use the ShieldManager to add app to shield
                            shieldManager.addApplicationToShield(applicationProfile)
                            
                            // Apply shield immediately
                            shieldManager.shieldActivities()
                            
                            print("[ShieldCustomView] App saved successfully: \(appName)")
                            
                            // Clear the picker selection for next use
                            selection = FamilyActivitySelection()
                            
                            dismiss()
                        }
                    )
                }
                .onAppear {
                    // Mark view as active to prevent passcode prompt
                    isViewActive = true
                    
                    // Debug: Print current passcode state
                    print("[ShieldCustomView] Passcode enabled: \(passcodeManager.isPasscodeEnabled)")
                    print("[ShieldCustomView] Device locked: \(passcodeManager.isLocked)")
                    print("[ShieldCustomView] View active: \(isViewActive)")
                }
                .onDisappear {
                    // Mark view as inactive when leaving
                    isViewActive = false
                    print("[ShieldCustomView] View inactive: \(isViewActive)")
                }
                .onChange(of: selection) { _, newSelection in
                    validateSelection(newSelection)
                }
            }
        }
    }
    
    private func validateSelection(_ newSelection: FamilyActivitySelection) {
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
}
