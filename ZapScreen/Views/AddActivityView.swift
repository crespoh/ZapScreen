import SwiftUI
import FamilyControls
import ManagedSettings

struct AddActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appIconStore: AppIconStore
    @StateObject private var shieldManager = ShieldManager.shared
    @State private var selection = FamilyActivitySelection()
    @State private var errorMessage: String? = nil
    @State private var showNamePrompt = false
    @State private var enteredAppName: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    Spacer()
                    Button("Add") {
                        if selection.applicationTokens.count == 1 {
                            showNamePrompt = true
                        }
                    }
                    .disabled(selection.applicationTokens.count != 1)
                }
                .padding()
                
                // App selection picker
                FamilyActivityPicker(selection: $selection)
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Add Activity")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selection) { newSelection in
                validateSelection(newSelection)
            }
            .sheet(isPresented: $showNamePrompt) {
                AppNamePromptView(
                    selection: selection,
                    enteredAppName: $enteredAppName,
                    onSave: { appName in
                        addAppToShield(appName: appName)
                    }
                )
            }
        }
    }
    
    private func validateSelection(_ selection: FamilyActivitySelection) {
        let apps = selection.applicationTokens
        let cats = selection.categoryTokens
        let webs = selection.webDomainTokens
        
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
    
    private func addAppToShield(appName: String) {
        guard let token = selection.applicationTokens.first else { return }
        
        print("[AddActivityView] Adding app to shield: \(appName)")
        
        // Create and save application profile
        let applicationProfile = ApplicationProfile(
            applicationToken: token,
            applicationName: appName
        )
        let dataBase = DataBase()
        dataBase.addApplicationProfile(applicationProfile)
        
        // Add to ShieldManager
        shieldManager.addApplicationToShield(token)
        
        // Reset and dismiss
        selection = FamilyActivitySelection()
        dismiss()
    }
}

#Preview {
    AddActivityView()
}
