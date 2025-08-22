import Foundation
import ManagedSettings
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
    let child_name: String? // New: child name for child devices
}

struct SupabaseDevice: Codable, Identifiable {
    let id: String
    let device_token: String
    let device_id: String
    let device_name: String
    let is_parent: Bool
    let user_account_id: String
    let child_name: String? // New: child name for child devices
    let created_at: String
    let updated_at: String? // New: updated timestamp
    
    // Optional: Convert created_at to Date
    var createdAtDate: Date? {
        ISO8601DateFormatter().date(from: created_at)
    }
    
    // Optional: Convert updated_at to Date
    var updatedAtDate: Date? {
        guard let updated_at = updated_at else { return nil }
        return ISO8601DateFormatter().date(from: updated_at)
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

// MARK: - Multi-Child Support Models

struct SupabaseFamilySummary: Codable, Identifiable {
    let child_name: String
    let device_name: String
    let device_id: String
    let total_apps: Int
    let total_requests: Int
    let total_minutes: Int
    let last_activity: String?
    
    var lastActivityDate: Date? {
        guard let last_activity = last_activity else { return nil }
        return ISO8601DateFormatter().date(from: last_activity)
    }
    
    // Computed property for Identifiable - use device_id as the identifier
    var id: String { device_id }
}

struct SupabaseChildDevice: Codable, Identifiable {
    let child_name: String
    let device_name: String
    let device_id: String
    let device_token: String?
    let created_at: String
    
    var createdAtDate: Date? {
        ISO8601DateFormatter().date(from: created_at)
    }
    
    // Computed property for Identifiable - use device_id as the identifier
    var id: String { device_id }
}

// MARK: - Shield Settings Models

/// Model for storing child shield settings in Supabase
struct SupabaseShieldSetting: Codable, Identifiable {
    let id: String
    let user_account_id: String
    let child_device_id: String
    let child_name: String
    let app_name: String
    let bundle_identifier: String
    let is_shielded: Bool
    let shield_type: String // "permanent" or "temporary"
    let unlock_expiry: String? // ISO8601 date string
    let created_at: String
    let updated_at: String
    
    /// Convert unlock_expiry string to Date
    var unlockExpiryDate: Date? {
        guard let unlock_expiry = unlock_expiry else { return nil }
        return ISO8601DateFormatter().date(from: unlock_expiry)
    }
    
    /// Convert created_at string to Date
    var createdAtDate: Date? {
        ISO8601DateFormatter().date(from: created_at)
    }
    
    /// Convert updated_at string to Date
    var updatedAtDate: Date? {
        ISO8601DateFormatter().date(from: updated_at)
    }
    
    /// Check if the shield setting is expired (for temporary shields)
    var isExpired: Bool {
        guard let expiryDate = unlockExpiryDate else { return false }
        return Date() > expiryDate
    }
    
    /// Get remaining time for temporary shields
    var remainingTime: TimeInterval? {
        guard let expiryDate = unlockExpiryDate else { return nil }
        let remaining = expiryDate.timeIntervalSince(Date())
        return remaining > 0 ? remaining : 0
    }
    
    /// Get remaining minutes for temporary shields
    var remainingMinutes: Int? {
        guard let remaining = remainingTime else { return nil }
        return Int(remaining / 60)
    }
    
    /// Get formatted remaining time string
    var formattedRemainingTime: String? {
        guard let minutes = remainingMinutes else { return nil }
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMins = minutes % 60
            if remainingMins == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMins)m"
            }
        }
    }
}

/// Model for inserting/updating child shield settings in Supabase
struct SupabaseShieldSettingInsert: Encodable {
    let user_account_id: String
    let child_device_id: String
    let child_name: String
    let app_name: String
    let bundle_identifier: String
    let is_shielded: Bool
    let shield_type: String
    let unlock_expiry: String?
    
