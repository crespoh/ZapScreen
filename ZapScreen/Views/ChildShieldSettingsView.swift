//
//  ChildShieldSettingsView.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import SwiftUI

struct ChildShieldSettingsView: View {
    @StateObject private var viewModel = ChildShieldSettingsViewModel()
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading shield settings...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.children.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "shield.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Children Found")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Child devices will appear here once they are registered and have shield settings configured.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Refresh") {
                            Task {
                                await viewModel.loadShieldSettings()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.children, id: \.deviceId) { child in
                            NavigationLink(destination: ChildShieldDetailView(child: child)) {
                                ChildShieldSummaryRow(child: child)
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.loadShieldSettings()
                    }
                }
            }
            .navigationTitle("Child Shield Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await viewModel.loadShieldSettings()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadShieldSettings()
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

struct ChildShieldSummaryRow: View {
    let child: ChildShieldSettingsSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(child.childName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(child.deviceId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(child.totalShieldedApps)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    Text("Shielded Apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !child.unshieldedApps.isEmpty {
                HStack {
                    Text("\(child.unshieldedApps.count) temporarily unshielded")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Text("Expires: \(child.nextExpiryTime?.formatted(date: .omitted, time: .shortened) ?? "Unknown")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ChildShieldSettingsView()
}
