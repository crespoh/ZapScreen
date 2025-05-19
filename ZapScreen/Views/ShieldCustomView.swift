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
import Combine


class AppSelectionModel: ObservableObject {
    @Published var activitySelection = FamilyActivitySelection()
    private var cancellables = Set<AnyCancellable>()
    static let shared = AppSelectionModel()
    
    init() {
        activitySelection = savedSelection() ?? FamilyActivitySelection()
          
        $activitySelection.sink { selection in
              self.saveSelection(selection: selection)
        }
        .store(in: &cancellables)
    }
    
    func saveSelection(selection: FamilyActivitySelection) {
    
        let defaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        
        guard let encoded = try? JSONEncoder().encode(selection) else { return }
        defaults?.set(encoded, forKey: "FamilyActivitySelection")
    }
    
    func savedSelection() -> FamilyActivitySelection? {
        
        let defaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        
        guard let data = defaults?.data(forKey: "FamilyActivitySelection") else { return nil }
        guard let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return nil }
        return decoded
        
    }
}

struct ShieldCustomView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appIconStore: AppIconStore
    @State var selection = FamilyActivitySelection()
    @StateObject private var shieldManager = ShieldManager.shared
    @State private var errorMessage: String? = nil
    @State private var showNamePrompt = false
    @State private var enteredAppName: String = ""
    @StateObject var model = AppSelectionModel.shared
    private var cancellables = Set<AnyCancellable>()

//    struct AppTokenName: Codable {
//        let tokenData: Data
//        let name: String
//    }

    private let tokenNameListKey = "ZapAppTokenNameList"

    // Helper to get the selected app token as a unique base64 string (if any)
    private func tokenKey(_ token: (NSSecureCoding & NSObjectProtocol)?) -> String? {
        guard let token = token else { return nil }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            return data.base64EncodedString()
        } catch {
            print("Failed to encode token: \(error)")
            return nil
        }
    }

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
                        let applicationProfile = ApplicationProfile(applicationToken: token!, applicationName: enteredAppName, applicationBundleId: app?.bundleIdentifier ?? "", applicationLocalizedAppName: app?.localizedDisplayName ?? "")
                        let dataBase = DataBase()
                        dataBase.addApplicationProfile(applicationProfile)
                        
                        print("[ShieldCustomView] Save App Token Successfully")
                        showNamePrompt = false
                        enteredAppName = ""
                        // Now do the original save logic
                        shieldManager.discouragedSelections.applicationTokens = selection.applicationTokens
                        shieldManager.discouragedSelections.categoryTokens = selection.categoryTokens
                        shieldManager.discouragedSelections.webDomainTokens = selection.webDomainTokens
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
