import SwiftUI
import FamilyControls
import Foundation

struct AppNamePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appIconStore: AppIconStore
    let selection: FamilyActivitySelection
    @Binding var enteredAppName: String
    let onSave: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter the name of the selected app")
                .font(.headline)
            
            TextField("App Name", text: $enteredAppName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            // App suggestions based on entered text
            if enteredAppName.count >= 2 {
                AppSuggestionsList(
                    searchText: enteredAppName,
                    onAppSelected: { appName in
                        enteredAppName = appName
                    }
                )
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    onSave(enteredAppName)
                    dismiss()
                }
                .disabled(enteredAppName.isEmpty)
            }
            .padding()
        }
        .padding()
    }
}

struct AppSuggestionsList: View {
    @EnvironmentObject var appIconStore: AppIconStore
    let searchText: String
    let onAppSelected: (String) -> Void
    
    var filteredApps: [AppIconData] {
        let systemRegion = Locale.current.regionCode ?? "US"
        return appIconStore.apps.filter { app in
            (app.region == nil || app.region?.isEmpty == true || app.region?.lowercased() == systemRegion.lowercased()) &&
            app.app_name.lowercased().contains(searchText.lowercased())
        }
        .prefix(10) // Limit to 10 suggestions
        .map { $0 }
    }
    
    var body: some View {
        if !filteredApps.isEmpty {
            List(filteredApps, id: \.id) { app in
                Button(action: {
                    onAppSelected(app.app_name)
                }) {
                    HStack {
                        if let image = app.image {
                            Image(uiImage: image)
                                .resizable()
                                .frame(width: 24, height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        Text(app.app_name)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }
}

#Preview {
    AppNamePromptView(
        selection: FamilyActivitySelection(),
        enteredAppName: .constant(""),
        onSave: { _ in }
    )
}
