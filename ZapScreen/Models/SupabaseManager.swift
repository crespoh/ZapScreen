import Foundation
import Supabase
import SwiftUI
import os.log

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
    private let unlockEventURL = "https://droyecamihyazodenamj.supabase.co/functions/v1/unlock-event"
    private let unlockCommandURL = "https://droyecamihyazodenamj.supabase.co/functions/v1/unlock-command"

    private let logger = Logger(subsystem: "com.ntt.ZapScreen.ZapScreenShieldAction", category: "ShieldAction")
    
    private init() {
        let url = URL(string: "https://droyecamihyazodenamj.supabase.co")! // Replace with your Supabase project URL
        let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRyb3llY2FtaWh5YXpvZGVuYW1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTIwMTYsImV4cCI6MjA2MzM4ODAxNn0.aC8tAcICXcE1pBYOGsSMLzj7XdSmbncAPjqx9cNW0OY" // Replace with your Supabase anon key
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    /// Restore Supabase session from App Group before making authenticated requests
    func restoreSessionFromAppGroup() async {
        let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        if let accessToken = groupDefaults?.string(forKey: "supabase_access_token"),
           let refreshToken = groupDefaults?.string(forKey: "supabase_refresh_token") {
            do {
                let session = try await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
                print("AccessToken \(accessToken)")
                print("RefreshToken \(refreshToken)")
                updateStoredTokens(from: session)
            } catch {
                print("Failed to restore Supabase session: \(error)")
            }
        }
    }

    /// Helper to update tokens in App Group UserDefaults
    func updateStoredTokens(from session: Session) {
        let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        groupDefaults?.set(session.accessToken, forKey: "supabase_access_token")
        groupDefaults?.set(session.refreshToken, forKey: "supabase_refresh_token")
    }

    /// Example: Call this after login or any session refresh
    func loginAndStoreTokens(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        updateStoredTokens(from: session)
    }
    
    /// Call this in your extension before making authenticated requests
    func loadSessionFromAppGroup() async {
        let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        if let accessToken = groupDefaults?.string(forKey: "supabase_access_token"),
           let refreshToken = groupDefaults?.string(forKey: "supabase_refresh_token") {
            do {
                // If your SDK supports this:
                try await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
            } catch {
                print("Failed to restore Supabase session: \(error)")
            }
        }
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
        await restoreSessionFromAppGroup()
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
        await restoreSessionFromAppGroup()
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
        await restoreSessionFromAppGroup()
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
        await restoreSessionFromAppGroup()
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
        await restoreSessionFromAppGroup()
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
        await restoreSessionFromAppGroup()
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
    
    func sendUnlockEvent(bundleIdentifier: String, requestId: String? = nil) async {
        // Call Supabase Edge Function for unlock-event
        let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        var accessToken = groupDefaults?.string(forKey: "supabase_access_token")
        var refreshToken = groupDefaults?.string(forKey: "supabase_refresh_token")
        
        logger.info("[SupabaseManager] SendUnlockEvent")
        // If no access token, try silent refresh
        if accessToken == nil, let refreshToken = refreshToken {
            do {
                let session = try await client.auth.refreshSession(refreshToken: refreshToken)
                updateStoredTokens(from: session)
                accessToken = session.accessToken
            } catch {
                print("[SupabaseManager] Silent refresh failed: \(error)")
                return
            }
        }
        guard let finalAccessToken = accessToken else {
            print("No Supabase access token available.")
            return
        }
        logger.info("[SupabaseManager] SendUnlockEvent with token found \(finalAccessToken)")

        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else { return }
        guard let url = URL(string: "https://droyecamihyazodenamj.supabase.co/functions/v1/unlock-event") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(finalAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build request body with optional request_id
        var payload: [String: Any] = [
            "childDeviceId": deviceId,
            "bundleIdentifier": bundleIdentifier
        ]
        
        if let requestId = requestId {
            payload["request_id"] = requestId
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        // --- BEGIN VERBOSE LOGGING ---
        logger.info("[SupabaseManager] Sending Unlock Event request:")
        logger.info("URL: \(request.url?.absoluteString ?? "<nil>")")
        logger.info("Method: \(request.httpMethod ?? "<nil>")")
        logger.info("Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.info("Body: \(bodyString)")
        } else {
            logger.info("Body: <none>")
        }
        // --- END VERBOSE LOGGING ---
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                logger.info("Unlock event sent successfully.")
            } else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.info("Failed to send unlock event: \(message)")
            }
        } catch {
            logger.info("Network error sending unlock event: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Send Lock Command
    func sendUnLockCommand(to childDeviceId: String, bundleIdentifier: String, time minutes: Int, requestId: String? = nil, completion: @escaping (Result<Void, Error>) -> Void) async {
        // Call Supabase Edge Function for unlock-command
        let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        var accessToken = groupDefaults?.string(forKey: "supabase_access_token")
        let refreshToken = groupDefaults?.string(forKey: "supabase_refresh_token")
        // If no access token, try silent refresh
        if accessToken == nil, let refreshToken = refreshToken {
            do {
                let session = try await client.auth.refreshSession(refreshToken: refreshToken)
                updateStoredTokens(from: session)
                accessToken = session.accessToken
            } catch {
                completion(.failure(NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Silent refresh failed: \(error.localizedDescription)"])));
                return
            }
        }
        guard let finalAccessToken = accessToken else {
            completion(.failure(NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "No Supabase access token available."])));
            return
        }
        guard let url = URL(string: "https://droyecamihyazodenamj.supabase.co/functions/v1/unlock-command") else {
            completion(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Supabase Edge Function URL."])));
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(finalAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build request body with optional request_id
        var body: [String: Any] = [
            "childDeviceId": childDeviceId,
            "bundleIdentifier": bundleIdentifier,
            "minutes": minutes
        ]
        
        if let requestId = requestId {
            body["request_id"] = requestId
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        print("Bundle Identifier: \(bundleIdentifier)")
        print("Time \(minutes)")
        // --- BEGIN VERBOSE LOGGING ---
        print("[ZapScreenManager] Sending request:")
        print("URL: \(request.url?.absoluteString ?? "<nil>")")
        print("Method: \(request.httpMethod ?? "<nil>")")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Body: \(bodyString)")
        } else {
            print("Body: <none>")
        }
        // --- END VERBOSE LOGGING ---
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let responseString = String(data: data, encoding: .utf8) ?? ""
                
                if httpResponse.statusCode == 200 {
                    completion(.success(()))
                } else if httpResponse.statusCode == 503 {
                    // Retryable error
                    completion(.failure(NSError(domain: "", code: 503, userInfo: [NSLocalizedDescriptionKey: "Service temporarily unavailable. Please try again."])))
                } else {
                    // Parse error response
                    if let responseData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = responseData["error"] as? String {
                        completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: error])))
                    } else {
                        completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to send Unlock command: \(responseString)"])))
                    }
                }
            } else {
                completion(.failure(NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
            }
        } catch {
            completion(.failure(error))
        }
    }
}
