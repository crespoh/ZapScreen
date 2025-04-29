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

class ZapScreenManager {
    static let shared = ZapScreenManager()
    private let baseURL = "https://zap-screen-server.onrender.com"
//    private let baseURL = "http://192.168.50.201:3000"
//    private let baseURL = "http://172.20.10.2:3000"

    
    func getAllDevices(completion: @escaping (Result<DeviceListResponse, Error>) -> Void) {
            let url = URL(string: "\(baseURL)/api/devices/list")!
            var request = URLRequest(url: url)
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
          let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
          
          checkDeviceRegistration(deviceId: deviceId) { result in
              switch result {
              case .success(let response):
                  if response.isRegistered {
                      print("Device already registered. Parent status: \(response.isParent)")
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
        
        URLSession.shared.dataTask(with: request) { data, response, error in
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
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "childDeviceId": deviceId,
            "bundleIdentifier": bundleIdentifier
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
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
    
    func updateDeviceName(deviceId: String, deviceName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/api/devices/\(deviceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "deviceName": deviceName
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        print("Updating device name for ID: \(deviceId)")
        print("New device name: \(deviceName)")
        
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
                    completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to update device name"])))
                }
            }
        }.resume()
    }
}