    /// Initialize with ApplicationProfile for shielded apps
    init(applicationProfile: ApplicationProfile, 
         userAccountId: String, 
         childDeviceId: String, 
         childName: String) {
        self.user_account_id = userAccountId
        self.child_device_id = childDeviceId
        self.child_name = childName
        self.app_name = applicationProfile.applicationName
        self.bundle_identifier = String(applicationProfile.applicationToken.hashValue)
        self.is_shielded = true
        self.shield_type = "permanent"
        self.unlock_expiry = nil
    }
    
    /// Initialize with UnshieldedApplication for temporarily unshielded apps
    init(unshieldedApp: UnshieldedApplication, 
         userAccountId: String, 
         childDeviceId: String, 
         childName: String) {
        self.user_account_id = userAccountId
        self.child_device_id = childDeviceId
        self.child_name = childName
        self.app_name = unshieldedApp.applicationName
        self.bundle_identifier = String(unshieldedApp.shieldedAppToken.hashValue)
        self.is_shielded = false
        self.shield_type = "temporary"
        
        // Convert expiry date to ISO8601 string
        let formatter = ISO8601DateFormatter()
        self.unlock_expiry = formatter.string(from: unshieldedApp.expiryDate)
    }
    
    /// Initialize with custom values
    init(userAccountId: String, 
         childDeviceId: String, 
         childName: String, 
         appName: String, 
         bundleIdentifier: String, 
         isShielded: Bool, 
         shieldType: String, 
         unlockExpiry: Date? = nil) {
        self.user_account_id = userAccountId
        self.child_device_id = childDeviceId
        self.child_name = childName
        self.app_name = appName
        self.bundle_identifier = bundleIdentifier
        self.is_shielded = isShielded
        self.shield_type = shieldType
        
        if let expiry = unlockExpiry {
            let formatter = ISO8601DateFormatter()
            self.unlock_expiry = formatter.string(from: expiry)
        } else {
            self.unlock_expiry = nil
        }
    }
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
        
        print("[SupabaseManager] Checking if device exists - Device ID: \(deviceId), Token: \(String(deviceToken.prefix(10)))...")
        
        // Query for either device_token or device_id using proper Supabase syntax
        let response = try await client
            .from("devices")
            .select("id")
            .or("device_token.eq.\(deviceToken),device_id.eq.\(deviceId)")
            .limit(1)
            .execute()
        
        let data = response.data
        print("[SupabaseManager] Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
        
        do {
            let devices = try JSONDecoder().decode([SupabaseDevice].self, from: data)
            let exists = !devices.isEmpty
            print("[SupabaseManager] Device exists check result: \(exists)")
            return exists
        } catch {
            print("[SupabaseManager] Decoding error in deviceExists: \(error)")
            // Try parsing as simple array of objects with just 'id'
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    let exists = !jsonArray.isEmpty
                    print("[SupabaseManager] Device exists check result (fallback): \(exists)")
                    return exists
                }
            } catch {
                print("[SupabaseManager] Fallback parsing also failed: \(error)")
            }
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
            user_account_id: userAccountId,
            child_name: nil // Will be set when registering child devices
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
        let existingPairs = Set(existingRels.map { $0.parent_device_id + ":" + $0.child_device_id })
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
        _ = try await client
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
        let refreshToken = groupDefaults?.string(forKey: "supabase_refresh_token")
        
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

        guard let deviceId = await UIDevice.current.identifierForVendor?.uuidString else { return }
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
    
    // MARK: - Enhanced Usage Statistics Sync
    
    // Sync individual usage records to Supabase
    func syncUsageRecords(_ records: [UsageRecord]) async throws {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        guard let deviceId = await UIDevice.current.identifierForVendor?.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No device ID available"])
        }
        
        let deviceName = await UIDevice.current.name
        
        // Get child name from device registration
        let childName = try? await getChildNameForDevice(deviceId: deviceId)
        
