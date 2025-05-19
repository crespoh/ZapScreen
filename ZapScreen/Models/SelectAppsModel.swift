//
//  SelectAppsModel.swift
//  ZapScreen
//
//  Created by tongteknai on 18/5/25.
//

import Foundation
import FamilyControls

class SelectAppsModel: ObservableObject {
    @Published var activitySelection = FamilyActivitySelection()

    init() { }
}
