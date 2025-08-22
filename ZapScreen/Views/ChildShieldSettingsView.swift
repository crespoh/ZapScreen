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
    @State private var showingExportView = false
    
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
                    VStack(spacing: 0) {
                        // Statistics Summary Card
                        if !viewModel.children.isEmpty {
                            statisticsSummaryCard
                        }
                        
                        // Search and Filter Controls
                        searchAndFilterControls
                        
                        // Results List
                        if viewModel.filteredAndSortedChildren.isEmpty {
                            noResultsView
                        } else {
                            childrenList
                        }
                    }
                }
            }
            .navigationTitle("Child Shield Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button("Export") {
                            showingExportView = true
                        }
                        
                        Button("Refresh") {
                            Task {
                                await viewModel.loadShieldSettings()
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
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
        .sheet(isPresented: $showingExportView) {
            ShieldExportView()
        }
    }
    
    // MARK: - Search and Filter Controls
    
    // MARK: - Statistics Summary Card
    
    private var statisticsSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.accentColor)
                Text("Family Shield Overview")
                    .font(.headline)
                Spacer()
                
                // Auto-refresh toggle
                Button(action: {
                    viewModel.toggleAutoRefresh()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isAutoRefreshing ? "arrow.clockwise" : "arrow.clockwise.circle")
                            .foregroundColor(viewModel.isAutoRefreshing ? .green : .secondary)
                        Text(viewModel.isAutoRefreshing ? "Auto" : "Manual")
                            .font(.caption)
                            .foregroundColor(viewModel.isAutoRefreshing ? .green : .secondary)
                    }
                }
                .buttonStyle(.bordered)
                .scaleEffect(0.9)
            }
            
            // Statistics Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Total Children
                VStack(spacing: 4) {
                    Text("\(viewModel.totalChildren)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Children")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Total Apps
                VStack(spacing: 4) {
                    Text("\(viewModel.totalApps)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Total Apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Shielded Apps
                VStack(spacing: 4) {
                    Text("\(viewModel.totalShieldedApps)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("Shielded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Overall Shield Coverage Bar
            if viewModel.totalApps > 0 {
                VStack(spacing: 8) {
                    HStack {
                        Text("Overall Shield Coverage")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(Int(viewModel.overallShieldedPercentage))%")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    
                    ProgressView(value: viewModel.overallShieldedPercentage, total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: .red))
                        .scaleEffect(x: 1, y: 1.2, anchor: .center)
                }
            }
            
            // Last Updated Info
            HStack {
                Text("Last updated: \(viewModel.lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.isAutoRefreshing {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                        Text("Auto-refreshing every 30s")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var searchAndFilterControls: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search children or apps...", text: $viewModel.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !viewModel.searchText.isEmpty {
                    Button("Clear") {
                        viewModel.clearSearch()
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            
            // Filter and Sort Controls
            HStack(spacing: 16) {
                // Filter Picker
                Menu {
                    ForEach(ShieldFilter.allCases) { filter in
                        Button(action: {
                            viewModel.selectedFilter = filter
                        }) {
                            HStack {
                                Image(systemName: filter.icon)
                                Text(filter.rawValue)
                                if viewModel.selectedFilter == filter {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.selectedFilter.icon)
                        Text(viewModel.selectedFilter.rawValue)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Sort Picker
                Menu {
                    ForEach(ShieldSort.allCases) { sort in
                        Button(action: {
                            viewModel.selectedSort = sort
                        }) {
                            HStack {
                                Image(systemName: sort.icon)
                                Text(sort.rawValue)
                                if viewModel.selectedSort == sort {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.selectedSort.icon)
                        Text(viewModel.selectedSort.rawValue)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Reset Filters Button
                if viewModel.selectedFilter != .all || viewModel.selectedSort != .nameAsc {
                    Button("Reset") {
                        viewModel.resetFilters()
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var childrenList: some View {
        List {
            ForEach(viewModel.filteredAndSortedChildren, id: \.deviceId) { child in
                NavigationLink(destination: ChildShieldDetailView(child: child)) {
                    ChildShieldSummaryRow(child: child)
                }
            }
        }
        .refreshable {
            await viewModel.loadShieldSettings()
        }
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Results Found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try adjusting your search terms or filters.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Clear Search") {
                viewModel.clearSearch()
            }
            .buttonStyle(.bordered)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ChildShieldSummaryRow: View {
    let child: ChildShieldSettingsSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with child info and main stats
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
                
                // Main statistics
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        // Shielded apps count
                        VStack(spacing: 2) {
                            Text("\(child.totalShieldedApps)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            
                            Text("Shielded")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        // Total apps count
                        VStack(spacing: 2) {
                            Text("\(child.totalApps)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Total")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Progress bar for shield percentage
            if child.totalApps > 0 {
                VStack(spacing: 4) {
                    HStack {
                        Text("Shield Coverage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(child.shieldedPercentage))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    ProgressView(value: child.shieldedPercentage, total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: .red))
                        .scaleEffect(x: 1, y: 0.8, anchor: .center)
                }
            }
            
            // Unshielded apps info with enhanced display
            if !child.unshieldedApps.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("\(child.unshieldedApps.count) temporarily unshielded")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                    
                    if let formattedTime = child.formattedTimeUntilExpiry {
                        HStack {
                            Text("Next expires in:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(formattedTime)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

#Preview {
    ChildShieldSettingsView()
}
