//
//  ChildShieldSettingsViewModel.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import Combine

@MainActor
class ChildShieldSettingsViewModel: ObservableObject {
    @Published var children: [ChildShieldSettingsSummary] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // Search and filtering
    @Published var searchText = ""
    @Published var selectedFilter: ShieldFilter = .all
    @Published var selectedSort: ShieldSort = .nameAsc
    
    // Real-time updates
    @Published var lastUpdated = Date()
    @Published var isAutoRefreshing = false
    
    // Computed properties for filtered and sorted results
    var filteredAndSortedChildren: [ChildShieldSettingsSummary] {
        let filtered = filterChildren(children)
        return sortChildren(filtered)
    }
    
    // Enhanced statistics
    var totalChildren: Int { children.count }
    var totalShieldedApps: Int { children.reduce(0) { $0 + $1.totalShieldedApps } }
    var totalUnshieldedApps: Int { children.reduce(0) { $0 + $1.unshieldedApps.count } }
    var totalApps: Int { totalShieldedApps + totalUnshieldedApps }
    var overallShieldedPercentage: Double {
        guard totalApps > 0 else { return 0 }
        return Double(totalShieldedApps) / Double(totalApps) * 100
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var autoRefreshTimer: Timer?
    
    init() {
        // Set up error handling
        $error
            .compactMap { $0 }
            .sink { [weak self] error in
                print("[ChildShieldSettingsViewModel] Error occurred: \(error.localizedDescription)")
                self?.error = nil // Reset error after handling
            }
            .store(in: &cancellables)
        
        // Start auto-refresh timer
        startAutoRefresh()
    }
    
    deinit {
        // Clean up timer on any thread (deinit can run on any thread)
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }
    
    func loadShieldSettings() async {
        isLoading = true
        error = nil
        
        do {
            print("[ChildShieldSettingsViewModel] Loading shield settings for all children...")
            
            // Get all shield settings for the current user's children
            let allSettings = try await SupabaseManager.shared.getAllChildrenShieldSettings()
            print("[ChildShieldSettingsViewModel] Retrieved \(allSettings.count) total shield settings")
            
            // Group settings by child device
            let groupedSettings = Dictionary(grouping: allSettings) { setting in
                setting.child_device_id
            }
            
            // Convert to ChildShieldSettingsSummary objects
            var childSummaries: [ChildShieldSettingsSummary] = []
            
            for (deviceId, settings) in groupedSettings {
                let childName = settings.first?.device_owner ?? "Unknown Child"
                
                // Separate shielded and unshielded apps
                let shieldedApps = settings.filter { $0.is_shielded }
                let unshieldedApps = settings.filter { !$0.is_shielded }
                
                // Find next expiry time for unshielded apps
                let nextExpiryTime = unshieldedApps
                    .compactMap { setting -> Date? in
                        guard let expiryString = setting.unlock_expiry else { return nil }
                        return ISO8601DateFormatter().date(from: expiryString)
                    }
                    .min()
                
                let summary = ChildShieldSettingsSummary(
                    deviceId: deviceId,
                    childName: childName,
                    totalShieldedApps: shieldedApps.count,
                    unshieldedApps: unshieldedApps,
                    nextExpiryTime: nextExpiryTime
                )
                
                childSummaries.append(summary)
            }
            
            // Sort by child name
            childSummaries.sort { $0.childName < $1.childName }
            
            self.children = childSummaries
            print("[ChildShieldSettingsViewModel] Successfully loaded \(childSummaries.count) children")
            
        } catch {
            print("[ChildShieldSettingsViewModel] Failed to load shield settings: \(error)")
            self.error = error
        }
        
        isLoading = false
    }
    
    func refreshData() async {
        await loadShieldSettings()
    }
    
    // MARK: - Search and Filtering
    
    private func filterChildren(_ children: [ChildShieldSettingsSummary]) -> [ChildShieldSettingsSummary] {
        var filtered = children
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { child in
                child.childName.localizedCaseInsensitiveContains(searchText) ||
                child.deviceId.localizedCaseInsensitiveContains(searchText) ||
                child.hasShieldedApps(searchText) ||
                child.hasUnshieldedApps(searchText)
            }
        }
        
        // Apply shield status filter
        switch selectedFilter {
        case .all:
            break // No additional filtering
        case .shieldedOnly:
            filtered = filtered.filter { $0.totalShieldedApps > 0 }
        case .unshieldedOnly:
            filtered = filtered.filter { $0.hasUnshieldedApps }
        case .mixed:
            filtered = filtered.filter { $0.totalShieldedApps > 0 && $0.hasUnshieldedApps }
        }
        
        return filtered
    }
    
    private func sortChildren(_ children: [ChildShieldSettingsSummary]) -> [ChildShieldSettingsSummary] {
        switch selectedSort {
        case .nameAsc:
            return children.sorted { $0.childName < $1.childName }
        case .nameDesc:
            return children.sorted { $0.childName > $1.childName }
        case .appCountAsc:
            return children.sorted { $0.totalApps < $1.totalApps }
        case .appCountDesc:
            return children.sorted { $0.totalApps > $1.totalApps }
        case .shieldedCountAsc:
            return children.sorted { $0.totalShieldedApps < $1.totalShieldedApps }
        case .shieldedCountDesc:
            return children.sorted { $0.totalShieldedApps > $1.totalShieldedApps }
        }
    }
    
    // MARK: - Helper Methods
    
    func clearSearch() {
        searchText = ""
    }
    
    func resetFilters() {
        selectedFilter = .all
        selectedSort = .nameAsc
    }
    
    // MARK: - Auto-refresh Methods
    
    private func startAutoRefresh() {
        stopAutoRefresh() // Ensure no duplicate timers
        
        DispatchQueue.main.async { [weak self] in
            self?.autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    await self?.autoRefresh()
                }
            }
            
            self?.isAutoRefreshing = true
            print("[ChildShieldSettingsViewModel] Auto-refresh started (30 second interval)")
        }
    }
    
    private func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
        isAutoRefreshing = false
        print("[ChildShieldSettingsViewModel] Auto-refresh stopped")
    }
    
    private func autoRefresh() async {
        guard !isLoading else { return }
        
        print("[ChildShieldSettingsViewModel] Auto-refreshing shield settings...")
        await loadShieldSettings()
        lastUpdated = Date()
    }
    
    func toggleAutoRefresh() {
        if isAutoRefreshing {
            stopAutoRefresh()
        } else {
            startAutoRefresh()
        }
    }
}
