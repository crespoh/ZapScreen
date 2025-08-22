//
//  ChildShieldDetailViewModel.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import Combine

@MainActor
class ChildShieldDetailViewModel: ObservableObject {
    @Published var shieldedApps: [SupabaseShieldSetting] = []
    @Published var unshieldedApps: [SupabaseShieldSetting] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Set up error handling
        $error
            .compactMap { $0 }
            .sink { [weak self] error in
                print("[ChildShieldDetailViewModel] Error occurred: \(error.localizedDescription)")
                self?.error = nil // Reset error after handling
            }
            .store(in: &cancellables)
    }
    
    func loadShieldSettings(for childDeviceId: String) async {
        isLoading = true
        error = nil
        
        do {
            print("[ChildShieldDetailViewModel] Loading shield settings for child device: \(childDeviceId)")
            
            // Get shield settings for the specific child device
            let settings = try await SupabaseManager.shared.getChildShieldSettings(for: childDeviceId)
            print("[ChildShieldDetailViewModel] Retrieved \(settings.count) shield settings")
            
            // Separate shielded and unshielded apps
            let shielded = settings.filter { $0.is_shielded }
            let unshielded = settings.filter { !$0.is_shielded }
            
            // Sort by app name
            self.shieldedApps = shielded.sorted { $0.app_name < $1.app_name }
            self.unshieldedApps = unshielded.sorted { $0.app_name < $1.app_name }
            
            print("[ChildShieldDetailViewModel] Successfully loaded \(shielded.count) shielded and \(unshielded.count) unshielded apps")
            
        } catch {
            print("[ChildShieldDetailViewModel] Failed to load shield settings: \(error)")
            self.error = error
        }
        
        isLoading = false
    }
    
    func refreshData(for childDeviceId: String) async {
        await loadShieldSettings(for: childDeviceId)
    }
}
