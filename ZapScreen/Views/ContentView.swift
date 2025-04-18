import SwiftUI
import FamilyControls

struct ContentView: View {
    @StateObject private var settings = AppSettings()
    @State private var showingModeSelection = false
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Detecting device type...")
                    .onAppear {
                        // Wait a moment for the device type detection to complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isLoading = false
                        }
                    }
            } else if showingModeSelection {
                ModeSelectionView(settings: settings, showingModeSelection: $showingModeSelection)
            } else {
                if settings.isParentMode {
                    ParentView()
                } else {
                    ChildView()
                }
            }
        }
    }
}

struct ModeSelectionView: View {
    @ObservedObject var settings: AppSettings
    @Binding var showingModeSelection: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to ZapScreen")
                .font(.largeTitle)
                .padding()
            
            Text("Select your mode:")
                .font(.headline)
            
            Button(action: {
                settings.isParentMode = true
                showingModeSelection = false
            }) {
                Text("Parent Mode")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                settings.isParentMode = false
                showingModeSelection = false
            }) {
                Text("Child Mode")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
} 