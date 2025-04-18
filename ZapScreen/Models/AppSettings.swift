import Foundation
import FamilyControls
import ManagedSettings
import UIKit
import SwiftUI

@MainActor
class AppSettings: ObservableObject {
    @Published var isParentMode: Bool = false
    @Published var children: [Child] = []
    @Published var selectedChildId: UUID?
    @Published var currentDeviceIdentifier: String?
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var isAuthorized = false
    
    var selectedChild: Child? {
        children.first { $0.id == selectedChildId }
    }
    
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()
    @Published var earningApps: FamilyActivitySelection = FamilyActivitySelection()
    @Published var timeLimits: [String: TimeInterval] = [:] // App bundle ID to time limit
    @Published var earningRates: [String: TimeInterval] = [:] // App bundle ID to earning rate (minutes per usage)
    @Published var shieldOptions: [TimeInterval] = [600, 1200, 1800] // 10, 20, 30 minutes in seconds
    
    private let center = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()
    
    init() {
        Task {
            await requestAuthorization()
        }
    }
    
    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            isAuthorized = true
            await fetchChildren()
        } catch {
            print("Error requesting authorization: \(error)")
        }
    }
    
    func fetchChildren() async {
        do {
            let familyMembers = try await center.requestFamilyMembers()
            
            children = familyMembers.map { member in
                Child(
                    name: member.displayName,
                    deviceIdentifier: member.deviceIdentifier ?? "",
                    earningApps: EarningApps(applicationTokens: [], categoryTokens: [])
                )
            }
        } catch {
            print("Error fetching children: \(error)")
        }
    }
    
    private func checkAuthorizationStatus() async {
        let status = await center.authorizationStatus
        await MainActor.run {
            authorizationStatus = status
        }
    }
    
    private func getCurrentDeviceIdentifier() async {
        // Get the current device's identifier
        if let identifier = UIDevice.current.identifierForVendor?.uuidString {
            await MainActor.run {
                currentDeviceIdentifier = identifier
                // If this is a child device, add it to the children list
                if !isParentMode {
                    let child = Child(
                        name: UIDevice.current.name,
                        deviceIdentifier: identifier
                    )
                    if !children.contains(where: { $0.deviceIdentifier == identifier }) {
                        children.append(child)
                        selectedChildId = child.id
                    }
                }
            }
        }
    }
    
    private func checkDeviceType() async {
        do {
            // Try to request authorization for child mode
            try await center.requestAuthorization(for: .individual)
            // If successful, this is a child device
            await MainActor.run {
                isParentMode = false
            }
        } catch {
            // If authorization fails, this is likely a parent device
            // because only child devices can be authorized
            await MainActor.run {
                isParentMode = true
            }
        }
    }
    
    func addChild(name: String, deviceIdentifier: String) {
        let newChild = Child(
            name: name,
            deviceIdentifier: deviceIdentifier
        )
        children.append(newChild)
        if selectedChildId == nil {
            selectedChildId = newChild.id
        }
    }
    
    func removeChild(_ child: Child) {
        children.removeAll { $0.id == child.id }
        if selectedChildId == child.id {
            selectedChildId = children.first?.id
        }
    }
    
    func setAppRestrictions() {
        guard let child = selectedChild else { return }
        let store = ManagedSettingsStore(named: .init(child.deviceIdentifier))
        
        // Clear existing restrictions
        store.clearAllSettings()
        
        // Set new restrictions
        if !child.appRestrictions.applicationTokens.isEmpty {
            store.shield.applications = child.appRestrictions.applicationTokens
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(child.appRestrictions.categoryTokens)
        }
    }
    
    func setEarningApps(for child: Child, selection: FamilyActivitySelection) {
        guard let index = children.firstIndex(where: { $0.id == child.id }) else { return }
        children[index].earningApps = EarningApps(
            applicationTokens: selection.applicationTokens,
            categoryTokens: selection.categoryTokens
        )
    }
    
    func requestAdditionalTime(minutes: TimeInterval, for app: String) {
        // This function will be called from the child device
        // In a real implementation, this would send a notification to the parent device
        print("Requesting \(minutes) additional minutes for \(app)")
    }
    
    func approveTimeRequest(minutes: TimeInterval, for app: String) {
        guard let child = selectedChild,
              let currentLimit = child.timeLimits[app] else { return }
        
        // Approve time request from parent
        var updatedChild = child
        updatedChild.timeLimits[app] = currentLimit + (minutes * 60)
        if let index = children.firstIndex(where: { $0.id == child.id }) {
            children[index] = updatedChild
        }
    }
    
    // Child device specific functions
    func getCurrentChild() -> Child? {
        guard !isParentMode,
              let deviceIdentifier = currentDeviceIdentifier else { return nil }
        return children.first { $0.deviceIdentifier == deviceIdentifier }
    }
    
    func getRemainingTime(for app: String) -> TimeInterval {
        guard let child = getCurrentChild() else { return 0 }
        return child.timeLimits[app] ?? 0
    }
    
    func getEarningRate(for app: String) -> TimeInterval {
        guard let child = getCurrentChild() else { return 0 }
        return child.earningRates[app] ?? 0
    }
} 
