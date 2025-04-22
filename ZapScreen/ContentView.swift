import SwiftUI
import FamilyControls
import ManagedSettings

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack {
            // Your existing content
        }
        .sheet(isPresented: $appState.showSelectionView) {
            SelectionView()
        }
    }
} 