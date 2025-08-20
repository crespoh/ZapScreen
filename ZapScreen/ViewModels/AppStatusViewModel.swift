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
        loadAppStatus()
        startAutoRefresh()
    }
    
    deinit {
        stopAutoRefresh()
    }
    
    // MARK: - Data Loading
    
    func loadAppStatus() {
        isLoading = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.shieldedApplications = self.shieldManager.getShieldedApplications()
            self.unshieldedApplications = self.shieldManager.getUnshieldedApplications()
            self.isLoading = false
        }
    }
    
    func refreshAppStatus() {
        shieldManager.cleanupExpiredUnshieldedApps()
        loadAppStatus()
    }
    
    // MARK: - App Management
    
    func temporarilyUnlockApp(_ app: ApplicationProfile, for durationMinutes: Int) {
        shieldManager.temporarilyUnlockApplication(app, for: durationMinutes)
        loadAppStatus()
    }
    
    func reapplyShieldToApp(_ app: UnshieldedApplication) {
        shieldManager.reapplyShieldToExpiredApp(app)
        loadAppStatus()
    }
    
    func removeAppFromShield(_ app: ApplicationProfile) {
        shieldManager.removeApplicationFromShield(app)
        loadAppStatus()
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
