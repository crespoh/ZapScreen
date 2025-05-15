//
//  ShieldCustomView.swift
//  ZapScreen
//
//  Created by tongteknai on 13/5/25.
//
import SwiftUI
import FamilyControls
import DeviceActivity

struct ShieldCustomView: View {
    @State var selection = FamilyActivitySelection()
    @StateObject private var shieldManager = ShieldManager.shared
    @State private var errorMessage: String? = nil
    @State private var showNamePrompt = false
    @State private var enteredAppName: String = ""
    var onDismiss: (() -> Void)? = nil

    struct AppTokenName: Codable {
        let tokenData: Data
        let name: String
    }

    private let tokenNameListKey = "AppTokenNameList"

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
    private var selectedAppTokenKey: String? {
        tokenKey(selection.applicationTokens.first as? (NSSecureCoding & NSObjectProtocol))
    }

    var body: some View {
        let saveDisabled = selection.applicationTokens.count != 1 || selection.categoryTokens.count > 0 || selection.webDomainTokens.count > 0 || errorMessage != nil
        VStack {
            HStack {
                Button("Cancel") {
                    onDismiss?()
                }
                Spacer()
                Button("Save") {
                    // Instead of saving immediately, show the name prompt
                    showNamePrompt = true
                }
                .disabled(saveDisabled)
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
                        let userDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") ?? .standard
                        if let token = selection.applicationTokens.first, !enteredAppName.isEmpty {
                            let userDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") ?? .standard
                            let tokenKey: String
                            if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
                                tokenKey = data.base64EncodedString()
                                print("[ZapScreen] Used archivedData for tokenKey")
                            } else {
                                tokenKey = String(describing: token)
                                print("[ZapScreen] Used String(describing:) for tokenKey: \(tokenKey)")
                            }
                            var mapping = userDefaults.dictionary(forKey: tokenNameListKey) as? [String: String] ?? [:]
                            mapping[tokenKey] = enteredAppName
                            userDefaults.set(mapping, forKey: tokenNameListKey)
                            let successMsg = "[ZapScreen] Saved app name '\(enteredAppName)' for tokenKey \(tokenKey)"
                            print(successMsg)
                            errorMessage = nil
                        } else if selection.applicationTokens.first == nil {
                            let errMsg = "No application token selected; cannot save app name."
                            print("[ZapScreen] \(errMsg)")
                            errorMessage = errMsg
                        } else {
                            let errMsg = "App name is empty; cannot save."
                            print("[ZapScreen] \(errMsg)")
                            errorMessage = errMsg
                        }
                        showNamePrompt = false
                        enteredAppName = ""
                        // Now do the original save logic
                        shieldManager.discouragedSelections.applicationTokens = selection.applicationTokens
                        shieldManager.discouragedSelections.categoryTokens = selection.categoryTokens
                        shieldManager.discouragedSelections.webDomainTokens = selection.webDomainTokens
                        shieldManager.shieldActivities()
                        onDismiss?()
                    }
                    .disabled(enteredAppName.isEmpty)
                }
                .padding()
            }
            .padding()
        }
    }
}
