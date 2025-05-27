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
    @State private var hasCheckedStoredRole = false
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
        .onAppear {
            // Skip selection if already selected
            guard !hasCheckedStoredRole else { return }
            hasCheckedStoredRole = true
            let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
            if let savedRole = groupDefaults?.string(forKey: "zap_userRole"),
               let userRole = UserRole(rawValue: savedRole) {
                // Directly call onSelect to skip selection UI
                DispatchQueue.main.async {
                    onSelect(userRole)
                }
            }
        }
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
                    // Save DeviceName and Role to group UserDefaults
                    groupDefaults?.set(role.rawValue, forKey: "zap_userRole")
                    groupDefaults?.set(deviceOwnerName, forKey: "DeviceName")
                    if let deviceId = groupDefaults?.string(forKey: "ZapDeviceId") {
                        // Update device name and parent status using SupabaseManager
                        Task {
                            do {
                                _ = try await SupabaseManager.shared.updateDeviceName(newName: deviceOwnerName)
                                print("Device name updated on Supabase.")
                            } catch {
                                print("Failed to update device name on Supabase: \(error)")
                            }
                            do {
                                _ = try await SupabaseManager.shared.updateDeviceParentStatus(isParent: isParent)
                                print("Device parent status updated on Supabase.")
                                do {
                                    let pairs = try await SupabaseManager.shared.checkDeviceRelationship()
                                    print("Device relationships checked. Created pairs: \(pairs)")
                                } catch {
                                    print("Failed to check device relationships: \(error)")
                                }
                            } catch {
                                print("Failed to update device parent status on Supabase: \(error)")
                            }
                            await MainActor.run {
                                showingNamePrompt = false
                                onSelect(role)
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
