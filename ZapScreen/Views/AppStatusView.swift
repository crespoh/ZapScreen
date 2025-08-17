//
//  AppStatusView.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import SwiftUI
import ManagedSettings

struct AppStatusView: View {
    @StateObject private var viewModel = AppStatusViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading app status...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Shielded Applications Section
                        Section(header: Text("Shielded Applications").font(.headline)) {
                            if viewModel.shieldedApplications.isEmpty {
                                Text("No applications are currently shielded")
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else {
                                ForEach(viewModel.shieldedApplications, id: \.id) { app in
                                    HStack {
                                        Image(systemName: "lock.shield")
                                            .foregroundColor(.red)
                                        VStack(alignment: .leading) {
                                            Label(app.applicationToken).labelStyle(.titleAndIcon)
                                            // Text(app.applicationName)
                                            //     .font(.body)
                                            Text("Permanently blocked")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Button("Unlock") {
                                            // Temporarily unlock for 5 minutes
                                            viewModel.temporarilyUnlockApp(app, for: 5)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                    }
                                }
                                .onDelete { indexSet in
                                    for index in indexSet {
                                        viewModel.removeAppFromShield(viewModel.shieldedApplications[index])
                                    }
                                }
                            }
                        }
                        
                        // Unshielded Applications Section
                        Section(header: Text("Temporarily Unshielded").font(.headline)) {
                            if viewModel.unshieldedApplications.isEmpty {
                                Text("No applications are currently unshielded")
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else {
                                ForEach(viewModel.unshieldedApplications, id: \.id) { app in
                                    HStack {
                                        Image(systemName: "lock.open")
                                            .foregroundColor(.green)
                                        VStack(alignment: .leading) {
                                            Text(app.applicationName)
                                                .font(.body)
                                            Text("Unlocked for \(app.durationMinutes) minutes")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            if !app.isExpired {
                                                Text("Time remaining: \(app.formattedRemainingTime)")
                                                    .font(.caption2)
                                                    .foregroundColor(.orange)
                                            } else {
                                                Text("Expired - will be re-shielded")
                                                    .font(.caption2)
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        Spacer()
                                        if app.isExpired {
                                            Button("Re-shield") {
                                                viewModel.reapplyShieldToApp(app)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                    }
                                }
                                .onDelete { indexSet in
                                    for index in indexSet {
                                        let app = viewModel.unshieldedApplications[index]
                                        if app.isExpired {
                                            viewModel.reapplyShieldToApp(app)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Summary Section
                        Section(header: Text("Summary").font(.headline)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Total Shielded")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("\(viewModel.totalShieldedCount)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("Total Unshielded")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("\(viewModel.totalUnshieldedCount)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("App Status")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        viewModel.refreshAppStatus()
                    }
                }
            }
            .refreshable {
                viewModel.refreshAppStatus()
            }
        }
    }
}

#Preview {
    AppStatusView()
}
