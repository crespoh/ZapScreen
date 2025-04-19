import SwiftUI
import FamilyControls
import ManagedSettings

struct ParentView: View {
    @StateObject private var settings = AppSettings()
    @State private var selection = FamilyActivitySelection()
    @State private var showingPicker = false
    
    private var currentChild: Child? {
        settings.getCurrentChild()
    }
    
    private var childEarningApps: FamilyActivitySelection? {
        guard let child = currentChild else { return nil }
        var selection = FamilyActivitySelection()
        selection.applicationTokens = child.earningApps.applicationTokens
        selection.categoryTokens = child.earningApps.categoryTokens
        return selection
    }
    
    private var earningApps: [Application] {
        guard let apps = childEarningApps else { return [] }
        return Array(apps.applicationTokens).map { token in
            Application(token: token)
        }
    }
    
    private func earningRate(for app: Application) -> TimeInterval {
        let bundleId: String = app.bundleIdentifier ?? ""
        return settings.getEarningRate(for: bundleId)
    }
    
    private func appDisplayName(_ app: Application) -> String {
        app.localizedDisplayName ?? String(describing: app.token)
    }
    
    private func rateBinding(for app: Application) -> Binding<TimeInterval> {
        let bundleId: String = app.bundleIdentifier ?? ""
        return Binding(
            get: { settings.getEarningRate(for: bundleId) },
            set: { newValue in
                if let child = currentChild {
                    var updatedChild = child
                    updatedChild.earningRates[bundleId] = newValue
                    if let index = settings.children.firstIndex(where: { $0.id == child.id }) {
                        settings.children[index] = updatedChild
                    }
                }
            }
        )
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Earning Apps")) {
                    ForEach(earningApps, id: \.token) { app in
                        let rate = earningRate(for: app)
                        HStack {
                            Text(appDisplayName(app))
                            Spacer()
                            Text("\(Int(rate)) minutes per usage")
                        }
                    }
                    
                    Button("Select Earning Apps") {
                        showingPicker = true
                    }
                    .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
                }
                
                Section(header: Text("Earning Rates")) {
                    ForEach(earningApps, id: \.token) { app in
                        HStack {
                            Text(appDisplayName(app))
                            Spacer()
                            TextField("Minutes", value: rateBinding(for: app), formatter: NumberFormatter())
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .navigationTitle("Parent View")
            .onChange(of: selection) { oldValue, newValue in
                settings.setEarningApps(newValue)
            }
        }
    }
} 
