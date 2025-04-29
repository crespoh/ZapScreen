import SwiftUI

struct UserDefaultsView: View {
    @State private var lastBlockedAppName: String = ""
    @State private var lastBlockedAppToken: String = ""
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Last Blocked App Details")
                .font(.title)
                .padding()
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("App Name:")
                    .font(.headline)
                Text(lastBlockedAppName)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                Text("App Token:")
                    .font(.headline)
                Text(lastBlockedAppToken)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding()
            
            Button("Refresh Values") {
                refreshValues()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .onAppear {
            refreshValues()
        }
    }
    
    private func refreshValues() {
        let (name, token) = UserDefaultsManager.shared.getLastBlockedApp()
        lastBlockedAppName = name ?? "No app name found"
        lastBlockedAppToken = token ?? "No app token found"
        errorMessage = nil
    }
}

#Preview {
    UserDefaultsView()
} 