import SwiftUI

// Example SwiftUI view to display the device list
struct DeviceListView: View {
    @StateObject private var viewModel = DevicesListViewModel()
    @State private var editedDevices: [String: Bool] = [:] // Track edited isParent states
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView("Loading devices...")
                } else {
                    ForEach(viewModel.devices) { device in
                        DeviceRow(
                            device: device,
                            viewModel: viewModel
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
        for (deviceId, isParent) in editedDevices {
            viewModel.updateDeviceParentStatus(deviceId: deviceId, isParent: isParent)
        }
        editedDevices.removeAll()
    }
}

struct DeviceRow: View {
    let device: DeviceListResponse.Device
    @ObservedObject var viewModel: DevicesListViewModel
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
                                viewModel.updateDeviceName(deviceId: device.deviceId, deviceName: editedName)
                            }
                            isEditingName = false
                        }
                } else {
                    Text(device.deviceName)
                        .font(.headline)
                        .onTapGesture {
                            editedName = device.deviceName
                            isEditingName = true
                        }
                }
                
                Spacer()
                
                Toggle("Parent", isOn: Binding(
                    get: { device.isParent },
                    set: { newValue in
                        viewModel.updateDeviceParentStatus(deviceId: device.deviceId, isParent: newValue)
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
