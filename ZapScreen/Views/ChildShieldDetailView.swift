//
//  ChildShieldDetailView.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import SwiftUI

struct ChildShieldDetailView: View {
    let child: ChildShieldSettingsSummary
    @StateObject private var viewModel = ChildShieldDetailViewModel()
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading details...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    // Child Info Section
                    Section("Device Information") {
                        HStack {
                            Label("Device Name", systemImage: "iphone")
                            Spacer()
                            Text(child.childName)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("Device ID", systemImage: "number")
                            Spacer()
                            Text(child.deviceId)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        HStack {
                            Label("Total Apps", systemImage: "app.badge")
                            Spacer()
                            Text("\(child.totalShieldedApps + child.unshieldedApps.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Shielded Apps Section
                    if !viewModel.shieldedApps.isEmpty {
                        Section("Permanently Shielded Apps (\(viewModel.shieldedApps.count))") {
                            ForEach(viewModel.shieldedApps, id: \.id) { app in
                                ShieldedAppRow(app: app)
                            }
                        }
                    }
                    
                    // Unshielded Apps Section
                    if !viewModel.unshieldedApps.isEmpty {
                        Section("Temporarily Unshielded Apps (\(viewModel.unshieldedApps.count))") {
                            ForEach(viewModel.unshieldedApps, id: \.id) { app in
                                UnshieldedAppRow(app: app)
                            }
                        }
                    }
                    
                    // No Apps Message
                    if viewModel.shieldedApps.isEmpty && viewModel.unshieldedApps.isEmpty {
                        Section {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    Image(systemName: "shield.slash")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    
                                    Text("No Shield Settings")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
                                    Text("This child device doesn't have any shield settings configured yet.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadShieldSettings(for: child.deviceId)
                }
            }
        }
        .navigationTitle(child.childName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Refresh") {
                    Task {
                        await viewModel.loadShieldSettings(for: child.deviceId)
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadShieldSettings(for: child.deviceId)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onReceive(viewModel.$error) { error in
            if let error = error {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

struct ShieldedAppRow: View {
    let app: SupabaseShieldSetting
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(app.app_name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(app.bundle_identifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.red)
                    Text("Shielded")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Text("Permanent")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct UnshieldedAppRow: View {
    let app: SupabaseShieldSetting
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(app.app_name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(app.bundle_identifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                    Text("Unlocked")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if let expiryString = app.unlock_expiry,
                   let expiryDate = ISO8601DateFormatter().date(from: expiryString) {
                    Text("Expires: \(expiryDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Expires: Unknown")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationView {
        ChildShieldDetailView(child: ChildShieldSettingsSummary(
            deviceId: "test-device",
            childName: "Test Child",
            totalShieldedApps: 2,
            unshieldedApps: [],
            nextExpiryTime: nil
        ))
    }
}
