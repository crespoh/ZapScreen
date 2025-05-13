import SwiftUI
import FamilyControls

struct ContentView: View {
    @State private var showingModeSelection = false
    @State private var isLoading = true
    @State private var isConfigSheetPresented = false
    
    var body: some View {
        TabView {
            VStack {
                Button("Configure activities") {
                    isConfigSheetPresented = true
                }
                .padding()
                .sheet(isPresented: $isConfigSheetPresented) {
                    ActivityConfigSheet(isPresented: $isConfigSheetPresented)
                }
//                ShieldView(isPresented: .constant(false)) // For display, but disables config
            }
            .tabItem {
                Label("Shield", systemImage: "shield")
            }
            
            DeviceListView()
                .tabItem {
                    Label("Devices", systemImage: "iphone")
                }
            
            UserDefaultsView()
                .tabItem {
                    Label("Debug", systemImage: "ladybug")
                }
        }
    }
}

