//
//  ZapScreenManager.swift
//  ZapScreen
//
//  Created by tongteknai on 25/4/25.
//

import Foundation
import SwiftUI

// Response types
struct DeviceRegistrationResponse: Codable {
    let success: Bool
    let device: Device
    
    struct Device: Codable {
        let deviceToken: String
        let deviceId: String
        let deviceName: String
        let isParent: Bool
        let id: String
        let createdAt: String
        
        // Computed property to convert string to date
        var createdAtDate: Date? {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: createdAt)
        }
        
        enum CodingKeys: String, CodingKey {
            case deviceToken
            case deviceId
            case deviceName
            case isParent
            case id = "_id"
            case createdAt
        }
    }
}

struct DeviceCheckResponse: Codable {
    let success: Bool
    let isRegistered: Bool
    let isParent: Bool?
    let deviceToken: String?
    let deviceName: String?
    let lastUpdated: String?
    
    // Add computed property to convert string to date if needed
    var lastUpdatedDate: Date? {
        guard let dateString = lastUpdated else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }
    
}

struct DeviceListResponse: Codable {
    let success: Bool
    let devices: [Device]
    
    struct Device: Codable, Identifiable {
        let deviceToken: String
        let deviceId: String
        var deviceName: String
        var isParent: Bool
        let createdAt: String
        
        // Add id property for Identifiable conformance
        var id: String { deviceId }
        
        // Computed property to convert string to date
        var createdAtDate: Date? {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: createdAt)
        }
    }
}

struct DeviceRelationshipResponse: Codable {
    let success: Bool
    let message: String
    let relationship: Relationship
    
    struct Relationship: Codable {
        let parentDeviceId: String
        let childDeviceId: String
        let createdAt: String
        
        var createdAtDate: Date? {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: createdAt)
        }
    }
}

class ZapScreenManager {
    // Helper to fetch userId from group UserDefaults
    private let groupUserDefaultsId = "group.com.ntt.ZapScreen.data"
    private func fetchUserIdentifier() -> String? {
        guard let userDefaults = UserDefaults(suiteName: groupUserDefaultsId) else {
            print("[ZapScreenManager] Failed to access group UserDefaults for identifier extraction.")
            return nil
        }
        let userId = userDefaults.string(forKey: "zap_userId")
        print("[ZapScreenManager] fetchUserIdentifier -> userId: \(userId ?? "<nil>")")
        return userId
    }

    /// Injects userId as HTTP header into a URLRequest
    private func injectUserHeaders(into request: inout URLRequest) {
        if let userId = fetchUserIdentifier() {
            request.setValue(userId, forHTTPHeaderField: "user-account-id")
        }
    }

    /// Saves the user ID to group UserDefaults upon login.
    /// - Parameter userId: The user ID to save.
    func saveUserLoginInfo(userId: String) {
        guard let userDefaults = UserDefaults(suiteName: groupUserDefaultsId) else {
            print("Failed to access group UserDefaults with identifier: \(groupUserDefaultsId)")
            return
        }
        // Check if userId already exists
        if let existingUserId = userDefaults.string(forKey: "zap_userId") {
            print("userId \(existingUserId) already exists in group UserDefaults. Not overwriting.")
            return
        }
        userDefaults.set(userId, forKey: "zap_userId")
        userDefaults.synchronize() // Optional, ensures immediate write
        print("Saved userId \(userId) to group UserDefaults")
    }


