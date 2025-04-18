import SwiftUI
import FamilyControls
import ManagedSettings

@MainActor
class AppSettings: ObservableObject {
    @Published var children: [Child] = []
    @Published var isAuthorized = false
    
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
            let selection = try await center.requestAuthorization(for: .individual)
            let familyMembers = try await center.requestFamilyMembers()
            
            children = familyMembers.map { member in
                Child(
                    name: member.displayName,
                    deviceIdentifier: member.deviceIdentifier ?? "",
                    earningApps: EarningApps(applicationTokens: selection.applicationTokens, categoryTokens: selection.categoryTokens)
                )
            }
        } catch {
            print("Error fetching children: \(error)")
        }
    }
    
    func setEarningApps(for child: Child, selection: FamilyActivitySelection) {
        guard let index = children.firstIndex(where: { $0.id == child.id }) else { return }
        children[index].earningApps = EarningApps(
            applicationTokens: selection.applicationTokens,
            categoryTokens: selection.categoryTokens
        )
    }
} 