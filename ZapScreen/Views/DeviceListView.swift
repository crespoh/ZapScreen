import SwiftUI
import Combine

// Example SwiftUI view to display the device list
struct DeviceListView: View {
    @StateObject private var viewModel = DevicesListViewModel()
    @AppStorage("selectedRole") private var selectedRole: String?
    @State private var devices: [DeviceListResponse.Device] = []
      
    private var deviceIdFromGroupDefaults: String? {
        let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        return groupDefaults?.string(forKey: "ZapDeviceId")
    }
    
    // Computed property to check if the logged-in user is a parent
    private var canDeleteDevices: Bool {
        selectedRole == "Parent"
    }
    
    var body: some View {
        
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView("Loading devices...")
                }
                ForEach(devices) { device in
                    DeviceRow(
                        device: device,
                        viewModel: viewModel,
                        editedDevices: .constant([:]),
                        selectedRole: selectedRole
                    )
                }
                .onDelete(perform: canDeleteDevices ? deleteDevice : nil)
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
            .alert("Not allowed", isPresented: $showDeleteNotAllowedAlert) {
                Button("OK") { showDeleteNotAllowedAlert = false }
            } message: {
                Text("You do not have permission to delete devices.")
            }
            .onAppear {
                
                viewModel.fetchDevices()
                // Sync local devices array when devices are loaded
                viewModel.$devices
                    .receive(on: RunLoop.main)
                    .sink { loaded in
                        print("Device IDs: \(devices.map { $0.id })")
                        devices = loaded
                    }
                    .store(in: &cancellables)
            }
            .toolbar {

            }
        }
    }
    
    // For Combine subscription storage
    @State private var cancellables: Set<AnyCancellable> = []

    // State for showing delete permission alert
    @State private var showDeleteNotAllowedAlert = false

    // Delete device at offsets
    private func deleteDevice(at offsets: IndexSet) {
        guard canDeleteDevices else {
            showDeleteNotAllowedAlert = true
            return
        }
        let toDelete = offsets.map { devices[$0] }
        for device in toDelete {
            viewModel.deleteDevice(deviceId: device.id)
        }
        devices.remove(atOffsets: offsets)
    }
}

struct DeviceRow: View {
    let device: DeviceListResponse.Device
    @ObservedObject var viewModel: DevicesListViewModel
    @Binding var editedDevices: [String: (isParent: Bool, deviceName: String)]
    let selectedRole: String?
    @State private var isEditingName = false
    @State private var editedName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {

                Text(device.deviceName)
                    .font(.headline)
                Spacer()
                Text(device.isParent ? "Parent" : "Child")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Text(device.id)
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
