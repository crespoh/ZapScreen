import SwiftUI

import FamilyControls

import ManagedSettings

struct ConfigureActivitiesView: View {
    @StateObject private var shieldManager = ShieldManager.shared
    @EnvironmentObject var appIconStore: AppIconStore
    private let store = ManagedSettingsStore()
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
                
                NavigationLink(destination: AppStatusView()) {
                    Text("View App Status")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Shield Status")
                        .font(.headline)
                        .padding(.top)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Shielded Apps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(shieldManager.getShieldedApplications().count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Unshielded Apps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(shieldManager.getUnshieldedApplications().count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.top)
                
                Spacer()
            }
            .navigationTitle("Shield")
        }
    }
}

#Preview {
    ConfigureActivitiesView()
}
