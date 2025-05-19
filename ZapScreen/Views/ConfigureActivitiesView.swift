import SwiftUI

import FamilyControls

import ManagedSettings

struct ConfigureActivitiesView: View {
    @StateObject private var shieldManager = ShieldManager.shared
    @EnvironmentObject var appIconStore: AppIconStore
    private let store = ManagedSettingsStore()
//    private var applications: Application
    private let db = DataBase()
    @StateObject var model = AppSelectionModel.shared
    
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink(destination: ShieldCustomView()) {
                    Text("Configure Activities")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Locked Apps")
                        .font(.headline)
                    if model.activitySelection.applications.isEmpty {
                        Text("No apps are currently locked.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(model.activitySelection.applicationTokens), id: \.self) { token in
                            Label(token).labelStyle(.titleAndIcon)
                        }
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Shield")
        }
    }
    
}

//#Preview {
//    ConfigureActivitiesView()
//}
