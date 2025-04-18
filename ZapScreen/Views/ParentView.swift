import SwiftUI
import FamilyControls
import ManagedSettings

struct ParentView: View {
    @StateObject private var settings = AppSettings()
    @State private var showingAppPicker = false
    @State private var showingEarningAppPicker = false
    @State private var showingAddChild = false
    @State private var newChildName = ""
    @State private var newChildDeviceId = ""
    
    private func appRestrictionsBinding(for child: Child) -> Binding<FamilyActivitySelection> {
        Binding(
            get: { child.appRestrictions },
            set: { newValue in
                if let index = settings.children.firstIndex(where: { $0.id == child.id }) {
                    var updatedChild = child
                    updatedChild.appRestrictions = newValue
                    settings.children[index] = updatedChild
                }
            }
        )
    }
    
    private func earningAppsBinding(for child: Child) -> Binding<FamilyActivitySelection> {
        Binding(
            get: { child.earningApps },
            set: { newValue in
                if let index = settings.children.firstIndex(where: { $0.id == child.id }) {
                    var updatedChild = child
                    updatedChild.earningApps = newValue
                    settings.children[index] = updatedChild
                }
            }
        )
    }
    
    private func earningRateBinding(for child: Child, token: ApplicationToken) -> Binding<TimeInterval> {
        let appIdentifier = String(describing: token)
        return Binding(
            get: { child.earningRates[appIdentifier] ?? 0 },
            set: { newValue in
                if let index = settings.children.firstIndex(where: { $0.id == child.id }) {
                    var updatedChild = child
                    updatedChild.earningRates[appIdentifier] = newValue
                    settings.children[index] = updatedChild
                }
            }
        )
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Children")) {
                    Picker("Select Child", selection: $settings.selectedChildId) {
                        ForEach(settings.children) { child in
                            Text(child.name).tag(child.id as UUID?)
                        }
                    }
                    
                    Button("Add New Child") {
                        showingAddChild = true
                    }
                }
                
                if let child = settings.selectedChild {
                    Section(header: Text("App Restrictions")) {
                        Button("Select Apps to Restrict") {
                            showingAppPicker = true
                        }
                        .familyActivityPicker(isPresented: $showingAppPicker,
                                            selection: appRestrictionsBinding(for: child))
                    }
                    
                    Section(header: Text("Earning Apps")) {
                        Button("Select Apps for Earning Time") {
                            showingEarningAppPicker = true
                        }
                        .familyActivityPicker(isPresented: $showingEarningAppPicker,
                                            selection: earningAppsBinding(for: child))
                        
                        let tokens = child.earningApps.applicationTokens
                        ForEach(Array(tokens), id: \.self) { token in
                            HStack {
                                Text(String(describing: token))
                                Spacer()
                                TextField("Minutes per usage", 
                                         value: earningRateBinding(for: child, token: token),
                                         format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                    
                    Section(header: Text("Shield Options")) {
                        ForEach(child.shieldOptions, id: \.self) { option in
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
            }
            .navigationTitle("Parent Controls")
            .onChange(of: settings.selectedChild) { _, _ in
                settings.setAppRestrictions()
            }
            .sheet(isPresented: $showingAddChild) {
                NavigationView {
                    Form {
                        Section(header: Text("Child Information")) {
                            TextField("Child's Name", text: $newChildName)
                            TextField("Device Identifier", text: $newChildDeviceId)
                        }
                    }
                    .navigationTitle("Add Child")
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingAddChild = false
                        },
                        trailing: Button("Add") {
                            settings.addChild(name: newChildName, deviceIdentifier: newChildDeviceId)
                            newChildName = ""
                            newChildDeviceId = ""
                            showingAddChild = false
                        }
                    )
                }
            }
        }
    }
} 