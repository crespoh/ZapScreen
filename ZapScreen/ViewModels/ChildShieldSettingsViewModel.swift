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
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Set up error handling
        $error
            .compactMap { $0 }
            .sink { [weak self] error in
                print("[ChildShieldSettingsViewModel] Error occurred: \(error.localizedDescription)")
                self?.error = nil // Reset error after handling
            }
            .store(in: &cancellables)
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
                let childName = settings.first?.child_name ?? "Unknown Child"
                
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
}
