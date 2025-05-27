import Foundation
import SwiftUI

@MainActor
// Create a view model to manage the device list
class DevicesListViewModel: ObservableObject {
    @Published var devices: [SupabaseDevice] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func fetchDevices() {
        isLoading = true
        Task {
            do {
                let allDevices = try await SupabaseManager.shared.fetchAllDevices()
                await MainActor.run {
                    self.devices = allDevices
                    self.isLoading = false
                    self.error = nil
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = error
                    print("Error fetching devices: \(error)")
                }
            }
        }
    }
    
    func updateDeviceParentStatus(deviceId: String, isParent: Bool) {
        isLoading = true
        Task {
            do {
                let updatedDevice = try await SupabaseManager.shared.updateDeviceParentStatus(isParent: isParent)
                await MainActor.run {
                    if let index = self.devices.firstIndex(where: { $0.device_id == deviceId }) {
                        self.devices[index] = updatedDevice
                    }
                    self.isLoading = false
                    self.error = nil
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = error
                    print("Error updating device parent status: \(error)")
                }
            }
        }
    }
    
    func updateDeviceName(deviceId: String, deviceName: String) {
        isLoading = true
        Task {
            do {
                let updatedDevice = try await SupabaseManager.shared.updateDeviceName(newName: deviceName)
                await MainActor.run {
                    if let index = self.devices.firstIndex(where: { $0.device_id == deviceId }) {
                        self.devices[index] = updatedDevice
                    }
                    self.isLoading = false
                    self.error = nil
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = error
                    print("Error updating device name: \(error)")
                }
            }
        }
    }
        
    func deleteDevice(deviceId: String) {
        isLoading = true
        Task {
            do {
                let _ = try await SupabaseManager.shared.deleteDevice(deviceId: deviceId)
                await MainActor.run {
                    self.devices.removeAll { $0.device_id == deviceId }
                    self.isLoading = false
                    self.error = nil
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = error
                    print("Error deleting device: \(error)")
                }
            }
        }
    }
    
    func updateDeviceRelationship(parentDeviceId: String, childDeviceId: String) {
        isLoading = true
        ZapScreenManager.shared.updateDeviceRelationship(parentDeviceId: parentDeviceId, childDeviceId: childDeviceId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let response):
                    print("Successfully created relationship: \(response.message)")
                    self?.error = nil
                case .failure(let error):
                    self?.error = error
                    print("Error creating relationship: \(error)")
                }
            }
        }
    }
}
