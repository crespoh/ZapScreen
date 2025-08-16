//
//  SelectAppsModel.swift
//  ZapScreen
//
//  Created by tongteknai on 18/5/25.
//

import Foundation
import FamilyControls
import Combine
import ManagedSettings

class AppSelectionModel: ObservableObject {
    @Published var activitySelection = FamilyActivitySelection()
    private var cancellables = Set<AnyCancellable>()
    static let shared = AppSelectionModel()
    
    init() {
        activitySelection = savedSelection() ?? FamilyActivitySelection()
          
        $activitySelection.sink { selection in
              self.saveSelection(selection: selection)
        }
        .store(in: &cancellables)
    }
    
    func saveSelection(selection: FamilyActivitySelection) {
    
        let defaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        
        guard let encoded = try? JSONEncoder().encode(selection) else { return }
        defaults?.set(encoded, forKey: "FamilyActivitySelection")
    }
    
    func savedSelection() -> FamilyActivitySelection? {
        
        let defaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        
        guard let data = defaults?.data(forKey: "FamilyActivitySelection") else { return nil }
        guard let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return nil }
        return decoded
        
    }
    
    // New method to sync with ShieldManager
    func syncWithShieldManager(_ shieldManager: ShieldManager) {
        // Update the model's selection to match ShieldManager's current state
        activitySelection.applicationTokens = shieldManager.discouragedSelections.applicationTokens
        saveSelection(selection: activitySelection)
        print("[AppSelectionModel] Synced with ShieldManager: \(activitySelection.applicationTokens.count) apps")
    }
}