        let supabaseRecords = records.map { record in
            SupabaseUsageRecordInsert(
                user_account_id: userId,
                child_device_id: deviceId,
                child_device_name: deviceName,
                child_name: childName,
                app_name: record.appName,
                bundle_identifier: getBundleIdentifier(for: record.applicationToken),
                approved_date: ISO8601DateFormatter().string(from: record.approvedDate),
                duration_minutes: record.durationMinutes,
                request_id: record.requestId
            )
        }
        
        try await client
            .from("usage_records")
            .insert(supabaseRecords)
            .execute()
        
        print("[SupabaseManager] Successfully synced \(records.count) usage records")
    }
    
    // Sync usage statistics to Supabase
    func syncUsageStatistics(_ statistics: [UsageStatistics]) async throws {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        guard let deviceId = await UIDevice.current.identifierForVendor?.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No device ID available"])
        }
        
        let deviceName = await UIDevice.current.name
        
        // Get child name from device registration
        let childName = try? await getChildNameForDevice(deviceId: deviceId)
        
        for stat in statistics {
            let payload = SupabaseUsageStatisticsInsert(
                user_account_id: userId,
                child_device_id: deviceId,
                child_device_name: deviceName,
                child_name: childName,
                app_name: stat.appName,
                bundle_identifier: getBundleIdentifier(for: stat.applicationToken),
                total_requests_approved: stat.totalRequestsApproved,
                total_time_approved_minutes: stat.totalTimeApprovedMinutes,
                last_approved_date: ISO8601DateFormatter().string(from: stat.lastApprovedDate ?? Date())
            )
            
            // Upsert to handle both insert and update
            try await client
                .from("usage_statistics")
                .upsert([payload], onConflict: "user_account_id,child_device_id,app_name")
                .execute()
        }
        
        print("[SupabaseManager] Successfully synced \(statistics.count) usage statistics")
    }
    
    // Fetch usage statistics from Supabase for specific date range
    func fetchUsageStatistics(for dateRange: DateRange) async throws -> [SupabaseUsageStatistics] {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        guard let deviceId = await UIDevice.current.identifierForVendor?.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No device ID available"])
        }
        
        let (startDate, endDate) = getDateRangeBounds(dateRange)
        
        let response = try await client
            .rpc("get_usage_statistics_for_range", params: [
                "p_user_id": userId,
                "p_child_device_id": deviceId,
                "p_start_date": ISO8601DateFormatter().string(from: startDate),
                "p_end_date": ISO8601DateFormatter().string(from: endDate)
            ] as [String: String])
            .execute()
        
        let data = response.data
        return try JSONDecoder().decode([SupabaseUsageStatistics].self, from: data)
    }
    
    // Helper method to get date range bounds
    private func getDateRangeBounds(_ range: DateRange) -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch range {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return (start, end)
        case .yesterday:
            let start = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            let end = calendar.startOfDay(for: now)
            return (start, end)
        case .thisWeek:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? now
            return (weekStart, weekEnd)
        case .lastWeek:
            let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (lastWeekStart, thisWeekStart)
        case .thisMonth:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
            return (monthStart, monthEnd)
        case .lastMonth:
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let thisMonthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (lastMonthStart, thisMonthStart)
        case .custom(let start, let end):
            return (start, end)
        case .allTime:
            let distantPast = Date.distantPast
            let distantFuture = Date.distantFuture
            return (distantPast, distantFuture)
        }
    }
    
    // Helper method to get bundle identifier from ApplicationToken
    private func getBundleIdentifier(for applicationToken: ApplicationToken) -> String {
        // For now, return a placeholder. In a real implementation, you might need to
        // store a mapping of ApplicationToken to bundle identifier, or use a different approach
        return "com.placeholder.app" // This will need to be enhanced in future phases
    }
    
    // MARK: - Multi-Child Support Methods
    
    // Register child device with name
    func registerChildDevice(deviceId: String, deviceName: String, childName: String, deviceToken: String? = nil) async throws -> String {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        // Ensure userId is a valid UUID format
        guard let uuid = UUID(uuidString: userId) else {
            throw NSError(domain: "SupabaseManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID format"])
        }
        
        let params: [String: String] = [
            "p_user_account_id": uuid.uuidString,
            "p_device_id": deviceId,
            "p_device_name": deviceName,
            "p_child_name": childName,
            "p_device_token": deviceToken ?? ""
        ]
        
        print("[SupabaseManager] Registering child device with params: \(params)")
        
        let response = try await client
            .rpc("register_child_device_with_name", params: params)
            .execute()
        
        let data = response.data
        print("[SupabaseManager] Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
        
        // Try to parse as JSON object first (for function name wrapper)
        if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let returnedDeviceId = result["register_child_device_with_name"] as? String {
            print("[SupabaseManager] Successfully registered child device: \(childName)")
            return returnedDeviceId
        }
        
        // If that fails, try to parse as plain string (direct UUID return)
        if let responseString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            print("[SupabaseManager] Successfully registered child device: \(childName)")
            return responseString
        }
        
        throw NSError(domain: "SupabaseManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format from register_child_device_with_name"])
    }
    
    // Register parent device
    func registerParentDevice(deviceId: String, deviceName: String, deviceToken: String? = nil) async throws -> String {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        // Ensure userId is a valid UUID format
        guard let uuid = UUID(uuidString: userId) else {
            throw NSError(domain: "SupabaseManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID format"])
        }
        
        let response = try await client
            .rpc("register_parent_device", params: [
                "p_user_account_id": uuid.uuidString,
                "p_device_id": deviceId,
                "p_device_name": deviceName,
                "p_device_token": deviceToken ?? ""
            ] as [String: String])
            .execute()
        
        let data = response.data
        print("[SupabaseManager] Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
        
        // Try to parse as JSON object first (for function name wrapper)
        if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let returnedDeviceId = result["register_parent_device"] as? String {
            print("[SupabaseManager] Successfully registered parent device")
            return returnedDeviceId
        }
        
        // If that fails, try to parse as plain string (direct UUID return)
        if let responseString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            print("[SupabaseManager] Successfully registered parent device")
            return responseString
        }
        
        throw NSError(domain: "SupabaseManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format from register_parent_device"])
    }
    
    // Get family summary (all children for a parent)
    func getFamilySummary() async throws -> [SupabaseFamilySummary] {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        print("[SupabaseManager] getFamilySummary - User ID: \(userId)")
        
        // Convert to lowercase to match database storage
        let normalizedUserId = userId.lowercased()
        print("[SupabaseManager] getFamilySummary - Normalized User ID: \(normalizedUserId)")
        
        let response = try await client
            .rpc("get_family_summary", params: ["p_user_id": normalizedUserId] as [String: String])
            .execute()
        
        let data = response.data
        print("[SupabaseManager] getFamilySummary - Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
        
        let summary = try JSONDecoder().decode([SupabaseFamilySummary].self, from: data)
        print("[SupabaseManager] getFamilySummary - Decoded \(summary.count) summary items")
        
        return summary
    }
    
    // Get all children for a parent
    func getChildrenForParent() async throws -> [SupabaseChildDevice] {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        print("[SupabaseManager] getChildrenForParent - User ID: \(userId)")
        
        // Convert to lowercase to match database storage
        let normalizedUserId = userId.lowercased()
        print("[SupabaseManager] getChildrenForParent - Normalized User ID: \(normalizedUserId)")
        
        let response = try await client
            .rpc("get_children_for_parent", params: ["p_user_id": normalizedUserId] as [String: String])
            .execute()
        
        let data = response.data
        print("[SupabaseManager] getChildrenForParent - Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
        
        let children = try JSONDecoder().decode([SupabaseChildDevice].self, from: data)
        print("[SupabaseManager] getChildrenForParent - Decoded \(children.count) children")
        
        return children
    }
    
    // Get child-specific statistics
    func getChildStatistics(childDeviceId: String, dateRange: DateRange) async throws -> [SupabaseUsageStatistics] {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        let (startDate, endDate) = getDateRangeBounds(dateRange)
        
        let response = try await client
            .rpc("get_child_statistics", params: [
                "p_user_id": userId,
                "p_child_device_id": childDeviceId,
                "p_start_date": ISO8601DateFormatter().string(from: startDate),
                "p_end_date": ISO8601DateFormatter().string(from: endDate)
            ] as [String: String])
            .execute()
        
        let data = response.data
        return try JSONDecoder().decode([SupabaseUsageStatistics].self, from: data)
    }
    
    // Link parent and child devices
    func linkParentChildDevices(parentDeviceId: String, childDeviceId: String) async throws -> String {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        // Ensure userId is a valid UUID format
        guard let uuid = UUID(uuidString: userId) else {
            throw NSError(domain: "SupabaseManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID format"])
        }
        
        let response = try await client
            .rpc("link_parent_child_devices", params: [
                "p_user_account_id": uuid.uuidString,
                "p_parent_device_id": parentDeviceId,
                "p_child_device_id": childDeviceId
            ] as [String: String])
            .execute()
        
        let data = response.data
        print("[SupabaseManager] Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
        
        // Try to parse as JSON object first (for function name wrapper)
        if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let linkId = result["link_parent_child_devices"] as? String {
            print("[SupabaseManager] Successfully linked parent and child devices")
            return linkId
        }
        
        // If that fails, try to parse as plain string (direct UUID return)
        if let responseString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            print("[SupabaseManager] Successfully linked parent and child devices")
            return responseString
        }
        
        throw NSError(domain: "SupabaseManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format from link_parent_child_devices"])
    }
    
    // Test database connection and function call
    func testDatabaseConnection() async throws -> String {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        print("[SupabaseManager] Testing database connection with user ID: \(userId)")
        
        // Test a simple query to verify connection
        _ = try await client
            .from("devices")
            .select("count")
            .limit(1)
            .execute()
        
        print("[SupabaseManager] Database connection test successful")
        return "Connection OK"
    }
    
    // Helper method to get child name for a device
    private func getChildNameForDevice(deviceId: String) async throws -> String? {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        let response = try await client
            .from("devices")
            .select("child_name")
            .eq("device_id", value: deviceId)
            .eq("user_account_id", value: userId)
            .single()
            .execute()
        
        let data = response.data
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return result?["child_name"] as? String
    }
    
    // MARK: - Shield Settings Management
    
    /// Sync a single shield setting to Supabase
    func syncShieldSetting(_ setting: SupabaseShieldSettingInsert) async throws -> String {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        print("[SupabaseManager] Syncing shield setting for app: \(setting.app_name)")
        
        let response = try await client
            .rpc("upsert_child_shield_setting", params: [
                "p_user_account_id": userId,
                "p_child_device_id": setting.child_device_id,
                "p_child_name": setting.child_name,
                "p_app_name": setting.app_name,
                "p_bundle_identifier": setting.bundle_identifier,
                "p_is_shielded": setting.is_shielded ? "true" : "false",
                "p_shield_type": setting.shield_type,
                "p_unlock_expiry": setting.unlock_expiry
            ] as [String: String?])
            .execute()
        
        let data = response.data
        print("[SupabaseManager] Shield setting sync response: \(String(data: data, encoding: .utf8) ?? "nil")")
        
        // Try to parse as JSON object first
        if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let settingId = result["upsert_child_shield_setting"] as? String {
            print("[SupabaseManager] Successfully synced shield setting: \(settingId)")
            return settingId
        }
        
        // If that fails, try to parse as plain string
        if let responseString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            print("[SupabaseManager] Successfully synced shield setting: \(responseString)")
            return responseString
        }
        
        throw NSError(domain: "SupabaseManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format from upsert_child_shield_setting"])
    }
    
    /// Sync multiple shield settings to Supabase
    func syncShieldSettings(_ settings: [SupabaseShieldSettingInsert]) async throws -> [String] {
        print("[SupabaseManager] Syncing \(settings.count) shield settings")
        
        var results: [String] = []
        var errors: [Error] = []
        
        // Process settings in parallel with error handling
        await withTaskGroup(of: (Int, Result<String, Error>).self) { group in
            for (index, setting) in settings.enumerated() {
                group.addTask {
                    do {
                        let result = try await self.syncShieldSetting(setting)
                        return (index, .success(result))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            
            for await (index, result) in group {
                switch result {
                case .success(let settingId):
                    results.append(settingId)
                    print("[SupabaseManager] Successfully synced shield setting \(index): \(settingId)")
                case .failure(let error):
                    errors.append(error)
                    print("[SupabaseManager] Failed to sync shield setting \(index): \(error)")
                }
            }
        }
        
        // If any errors occurred, throw the first one
        if let firstError = errors.first {
            throw firstError
        }
        
        print("[SupabaseManager] Successfully synced all \(results.count) shield settings")
        return results
    }
    
    /// Get shield settings for a specific child device
    func getChildShieldSettings(for childDeviceId: String) async throws -> [SupabaseShieldSetting] {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        print("[SupabaseManager] Getting shield settings for child device: \(childDeviceId)")
        
        let response = try await client
            .rpc("get_child_shield_settings", params: [
                "p_user_account_id": userId,
                "p_child_device_id": childDeviceId
            ] as [String: String])
            .execute()
        
        let data = response.data
        print("[SupabaseManager] Shield settings response: \(String(data: data, encoding: .utf8) ?? "nil")")
        
        let settings = try JSONDecoder().decode([SupabaseShieldSetting].self, from: data)
        print("[SupabaseManager] Retrieved \(settings.count) shield settings for child device: \(childDeviceId)")
        
        return settings
    }
    
    /// Get all shield settings for all children of the current user
    func getAllChildrenShieldSettings() async throws -> [SupabaseShieldSetting] {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        print("[SupabaseManager] Getting all children shield settings for user: \(userId)")
        
        let response = try await client
            .rpc("get_all_children_shield_settings", params: [
                "p_user_account_id": userId
            ] as [String: String])
            .execute()
        
        let data = response.data
        print("[SupabaseManager] All shield settings response: \(String(data: data, encoding: .utf8) ?? "nil")")
        
        let responseString = String(data: data, encoding: .utf8) ?? "nil"
        print("[SupabaseManager] All shield settings response: \(responseString)")
        
        let settings = try JSONDecoder().decode([SupabaseShieldSetting].self, from: data)
        print("[SupabaseManager] Retrieved \(settings.count) total shield settings for user: \(userId)")
        
        return settings
    }
    
    /// Delete a shield setting from Supabase by ID
    func deleteShieldSetting(settingId: String) async throws -> Bool {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        print("[SupabaseManager] Deleting shield setting by ID: \(settingId)")
        
        _ = try await client
            .from("child_shield_settings")
            .delete()
            .eq("id", value: settingId)
            .eq("user_account_id", value: userId)
            .execute()
        
        print("[SupabaseManager] Successfully deleted shield setting by ID: \(settingId)")
        return true
    }
    
    /// Delete a shield setting from Supabase by app bundle identifier and device info
    func deleteShieldSettingByApp(bundleIdentifier: String, childDeviceId: String) async throws -> Bool {
        await restoreSessionFromAppGroup()
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        
        print("[SupabaseManager] Deleting shield setting for app bundle: \(bundleIdentifier) on device: \(childDeviceId)")
        
        _ = try await client
            .from("child_shield_settings")
            .delete()
            .eq("bundle_identifier", value: bundleIdentifier)
            .eq("child_device_id", value: childDeviceId)
            .eq("user_account_id", value: userId)
            .execute()
        
        print("[SupabaseManager] Successfully deleted shield setting for app bundle: \(bundleIdentifier)")
        return true
    }
}
