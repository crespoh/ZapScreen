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
                        Task {
                            await determineDeviceType()
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
    
    private func determineDeviceType() async {
        do {
            // Try to request authorization for child mode
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            // If successful, this is a child device
            await MainActor.run {
                settings.isParentMode = false
            }
        } catch {
            // If authorization fails, show mode selection
            await MainActor.run {
                showingModeSelection = true
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