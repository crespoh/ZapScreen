import SwiftUI
import FamilyControls
import ManagedSettings

struct ChildView: View {
    @StateObject private var settings = AppSettings()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Earning Apps")) {
                    if let child = settings.getCurrentChild() {
                        ForEach(Array(child.earningApps.applicationTokens), id: \.self) { token in
                            let app = Application(token: token)
                            let rate = settings.getEarningRate(for: app.bundleIdentifier!)
                            HStack {
                                Text(app.localizedDisplayName ?? String(describing: token))
                                Spacer()
                                Text("\(Int(rate)) minutes per usage")
                            }
                        }
                    }
                }
                
                Section(header: Text("Time Requests")) {
                    Button("Request More Time") {
                        // Implement time request functionality
                    }
                }
            }
            .navigationTitle("Child View")
        }
    }
} 
