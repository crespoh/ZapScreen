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
    @State private var pendingRole: UserRole? = nil
    @State private var showingNamePrompt = false
    @State private var deviceOwnerName: String = ""
    var body: some View {
        VStack(spacing: 32) {
            Text("Who is using this device?")
                .font(.title)
                .padding(.top, 60)
            ForEach(UserRole.selectionCases) { role in
                Button(action: {
                    // Save the pending role and show name prompt
                    pendingRole = role
                    deviceOwnerName = ""
                    showingNamePrompt = true
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
        .sheet(isPresented: $showingNamePrompt) {
            VStack(spacing: 20) {
                Text("Who does this device belong to?")
                    .font(.headline)
                TextField("Enter name", text: $deviceOwnerName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                Button("Confirm") {
                    guard let role = pendingRole else { return }
                    let isParent = (role == .parent)
                    let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
                    // Save DeviceName to group UserDefaults
                    groupDefaults?.set(deviceOwnerName, forKey: "DeviceName")
                    if let deviceId = groupDefaults?.string(forKey: "ZapDeviceId") {
                        // First update device name on server
                        ZapScreenManager.shared.updateDeviceName(deviceId: deviceId, deviceName: deviceOwnerName) { result in
                            switch result {
                            case .success:
                                print("Device name updated on server.")
                            case .failure(let error):
                                print("Failed to update device name on server: \(error)")
                            }
                            // Then update parent status
                            ZapScreenManager.shared.updateDeviceParentStatus(deviceId: deviceId, isParent: isParent) { result in
                                switch result {
                                case .success:
                                    ZapScreenManager.shared.checkDeviceRelationship { _ in }
                                case .failure(let error):
                                    print("Failed to update device parent status: \(error)")
                                }
                                DispatchQueue.main.async {
                                    showingNamePrompt = false
                                    onSelect(role)
                                }
                            }
                        }
                    } else {
                        // If deviceId not found, just proceed
                        showingNamePrompt = false
                        onSelect(role)
                    }
                }
                .disabled(deviceOwnerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel") {
                    showingNamePrompt = false
                    pendingRole = nil
                }
                .foregroundColor(.red)
            }
            .padding()
            .presentationDetents([.medium])
        }
    }
}
