import Foundation
import Supabase
import SwiftUI

// MARK: - Supabase Table Structs

struct SupabaseDeviceInsert: Encodable {
    let device_token: String
    let device_id: String
    let device_name: String
    let is_parent: Bool
    let user_account_id: String
}

struct SupabaseDevice: Codable, Identifiable {
    let id: String
    let device_token: String
    let device_id: String
    let device_name: String
    let is_parent: Bool
    let user_account_id: String
    let created_at: String
    
    // Optional: Convert created_at to Date
    var createdAtDate: Date? {
        ISO8601DateFormatter().date(from: created_at)
    }
}

struct SupabaseParentChild: Codable, Identifiable {
    let id: String
    let parent_device_id: String
    let child_device_id: String
    let user_account_id: String
    let created_at: String
    
    // Optional: Convert created_at to Date
    var createdAtDate: Date? {
        ISO8601DateFormatter().date(from: created_at)
    }
}

struct SupabaseParentChildInsert: Encodable {
    let parent_device_id: String
    let child_device_id: String
    let user_account_id: String
}

class SupabaseManager {
    static let shared = SupabaseManager()
    let client: SupabaseClient

    private init() {
        let url = URL(string: "https://droyecamihyazodenamj.supabase.co")! // Replace with your Supabase project URL
        let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRyb3llY2FtaWh5YXpvZGVuYW1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTIwMTYsImV4cCI6MjA2MzM4ODAxNn0.aC8tAcICXcE1pBYOGsSMLzj7XdSmbncAPjqx9cNW0OY" // Replace with your Supabase anon key
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    // Check if a device exists in the 'devices' table by device_token or device_id
    func deviceExists(deviceToken: String) async throws -> Bool {
        guard let deviceId = await UIDevice.current.identifierForVendor?.uuidString else {
            return false
        }
        // Query for either device_token or device_id
        let response = try await client
            .from("devices")
            .select("id")
            .or("device_token.eq.", referencedTable: nil)
            .or("device_token.eq.\(deviceToken),device_id.eq.\(deviceId)", referencedTable: nil)
            .limit(1)
            .execute()
        let data = response.data
        do {
            let devices = try JSONDecoder().decode([SupabaseDevice].self, from: data)
            return !devices.isEmpty
        } catch {
            print("[SupabaseManager] Decoding error in deviceExists: \(error)")
        }
        return false
    }

    // Add a new device if device_token and device_id are not found
    func addDevice(deviceToken: String, deviceName: String, isParent: Bool, userAccountId: String) async throws -> SupabaseDevice? {
        guard let deviceId = await UIDevice.current.identifierForVendor?.uuidString else {
            return nil
        }
        guard let currentUserId = client.auth.currentUser?.id.uuidString, currentUserId == userAccountId else {
            print("[SupabaseManager] Not allowed: addDevice for another user.")
            return nil
        }
        // Check if device with this token or id already exists for this user
        let exists = try await deviceExists(deviceToken: deviceToken)
        if exists {
            return nil // Device already exists
        }
        // Insert new device
        let payload = SupabaseDeviceInsert(
            device_token: deviceToken,
            device_id: deviceId,
            device_name: deviceName,
            is_parent: isParent,
            user_account_id: userAccountId
        )
        let response = try await client
            .from("devices")
            .insert([payload])
            .select()
            .single()
            .execute()
        let data = response.data
        do {
            let device = try JSONDecoder().decode(SupabaseDevice.self, from: data)
            return device
        } catch {
            print("[SupabaseManager] Decoding error in addDevice: \(error)")
        }
        return nil
    }

    func updateDeviceName(newName: String) async throws -> SupabaseDevice {
        guard let deviceId = await UIDevice.current.identifierForVendor?.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No deviceId available"])
        }
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found for update."])
        }
        let response = try await client
            .from("devices")
            .update(["device_name": newName])
            .eq("device_id", value: deviceId)
            .eq("user_account_id", value: userId)
            .select()
            .single()
            .execute()
        let data = response.data
        let device = try JSONDecoder().decode(SupabaseDevice.self, from: data)
        return device
    }

    // Update the is_parent status for the current device
    func updateDeviceParentStatus(isParent: Bool) async throws -> SupabaseDevice {
        guard let deviceId = await UIDevice.current.identifierForVendor?.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No deviceId available"])
        }
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found for update."])
        }
        let response = try await client
            .from("devices")
            .update(["is_parent": isParent])
            .eq("device_id", value: deviceId)
            .eq("user_account_id", value: userId)
            .select()
            .single()
            .execute()
        let data = response.data
        let device = try JSONDecoder().decode(SupabaseDevice.self, from: data)
        return device
    }

    // Fetch all devices from Supabase
    func fetchAllDevices() async throws -> [SupabaseDevice] {
        guard let userId = client.auth.currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found for device query."])
        }
        let response = try await client
            .from("devices")
            .select()
            .eq("user_account_id", value: userId.uuidString)
            .execute()
        let data = response.data
        let devices = try JSONDecoder().decode([SupabaseDevice].self, from: data)
        return devices
    }

    // Check and create missing parent-child relationships in Supabase
    func checkDeviceRelationship() async throws -> [(parent: String, child: String)] {
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found for relationship operation."])
        }
        // Fetch all devices for this user
        let devices = try await fetchAllDevices()
        let parents = devices.filter { $0.is_parent }
        let children = devices.filter { !$0.is_parent }
        guard !parents.isEmpty, !children.isEmpty else {
            print("No parent or child devices found. Skipping relationship setup.")
            return []
        }
        // Fetch all existing relationships for this user
        let relResponse = try await client
            .from("parent_child")
            .select()
            .eq("user_account_id", value: userId)
            .execute()
        let relData = relResponse.data
        let existingRels = try JSONDecoder().decode([SupabaseParentChild].self, from: relData)
        var existingPairs = Set(existingRels.map { $0.parent_device_id + ":" + $0.child_device_id })
        var createdPairs: [(parent: String, child: String)] = []
        for parent in parents {
            for child in children {
                let pairKey = parent.device_id + ":" + child.device_id
                if !existingPairs.contains(pairKey) {
                    // Insert new relationship
                    let payload = SupabaseParentChildInsert(
                        parent_device_id: parent.device_id,
                        child_device_id: child.device_id,
                        user_account_id: userId
                    )
                    _ = try await client
                        .from("parent_child")
                        .insert([payload])
                        .execute()
                    createdPairs.append((parent: parent.device_id, child: child.device_id))
                }
            }
        }
        return createdPairs
    }

    // Delete the current device from Supabase
    func deleteDevice(deviceId: String) async throws -> Bool {
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found for delete."])
        }
        let response = try await client
            .from("devices")
            .delete()
            .eq("device_id", value: deviceId)
            .eq("user_account_id", value: userId)
            .execute()
        // If no error is thrown, consider delete successful
        return true
    }

}
