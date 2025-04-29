import Foundation
import SwiftUI

@MainActor
// Create a view model to manage the device list
class DevicesListViewModel: ObservableObject {
    @Published var devices: [DeviceListResponse.Device] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func fetchDevices() {
        isLoading = true
        ZapScreenManager.shared.getAllDevices { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let response):
                    self?.devices = response.devices
                    self?.error = nil
                case .failure(let error):
                    self?.error = error
                    print("Error fetching devices: \(error)")
                }
            }
        }
    }
    
    func updateDeviceParentStatus(deviceId: String, isParent: Bool) {
        isLoading = true
        ZapScreenManager.shared.updateDeviceParentStatus(deviceId: deviceId, isParent: isParent) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    // Update local device state
                    if let index = self?.devices.firstIndex(where: { $0.deviceId == deviceId }) {
                        self?.devices[index].isParent = isParent
                    }
                    self?.error = nil
                case .failure(let error):
                    self?.error = error
                    print("Error updating device parent status: \(error)")
                }
            }
        }
    }
    
    func updateDeviceName(deviceId: String, deviceName: String) {
        isLoading = true
        ZapScreenManager.shared.updateDeviceName(deviceId: deviceId, deviceName: deviceName) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    // Update local device state
                    if let index = self?.devices.firstIndex(where: { $0.deviceId == deviceId }) {
                        self?.devices[index].deviceName = deviceName
                    }
                    self?.error = nil
                case .failure(let error):
                    self?.error = error
                    print("Error updating device name: \(error)")
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
