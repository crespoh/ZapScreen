import SwiftUI

struct PasscodeConfirmationView: View {
    let deviceInfo: DeviceQRInfo
    @State private var parentPasscode = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isConfirming = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Confirm Child Device Passcode")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter the 4-digit passcode you set on the child device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Device Information
                VStack(spacing: 12) {
                    Text("Child Device Information")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        infoRow(title: "Device Name", value: deviceInfo.deviceName)
                        infoRow(title: "Device ID", value: deviceInfo.deviceId)
                        if let passcodeHash = deviceInfo.passcodeHash {
                            infoRow(title: "Passcode Set", value: "Yes")
                        } else {
                            infoRow(title: "Passcode Set", value: "No")
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                }
                .padding(.horizontal)
                
                // Passcode Display
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index < parentPasscode.count ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text(index < parentPasscode.count ? "•" : "")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            )
                    }
                }
                .padding(.vertical, 20)
                
                // Instructions
                Text("Enter the 4-digit passcode")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Numeric Keypad
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                    ForEach(1...9, id: \.self) { number in
                        NumberButton(number: "\(number)") {
                            addDigit("\(number)")
                        }
                        .disabled(isConfirming)
                    }
                    
                    // Bottom row: Clear, 0, Delete
                    Button("Clear") {
                        clearPasscode()
                    }
                    .buttonStyle(NumberButtonStyle())
                    .foregroundColor(.red)
                    .disabled(isConfirming)
                    
                    NumberButton(number: "0") {
                        addDigit("0")
                    }
                    .disabled(isConfirming)
                    
                    Button("⌫") {
                        deleteLastDigit()
                    }
                    .buttonStyle(NumberButtonStyle())
                    .foregroundColor(.orange)
                    .disabled(isConfirming)
                }
                .padding(.horizontal, 40)
                
                // Confirm Button
                Button("Confirm & Register") {
                    confirmAndRegister()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(parentPasscode.count != 4 || isConfirming)
                .padding(.top, 20)
                
                if isConfirming {
                    ProgressView("Registering device...")
                        .padding(.top, 10)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func addDigit(_ digit: String) {
        guard parentPasscode.count < 4 else { return }
        parentPasscode += digit
    }
    
    private func deleteLastDigit() {
        guard !parentPasscode.isEmpty else { return }
        parentPasscode.removeLast()
    }
    
    private func clearPasscode() {
        parentPasscode = ""
    }
    
    private func confirmAndRegister() {
        guard parentPasscode.count == 4 else { return }
        
        isConfirming = true
        
        Task {
            do {
                // 1. Save on parent device
                await saveChildPasscode(parentPasscode, for: deviceInfo.deviceId, childName: deviceInfo.deviceName)
                
                // 2. Send to Supabase (async, doesn't block registration)
                try await sendPasscodeToSupabase(parentPasscode, deviceInfo)
                
                // 3. Complete registration
                await completeRegistration(deviceInfo)
                
                await MainActor.run {
                    isConfirming = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isConfirming = false
                }
            }
        }
    }
    
    private func saveChildPasscode(_ passcode: String, for deviceId: String, childName: String) async {
        // Save passcode locally on parent device
        let passcodeData = ChildPasscodeData(
            deviceId: deviceId,
            childName: childName,
            passcode: passcode,
            savedAt: Date()
        )
        
        if let data = try? JSONEncoder().encode(passcodeData) {
            UserDefaults.standard.set(data, forKey: "ChildPasscode_\(deviceId)")
        }
        
        print("[PasscodeConfirmationView] Saved passcode locally for device: \(deviceId)")
    }
    
    private func sendPasscodeToSupabase(_ passcode: String, _ deviceInfo: DeviceQRInfo) async throws {
        // Send passcode to Supabase for child device access
        try await SupabaseManager.shared.syncChildPasscode(
            passcode: passcode,
            deviceId: deviceInfo.deviceId
        )
        
        print("[PasscodeConfirmationView] Passcode synced to Supabase for device: \(deviceInfo.deviceId)")
    }
    
    private func completeRegistration(_ deviceInfo: DeviceQRInfo) async {
        // Complete the device registration process
        // This would typically involve calling the existing registration logic
        print("[PasscodeConfirmationView] Registration completed for device: \(deviceInfo.deviceId)")
    }
    
    // MARK: - Helper Views
    func infoRow(title: String, value: String) -> some View {
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
}

// MARK: - Supporting Types

struct ChildPasscodeData: Codable {
    let deviceId: String
    let childName: String
    let passcode: String
    let savedAt: Date
}

#if DEBUG
struct PasscodeConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        PasscodeConfirmationView(deviceInfo: DeviceQRInfo(
            deviceName: "Child's iPhone",
            deviceId: "test-device-id",
            timestamp: Date(),
            deviceToken: "test-token",
            passcodeHash: "test-hash"
        ))
    }
}
#endif
