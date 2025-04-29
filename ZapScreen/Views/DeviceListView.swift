import SwiftUI

// Example SwiftUI view to display the device list
struct DeviceListView: View {
    @StateObject private var viewModel = DevicesListViewModel()
    @State private var editedDevices: [String: (isParent: Bool, deviceName: String)] = [:] // Track edited states
    @State private var updateErrors: [String: String] = [:]
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView("Loading devices...")
                } else {
                    ForEach(viewModel.devices) { device in
                        DeviceRow(
                            device: device,
                            viewModel: viewModel,
                            editedDevices: $editedDevices
                        )
                    }
                }
            }
            .navigationTitle("Devices")
            .refreshable {
                viewModel.fetchDevices()
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "Unknown error")
            }
            .onAppear {
                viewModel.fetchDevices()
            }
            .toolbar {
                if !editedDevices.isEmpty {
                    Button("Save Changes") {
                        saveChanges()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        let dispatchGroup = DispatchGroup()
        var updateErrors: [String] = []
        
        // First update all device changes
        for (deviceId, changes) in editedDevices {
            dispatchGroup.enter()
            
            // Update device name
            viewModel.updateDeviceName(deviceId: deviceId, deviceName: changes.deviceName)
            
            // Update parent status
            viewModel.updateDeviceParentStatus(deviceId: deviceId, isParent: changes.isParent)
            
            // Update local state
            if let index = viewModel.devices.firstIndex(where: { $0.deviceId == deviceId }) {
                viewModel.devices[index].deviceName = changes.deviceName
                viewModel.devices[index].isParent = changes.isParent
            }
            
            dispatchGroup.leave()
        }
        
        // Wait for all updates to complete
        dispatchGroup.notify(queue: .main) { [weak viewModel] in
            guard let viewModel = viewModel else { return }
            
            if !updateErrors.isEmpty {
                // Show error alert if any updates failed
                viewModel.error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: updateErrors.joined(separator: "\n")])
                return
            }
            
            // Get all parent and child devices from the updated local state
            let parentDevices = viewModel.devices.filter { $0.isParent }
            let childDevices = viewModel.devices.filter { !$0.isParent }
            
            print("Parent devices after update:", parentDevices)
            print("Child devices after update:", childDevices)
            
            // Only proceed if we have at least one parent and one child
            if !parentDevices.isEmpty && !childDevices.isEmpty {
                print("Trigger Child Parent relationship")
                // Create relationships between all parents and children
                for parent in parentDevices {
                    for child in childDevices {
                        viewModel.updateDeviceRelationship(parentDeviceId: parent.deviceId, childDeviceId: child.deviceId)
                    }
                }
            }
            
            editedDevices.removeAll()
        }
    }
}

struct DeviceRow: View {
    let device: DeviceListResponse.Device
    @ObservedObject var viewModel: DevicesListViewModel
    @Binding var editedDevices: [String: (isParent: Bool, deviceName: String)]
    @State private var isEditingName = false
    @State private var editedName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if isEditingName {
                    TextField("Device Name", text: $editedName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            if !editedName.isEmpty {
                                // Update the edited devices dictionary instead of making an immediate API call
                                var currentChanges = editedDevices[device.deviceId] ?? (isParent: device.isParent, deviceName: device.deviceName)
                                currentChanges.deviceName = editedName
                                editedDevices[device.deviceId] = currentChanges
                            }
                            isEditingName = false
                        }
                } else {
                    Text(editedDevices[device.deviceId]?.deviceName ?? device.deviceName)
                        .font(.headline)
                        .onTapGesture {
                            editedName = editedDevices[device.deviceId]?.deviceName ?? device.deviceName
                            isEditingName = true
                        }
                }
                
                Spacer()
                
                Toggle("Parent", isOn: Binding(
                    get: { editedDevices[device.deviceId]?.isParent ?? device.isParent },
                    set: { newValue in
                        // Update the edited devices dictionary instead of making an immediate API call
                        var currentChanges = editedDevices[device.deviceId] ?? (isParent: device.isParent, deviceName: device.deviceName)
                        currentChanges.isParent = newValue
                        editedDevices[device.deviceId] = currentChanges
                    }
                ))
                .labelsHidden()
            }
            
            Text(device.deviceId)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            if let createdAt = device.createdAtDate {
                Text("Created: \(createdAt, style: .date)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DeviceListView()
} 
