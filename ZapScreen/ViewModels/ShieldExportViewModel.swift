//
//  ShieldExportViewModel.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation

@MainActor
class ShieldExportViewModel: ObservableObject {
    @Published var selectedFormat: ExportFormat = .csv
    @Published var exportFilter = ExportFilter()
    @Published var availableChildren: [ChildShieldSettingsSummary] = []
    @Published var isExporting = false
    @Published var error: Error?
    
    init() {
        // Set up default filter to include all children
        exportFilter.selectedChildren = []
    }
    
    func loadAvailableChildren() {
        Task {
            do {
                let allSettings = try await SupabaseManager.shared.getAllChildrenShieldSettings()
                
                // Group settings by child device
                let groupedSettings = Dictionary(grouping: allSettings) { setting in
                    setting.child_device_id
                }
                
                // Convert to ChildShieldSettingsSummary objects
                var children: [ChildShieldSettingsSummary] = []
                
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
                    
                    children.append(summary)
                }
                
                // Sort by child name
                children.sort { $0.childName < $1.childName }
                
                self.availableChildren = children
                
                // If no specific children are selected, select all
                if exportFilter.selectedChildren.isEmpty {
                    exportFilter.selectedChildren = Set(children.map { $0.deviceId })
                }
                
            } catch {
                print("[ShieldExportViewModel] Failed to load children: \(error)")
                self.error = error
            }
        }
    }
    
    func toggleChildSelection(_ deviceId: String) {
        if exportFilter.selectedChildren.contains(deviceId) {
            exportFilter.selectedChildren.remove(deviceId)
        } else {
            exportFilter.selectedChildren.insert(deviceId)
        }
    }
    
    func resetFilters() {
        exportFilter = ExportFilter()
        // Select all available children
        exportFilter.selectedChildren = Set(availableChildren.map { $0.deviceId })
    }
    
    func generateExportData() async throws -> ShieldExportData {
        // Get all shield settings
        let allSettings = try await SupabaseManager.shared.getAllChildrenShieldSettings()
        
        // Apply filters
        let filteredSettings = applyFilters(to: allSettings)
        
        // Group by child device
        let groupedSettings = Dictionary(grouping: filteredSettings) { setting in
            setting.child_device_id
        }
        
        // Convert to export data
        var childrenExportData: [ChildShieldExportData] = []
        var totalShieldedApps = 0
        var totalUnshieldedApps = 0
        
        for (deviceId, settings) in groupedSettings {
            let childName = settings.first?.device_owner ?? "Unknown Child"
            
            // Separate shielded and unshielded apps
            let shieldedApps = settings.filter { $0.is_shielded }
            let unshieldedApps = settings.filter { !$0.is_shielded }
            
            totalShieldedApps += shieldedApps.count
            totalUnshieldedApps += unshieldedApps.count
            
            // Convert to export format
            let shieldedExportApps = shieldedApps.map { setting in
                AppShieldExportData(
                    appName: setting.app_name,
                    bundleIdentifier: setting.bundle_identifier,
                    isShielded: true,
                    shieldType: setting.shield_type,
                    unlockExpiry: nil,
                    lastUpdated: ISO8601DateFormatter().date(from: setting.updated_at) ?? Date()
                )
            }
            
            let unshieldedExportApps = unshieldedApps.map { setting in
                AppShieldExportData(
                    appName: setting.app_name,
                    bundleIdentifier: setting.bundle_identifier,
                    isShielded: false,
                    shieldType: setting.shield_type,
                    unlockExpiry: ISO8601DateFormatter().date(from: setting.unlock_expiry ?? ""),
                    lastUpdated: ISO8601DateFormatter().date(from: setting.updated_at) ?? Date()
                )
            }
            
            let totalApps = shieldedApps.count + unshieldedApps.count
            let shieldedPercentage = totalApps > 0 ? Double(shieldedApps.count) / Double(totalApps) * 100 : 0
            
            let childExportData = ChildShieldExportData(
                childName: childName,
                deviceId: deviceId,
                totalApps: totalApps,
                shieldedApps: shieldedExportApps,
                unshieldedApps: unshieldedExportApps,
                shieldedPercentage: shieldedPercentage,
                lastUpdated: Date() // Current time for export
            )
            
            childrenExportData.append(childExportData)
        }
        
        let totalApps = totalShieldedApps + totalUnshieldedApps
        let overallShieldedPercentage = totalApps > 0 ? Double(totalShieldedApps) / Double(totalApps) * 100 : 0
        
        // Get family name (use first child's name or default)
        let familyName = childrenExportData.first?.childName ?? "Family"
        
        return ShieldExportData(
            exportDate: Date(),
            familyName: familyName,
            totalChildren: childrenExportData.count,
            totalApps: totalApps,
            totalShieldedApps: totalShieldedApps,
            totalUnshieldedApps: totalUnshieldedApps,
            overallShieldedPercentage: overallShieldedPercentage,
            childrenData: childrenExportData
        )
    }
    
    private func applyFilters(to settings: [SupabaseShieldSetting]) -> [SupabaseShieldSetting] {
        var filtered = settings
        
        // Apply date range filter
        if let dateInterval = exportFilter.dateRange.dateInterval {
            filtered = filtered.filter { setting in
                if let updatedAt = ISO8601DateFormatter().date(from: setting.updated_at) {
                    return dateInterval.contains(updatedAt)
                }
                return false
            }
        }
        
        // Apply shield status filter
        if !exportFilter.includeShielded {
            filtered = filtered.filter { !$0.is_shielded }
        }
        
        if !exportFilter.includeUnshielded {
            filtered = filtered.filter { $0.is_shielded }
        }
        
        // Apply children filter
        if !exportFilter.selectedChildren.isEmpty {
            filtered = filtered.filter { exportFilter.selectedChildren.contains($0.child_device_id) }
        }
        
        return filtered
    }
}
