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
                            isParent: Binding(
                                get: { editedDevices[device.deviceId] ?? device.isParent },
                                set: { editedDevices[device.deviceId] = $0 }
                            )
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
    @Binding var isParent: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(device.deviceName)
                    .font(.headline)
                Spacer()
                Toggle("Parent Device", isOn: $isParent)
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
