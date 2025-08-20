import SwiftUI

struct ChildRegistrationView: View {
    @StateObject private var viewModel = ChildRegistrationViewModel()
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
                    
                    Text("Add a child device to your family")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Form
                VStack(spacing: 20) {
                    // Child Name Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Child's Name")
                            .font(.headline)
                        
                        TextField("Enter child's name", text: $childName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                            .disableAutocorrection(false)
                    }
                    
                    // Device Info Display
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Device Information")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            infoRow(title: "Device Name", value: viewModel.deviceName)
                            infoRow(title: "Device ID", value: viewModel.deviceId)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
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
                    }
                }
                .padding(.horizontal)
                
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
        .onAppear {
            viewModel.loadDeviceInfo()
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
    
    // MARK: - Actions
    private func registerChild() {
        guard !childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        viewModel.registerChild(name: childName.trimmingCharacters(in: .whitespacesAndNewlines)) { success, message in
            alertMessage = message
            showingAlert = true
        }
    }
}

// MARK: - Child Registration ViewModel
class ChildRegistrationViewModel: ObservableObject {
    @Published var isRegistering = false
    @Published var registrationSuccessful = false
    @Published var deviceName = ""
    @Published var deviceId = ""
    
    func loadDeviceInfo() {
        deviceName = UIDevice.current.name
        deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
    }
    
    func registerChild(name: String, completion: @escaping (Bool, String) -> Void) {
        isRegistering = true
        
        Task {
            do {
                let deviceToken = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")?.string(forKey: "DeviceToken")
                
                _ = try await SupabaseManager.shared.registerChildDevice(
                    deviceId: deviceId,
                    deviceName: deviceName,
                    childName: name,
                    deviceToken: deviceToken
                )
                
                await MainActor.run {
                    self.isRegistering = false
                    self.registrationSuccessful = true
                    completion(true, "Child device registered successfully!")
                }
            } catch {
                await MainActor.run {
                    self.isRegistering = false
                    self.registrationSuccessful = false
                    completion(false, "Failed to register child device: \(error.localizedDescription)")
                }
                print("[ChildRegistrationViewModel] Registration failed: \(error)")
            }
        }
    }
}

// MARK: - Preview
struct ChildRegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        ChildRegistrationView()
    }
}
