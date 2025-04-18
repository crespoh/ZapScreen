import SwiftUI
import FamilyControls

struct ParentView: View {
    @StateObject private var settings = AppSettings()
    @State private var showingAppPicker = false
    @State private var showingEarningAppPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("App Restrictions")) {
                    Button("Select Apps to Restrict") {
                        showingAppPicker = true
                    }
                    .familyActivityPicker(isPresented: $showingAppPicker,
                                        selection: $settings.selectedApps)
                }
                
                Section(header: Text("Earning Apps")) {
                    Button("Select Apps for Earning Time") {
                        showingEarningAppPicker = true
                    }
                    .familyActivityPicker(isPresented: $showingEarningAppPicker,
                                        selection: $settings.earningApps)
                    
                    ForEach(Array(arrayLiteral: settings.earningApps.applicationTokens), id: \.self) { token in
                        HStack {
                            Text(token.description)
                            Spacer()
                            TextField("Minutes per usage", value: $settings.earningRates[token.description], format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                Section(header: Text("Shield Options")) {
                    ForEach(settings.shieldOptions, id: \.self) { option in
                        Text("\(Int(option / 60)) minutes")
                    }
                    
                    Button("Add New Option") {
                        // Add new shield option
                    }
                }
                
                Section(header: Text("Time Requests")) {
                    // List of pending time requests from children
                    ForEach(0..<3) { _ in
                        HStack {
                            Text("YouTube - 30 minutes")
                            Spacer()
                            Button("Approve") {
                                // Handle approval
                            }
                            Button("Decline") {
                                // Handle decline
                            }
                        }
                    }
                }
            }
            .navigationTitle("Parent Controls")
            .onChange(of: settings.selectedApps) { _ in
                settings.setAppRestrictions()
            }
            .onChange(of: settings.earningApps) { _ in
                settings.setEarningApps()
            }
        }
    }
} 