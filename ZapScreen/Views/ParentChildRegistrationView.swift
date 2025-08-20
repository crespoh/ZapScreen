import SwiftUI

struct ParentChildRegistrationView: View {
    let deviceInfo: DeviceQRInfo
    @StateObject private var viewModel = ParentChildRegistrationViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var childName = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                    
                    Text("Register Child Device")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Add this child device to your family")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Scanned Device Info
                VStack(spacing: 16) {
                    Text("Device Information")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        infoRow(title: "Device Name", value: deviceInfo.deviceName)
                        infoRow(title: "Device ID", value: deviceInfo.deviceId)
                        infoRow(title: "Scanned At", value: formatDate(deviceInfo.timestamp))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                }
                .padding(.horizontal)
                
                // Child Name Input
                VStack(spacing: 16) {
                    Text("Child's Name")
                        .font(.headline)
                    
                    TextField("Enter child's name", text: $childName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disableAutocorrection(false)
                        .padding(.horizontal)
                }
                
                // Instructions
                VStack(spacing: 16) {
                    Text("Instructions")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        instructionRow("1. Enter the child's name above")
                        instructionRow("2. This device will be registered as a child device")
                        instructionRow("3. The child can request app unlocks from this device")
                        instructionRow("4. You can view their usage statistics in the family dashboard")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Register Button
                Button(action: registerChild) {
                    if viewModel.isRegistering {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Registering...")
                        }
                    } else {
                        Text("Register Child Device")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isRegistering)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Registration Result", isPresented: $showingAlert) {
            Button("OK") {
                if viewModel.registrationSuccessful {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Helper Views
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    private func instructionRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.accentColor)
            Text(text)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Actions
    private func registerChild() {
        guard !childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        print("[ParentChildRegistrationView] Registering child with device token: \(deviceInfo.deviceToken != nil)")
        if let token = deviceInfo.deviceToken {
            print("[ParentChildRegistrationView] Device token: \(String(token.prefix(20)))...")
        }
        
        viewModel.registerChild(
            deviceId: deviceInfo.deviceId,
            deviceName: deviceInfo.deviceName,
            childName: childName.trimmingCharacters(in: .whitespacesAndNewlines),
            deviceToken: deviceInfo.deviceToken
        ) { success, message in
            alertMessage = message
            showingAlert = true
        }
    }
}

// MARK: - Parent Child Registration ViewModel
class ParentChildRegistrationViewModel: ObservableObject {
    @Published var isRegistering = false
    @Published var registrationSuccessful = false
    
    func registerChild(deviceId: String, deviceName: String, childName: String, deviceToken: String?, completion: @escaping (Bool, String) -> Void) {
        isRegistering = true
        
        Task {
            do {
                // First, register the child device
                _ = try await SupabaseManager.shared.registerChildDevice(
                    deviceId: deviceId,
                    deviceName: deviceName,
                    childName: childName,
                    deviceToken: deviceToken // Use the device token from QR code
                )
                
                // Then, link parent and child devices
                let currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
                _ = try await SupabaseManager.shared.linkParentChildDevices(
                    parentDeviceId: currentDeviceId,
                    childDeviceId: deviceId
                )
                
                await MainActor.run {
                    self.isRegistering = false
                    self.registrationSuccessful = true
                    completion(true, "Child device registered and linked successfully!")
                }
            } catch {
                await MainActor.run {
                    self.isRegistering = false
                    self.registrationSuccessful = false
                    completion(false, "Failed to register child device: \(error.localizedDescription)")
                }
                print("[ParentChildRegistrationViewModel] Registration failed: \(error)")
            }
        }
    }
}

// MARK: - Preview
struct ParentChildRegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        ParentChildRegistrationView(
            deviceInfo: DeviceQRInfo(
                deviceName: "iPhone 15",
                deviceId: "12345678-1234-1234-1234-123456789012",
                timestamp: Date(),
                deviceToken: nil
            )
        )
    }
}