    static let shared = ZapScreenManager()
    private let baseURL = "https://zap-screen-server.onrender.com"
//    private let baseURL = "http://192.168.50.201:3000"
//    private let baseURL = "http://172.20.10.2:3000"
    /// Checks and sets up device relationships between all parents and children.
    /// For every parent-child pair, triggers updateDeviceRelationship if not already paired.
    /// Calls completion when all updates are triggered.
    /// Fetches all existing parent-child relationships from the server.
    private func fetchAllDeviceRelationships(completion: @escaping (Set<String>) -> Void) {
        let url = URL(string: "\(baseURL)/api/relationships/list")!
        var request = URLRequest(url: url)
        injectUserHeaders(into: &request)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, response, error in
            var existingPairs = Set<String>()
            defer { completion(existingPairs) }
            guard let data = data, error == nil else { return }
            struct RelationshipListResponse: Codable {
                let success: Bool
                let relationships: [DeviceRelationshipResponse.Relationship]
            }
            do {
                let decoded = try JSONDecoder().decode(RelationshipListResponse.self, from: data)
                for rel in decoded.relationships {
                    let key = rel.parentDeviceId + ":" + rel.childDeviceId
                    existingPairs.insert(key)
                }
            } catch {
                print("Failed to decode relationships list: \(error)")
            }
        }.resume()
    }

    func checkDeviceRelationship(completion: (([(parent: String, child: String)]) -> Void)? = nil) {
        getAllDevices { result in
            switch result {
            case .success(let response):
                let parents = response.devices.filter { $0.isParent }
                let children = response.devices.filter { !$0.isParent }
                guard !parents.isEmpty, !children.isEmpty else {
                    print("No parent or child devices found. Skipping relationship setup.")
                    completion?([])
                    return
                }
                self.fetchAllDeviceRelationships { existingPairs in
                    var triggeredPairs: Set<String> = existingPairs
                    var relationships: [(parent: String, child: String)] = []
                    let group = DispatchGroup()
                    for parent in parents {
                        for child in children {
                            let pairKey = parent.deviceId + ":" + child.deviceId
                            if !triggeredPairs.contains(pairKey) {
                                triggeredPairs.insert(pairKey)
                                relationships.append((parent: parent.deviceId, child: child.deviceId))
                                group.enter()
                                self.updateDeviceRelationship(parentDeviceId: parent.deviceId, childDeviceId: child.deviceId) { _ in
                                    group.leave()
                                }
                            }
                        }
                    }
                    group.notify(queue: .main) {
                        print("All parent-child relationships updated (new only).")
                        completion?(relationships)
                    }
                }
            case .failure(let error):
                print("Failed to fetch devices for relationship check: \(error)")
                completion?([])
            }
        }
    }
    
    func getAllDevices(completion: @escaping (Result<DeviceListResponse, Error>) -> Void) {
            let url = URL(string: "\(baseURL)/api/devices/list")!
            var request = URLRequest(url: url)
        injectUserHeaders(into: &request)
            request.httpMethod = "GET"
            
            print("Fetching all devices from: \(url)")

        URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Fetch failed: \(error)")
                    completion(.failure(error))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Fetch status: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                // Print raw response for debugging
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("Raw response: \(rawResponse)")
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(DeviceListResponse.self, from: data)
                    print("Successfully fetched \(response.devices.count) devices")
                    completion(.success(response))
                } catch {
                    print("Decoding failed: \(error)")
                    completion(.failure(error))
                }
            }.resume()
    }
    
    func checkDeviceRegistration(deviceId: String, completion: @escaping (Result<DeviceCheckResponse, Error>) -> Void) {
          let url = URL(string: "\(baseURL)/api/devices/check/\(deviceId)")!
          var request = URLRequest(url: url)
        injectUserHeaders(into: &request)
          request.httpMethod = "GET"
          
          print("Checking device registration for ID: \(deviceId)")

        URLSession.shared.dataTask(with: request) { data, response, error in
              if let error = error {
                  print("Check failed: \(error)")
                  completion(.failure(error))
                  return
              }
              
              if let httpResponse = response as? HTTPURLResponse {
                  print("Check status: \(httpResponse.statusCode)")
                  
                  guard (200...299).contains(httpResponse.statusCode) else {
                          print("Server error: \(httpResponse.statusCode)")
                          if let data = data, let html = String(data: data, encoding: .utf8) {
                              print("Received HTML/Error response: \(html)")
                          }
                          return
                      }
              }
              
              guard let data = data else {
                  completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                  return
              }
              
              // Print raw response for debugging
              if let rawResponse = String(data: data, encoding: .utf8) {
                  print("Raw response: \(rawResponse)")
              }
              
              do {
                  let decoder = JSONDecoder()
                  let response = try decoder.decode(DeviceCheckResponse.self, from: data)
                  print("Decoded response: \(response)")
                  completion(.success(response))
              } catch {
                  print("Decoding failed: \(error)")
                  completion(.failure(error))
              }
          }.resume()
      }
      
      func handleDeviceRegistration(deviceToken: String, completion: @escaping (Bool) -> Void) {
        let groupDefaults = UserDefaults(suiteName: groupUserDefaultsId)
          let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
          
          checkDeviceRegistration(deviceId: deviceId) { result in
              switch result {
              case .success(let response):
                groupDefaults?.set(deviceId, forKey: "ZapDeviceId")
                if response.isRegistered {
                    print("Device already registered. Parent status: \(String(describing: response.isParent))")
                    if response.deviceToken != deviceToken {
                        // Update token if changed
                        self.registerDevice(
                            deviceToken: deviceToken,
                            deviceId: deviceId,
                            isParent: response.isParent ?? true
                        ) { _ in
                            completion(response.isParent ?? true)
                        }
                    } else {
                        completion(response.isParent ?? true)
                    }
                } else {
                    // Register as new device
                    self.registerDevice(
                        deviceToken: deviceToken,
                        deviceId: deviceId,
                        isParent: true  // or false for child devices
                    ) { result in
                        switch result {
                        case .success:
                            groupDefaults?.set(deviceId, forKey: "ZapDeviceId")
                            completion(true)  // or false for child devices
                        case .failure:
                            completion(false)
                        }
                    }
                }
                  
              case .failure:
                  completion(false)
              }
          }
      }
    
    func registerDevice(deviceToken: String, deviceId: String, isParent: Bool, completion: @escaping (Result<DeviceRegistrationResponse, Error>) -> Void)  {
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else { return }
        let deviceName = UIDevice.current.name
        let url = URL(string: "\(baseURL)/api/devices/register")!
        var request = URLRequest(url: url)
        injectUserHeaders(into: &request)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "deviceToken": deviceToken,
            "deviceId": deviceId,
            "deviceName": deviceName,
            "isParent": isParent
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        print("Registering device with URL: \(url)")
        print("Payload: \(payload)")
        
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

URLSession.shared.dataTask(with: request) { data, response, error in
    // --- BEGIN VERBOSE RESPONSE LOGGING ---
    if let httpResponse = response as? HTTPURLResponse {
        print("[ZapScreenManager] Received response:")
        print("Status code: \(httpResponse.statusCode)")
        print("Headers: \(httpResponse.allHeaderFields)")
    }
    if let data = data, let responseBody = String(data: data, encoding: .utf8) {
        print("Body: \(responseBody)")
    } else {
        print("Body: <none>")
    }
    if let error = error {
        print("[ZapScreenManager] Error: \(error)")
    }
    // --- END VERBOSE RESPONSE LOGGING ---
            if let error = error {
                print("Registration failed: \(error)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Registration status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Print raw response for debugging
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw response: \(rawResponse)")
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let response = try decoder.decode(DeviceRegistrationResponse.self, from: data)
                print("Registration successful: \(response)")
                completion(.success(response))
            } catch {
                print("Decoding failed: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func sendUnlockEvent(bundleIdentifier: String) {
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else { return }
        
        let url = URL(string: "\(baseURL)/api/notifications/unlock-event")!
        var request = URLRequest(url: url)
        injectUserHeaders(into: &request)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "childDeviceId": deviceId,
            "bundleIdentifier": bundleIdentifier
        ]
        
        print("Trigger Unlock Event")
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
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

URLSession.shared.dataTask(with: request) { data, response, error in
    // --- BEGIN VERBOSE RESPONSE LOGGING ---
    if let httpResponse = response as? HTTPURLResponse {
        print("[ZapScreenManager] Received response:")
        print("Status code: \(httpResponse.statusCode)")
        print("Headers: \(httpResponse.allHeaderFields)")
    }
    if let data = data, let responseBody = String(data: data, encoding: .utf8) {
        print("Body: \(responseBody)")
    } else {
        print("Body: <none>")
    }
    if let error = error {
        print("[ZapScreenManager] Error: \(error)")
    }
    // --- END VERBOSE RESPONSE LOGGING ---
            if let error = error {
                print("Unlock event failed: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Unlock event status: \(httpResponse.statusCode)")
            }
        }.resume()
    }
    
    func updateDeviceParentStatus(deviceId: String, isParent: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/api/devices/\(deviceId)/parent-status")!
        var request = URLRequest(url: url)
        injectUserHeaders(into: &request)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "isParent": isParent
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        print("Updating device parent status for ID: \(deviceId)")
        print("New parent status: \(isParent)")
        


URLSession.shared.dataTask(with: request) { data, response, error in

            if let error = error {
                print("Update failed: \(error)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Update status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    completion(.success(()))
                } else {
                    completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to update device parent status"])))
                }
            }
        }.resume()
    }

    // MARK: - Send Lock Command
    func sendUnLockCommand(to childDeviceId: String, bundleIdentifier: String, time minutes: Int,completion: @escaping (Result<Void, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/api/notifications/devices/\(childDeviceId)/unlock")!
        var request = URLRequest(url: url)
        injectUserHeaders(into: &request)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "bundleIdentifier": bundleIdentifier,
            "minutes" : minutes
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        print("Sending lock command to device ID: \(childDeviceId)")
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

        URLSession.shared.dataTask(with: request) { data, response, error in
    // --- BEGIN VERBOSE RESPONSE LOGGING ---
    if let httpResponse = response as? HTTPURLResponse {
        print("[ZapScreenManager] Received response:")
        print("Status code: \(httpResponse.statusCode)")
        print("Headers: \(httpResponse.allHeaderFields)")
    }
    if let data = data, let responseBody = String(data: data, encoding: .utf8) {
        print("Body: \(responseBody)")
    } else {
        print("Body: <none>")
    }
    if let error = error {
        print("[ZapScreenManager] Error: \(error)")
    }
    // --- END VERBOSE RESPONSE LOGGING ---
            if let error = error {
                print("UnLock command failed: \(error)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("UnLock command status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    completion(.success(()))
                } else {
                    completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to send Unlock command"])))
                }
            }
        }.resume()
    }
    
    func updateDeviceName(deviceId: String, deviceName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/api/devices/\(deviceId)")!
        var request = URLRequest(url: url)
        injectUserHeaders(into: &request)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "deviceName": deviceName
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        print("Updating device name for ID: \(deviceId)")
        print("New device name: \(deviceName)")
        
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

URLSession.shared.dataTask(with: request) { data, response, error in
    // --- BEGIN VERBOSE RESPONSE LOGGING ---
    if let httpResponse = response as? HTTPURLResponse {
        print("[ZapScreenManager] Received response:")
        print("Status code: \(httpResponse.statusCode)")
        print("Headers: \(httpResponse.allHeaderFields)")
    }
    if let data = data, let responseBody = String(data: data, encoding: .utf8) {
        print("Body: \(responseBody)")
    } else {
        print("Body: <none>")
    }
    if let error = error {
        print("[ZapScreenManager] Error: \(error)")
    }
    // --- END VERBOSE RESPONSE LOGGING ---
            if let error = error {
                print("Update failed: \(error)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Update status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    completion(.success(()))
                } else {
                    completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to update device name"])))
                }
            }
        }.resume()
    }
    
    func updateDeviceRelationship(parentDeviceId: String, childDeviceId: String, completion: @escaping (Result<DeviceRelationshipResponse, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/api/relationships/link")!
        var request = URLRequest(url: url)
        injectUserHeaders(into: &request)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "parentDeviceId": parentDeviceId,
            "childDeviceId": childDeviceId
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        print("Creating relationship with URL: \(url)")
        print("Payload: \(payload)")
        
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

URLSession.shared.dataTask(with: request) { data, response, error in
    // --- BEGIN VERBOSE RESPONSE LOGGING ---
    if let httpResponse = response as? HTTPURLResponse {
        print("[ZapScreenManager] Received response:")
        print("Status code: \(httpResponse.statusCode)")
        print("Headers: \(httpResponse.allHeaderFields)")
    }
    if let data = data, let responseBody = String(data: data, encoding: .utf8) {
        print("Body: \(responseBody)")
    } else {
        print("Body: <none>")
    }
    if let error = error {
        print("[ZapScreenManager] Error: \(error)")
    }
    // --- END VERBOSE RESPONSE LOGGING ---
            if let error = error {
                print("Relationship creation failed: \(error)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Relationship creation status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Print raw response for debugging
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw response: \(rawResponse)")
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(DeviceRelationshipResponse.self, from: data)
                print("Successfully created relationship")
                completion(.success(response))
            } catch {
                print("Decoding failed: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
}
