//
//  AppStatusViewModel.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import Combine
import SwiftUI

class AppStatusViewModel: ObservableObject {
    @Published var shieldedApplications: [ApplicationProfile] = []
    @Published var unshieldedApplications: [UnshieldedApplication] = []
    @Published var isLoading = false
    
    private let shieldManager = ShieldManager.shared
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to ShieldManager's published properties
        setupBindings()
        startAutoRefresh()
    }
    
    deinit {
        stopAutoRefresh()
    }
    
    // MARK: - Data Binding
    
    private func setupBindings() {
        // Bind to ShieldManager's published properties
        shieldManager.$shieldedApplications
            .assign(to: \.shieldedApplications, on: self)
            .store(in: &cancellables)
        
        shieldManager.$unshieldedApplications
            .assign(to: \.unshieldedApplications, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    func loadAppStatus() {
        // Data is now automatically updated via bindings
        // Just trigger a refresh in ShieldManager
        shieldManager.refreshData()
    }
    
    func refreshAppStatus() {
        shieldManager.cleanupExpiredUnshieldedApps()
    }
    
    // MARK: - App Management
    
    func temporarilyUnlockApp(_ app: ApplicationProfile, for durationMinutes: Int) {
        shieldManager.temporarilyUnlockApplication(app, for: durationMinutes)
        // No need to call loadAppStatus() - ShieldManager will update automatically
    }
    
    func reapplyShieldToApp(_ app: UnshieldedApplication) {
        shieldManager.reapplyShieldToExpiredApp(app)
        // No need to call loadAppStatus() - ShieldManager will update automatically
    }
    
    func removeAppFromShield(_ app: ApplicationProfile) {
        shieldManager.removeApplicationFromShield(app)
        // No need to call loadAppStatus() - ShieldManager will update automatically
    }
    
    // MARK: - Auto Refresh
    
    private func startAutoRefresh() {
        // Refresh every 30 seconds to update countdown timers
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refreshAppStatus()
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Computed Properties
    
    var totalShieldedCount: Int {
        return shieldedApplications.count
    }
    
    var totalUnshieldedCount: Int {
        return unshieldedApplications.count
    }
    
    var activeUnshieldedApps: [UnshieldedApplication] {
        return unshieldedApplications.filter { !$0.isExpired }
    }
    
    var expiredUnshieldedApps: [UnshieldedApplication] {
        return unshieldedApplications.filter { $0.isExpired }
    }
    
    var hasActiveUnshieldedApps: Bool {
        return !activeUnshieldedApps.isEmpty
    }
    
    var hasExpiredUnshieldedApps: Bool {
        return !expiredUnshieldedApps.isEmpty
    }
}
