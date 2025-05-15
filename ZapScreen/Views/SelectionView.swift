//
//  SelectionView.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import SwiftUI

enum UserRole: String, CaseIterable, Identifiable {
    case parent = "Parent"
    case child = "Child"
    var id: String { rawValue }

    static var selectionCases: [UserRole] {
        return [.parent, .child]
    }
}

struct SelectionView: View {
    let onSelect: (UserRole) -> Void
    var body: some View {
        VStack(spacing: 32) {
            Text("Who is using this device?")
                .font(.title)
                .padding(.top, 60)
            ForEach(UserRole.selectionCases) { role in
                Button(action: {
                    let isParent = (role == .parent)
                    print("Role selected: \(role.rawValue), isParent: \(isParent)")
                    let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
                    if let deviceId = groupDefaults?.string(forKey: "DeviceId") {
                        print("Calling updateDeviceParentStatus with deviceId: \(deviceId), isParent: \(isParent)")
                        ZapScreenManager.shared.updateDeviceParentStatus(deviceId: deviceId, isParent: isParent) { result in
                            switch result {
                            case .success:
                                print("Device parent status updated for role: \(role)")
                                ZapScreenManager.shared.checkDeviceRelationship { relationships in
                                    print("Relationship check complete. Relationships added: ", relationships)
                                }
                            case .failure(let error):
                                print("Failed to update device parent status: \(error)")
                            }
                        }
                    } else {
                        print("DeviceId not found in UserDefaults")
                    }
                    onSelect(role)
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.2))
                        Text(role.rawValue)
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                }
                .padding(.horizontal)
            }
            Spacer()
        }
        .padding()
    }
}
