import SwiftUI

struct ParentPasscodeManagementView: View {
    @StateObject private var viewModel = ParentPasscodeManagementViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingChangePasscode = false
    @State private var selectedChildDevice: ChildPasscodeData?
    @State private var showingResetConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading child devices...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.childDevices.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No Child Devices Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Child devices will appear here after they are registered with passcodes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.childDevices, id: \.deviceId) { childDevice in
                            ChildPasscodeRow(
                                childDevice: childDevice,
                                onChangePasscode: {
                                    selectedChildDevice = childDevice
                                    showingChangePasscode = true
                                },
                                onResetPasscode: {
                                    selectedChildDevice = childDevice
                                    showingResetConfirmation = true
                                }
                            )
                        }
                    }
                    .refreshable {
                        await viewModel.loadChildDevices()
                    }
                }
            }
            .navigationTitle("Child Passcodes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadChildDevices()
                }
            }
            .sheet(isPresented: $showingChangePasscode) {
                if let childDevice = selectedChildDevice {
                    ChangeChildPasscodeView(childDevice: childDevice) {
                        Task {
                            await viewModel.loadChildDevices()
                        }
                    }
                }
            }
            .alert("Reset Passcode", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    if let childDevice = selectedChildDevice {
                        Task {
                            await viewModel.resetPasscode(for: childDevice)
                        }
                    }
                }
            } message: {
                if let childDevice = selectedChildDevice {
                    Text("This will remove the passcode for \(childDevice.childName)'s device. The child will need to set a new passcode to access shield settings.")
                }
            }
        }
    }
}

struct ChildPasscodeRow: View {
    let childDevice: ChildPasscodeData
    let onChangePasscode: () -> Void
    let onResetPasscode: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(childDevice.childName)
                        .font(.headline)
                    
                    Text(childDevice.deviceId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Set: \(childDevice.savedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button("Change") {
                        onChangePasscode()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Reset") {
                        onResetPasscode()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
            
            // Passcode display (masked)
            HStack {
                Text("Passcode:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { _ in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ChangeChildPasscodeView: View {
    let childDevice: ChildPasscodeData
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var newPasscode = ""
    @State private var confirmPasscode = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isChanging = false
    @State private var passcodeMismatch = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            
                            Text("Change Passcode")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Set new passcode for \(childDevice.childName)'s device")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, geometry.safeAreaInsets.top + 20)
                        
                        // New Passcode Entry
                        VStack(spacing: 12) {
                            Text("New Passcode")
                                .font(.headline)
                            
                            HStack(spacing: 12) {
                                ForEach(0..<4, id: \.self) { index in
                                    Circle()
                                        .fill(index < newPasscode.count ? Color.blue : Color.gray.opacity(0.3))
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Text(index < newPasscode.count ? "•" : "")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                        }
                        
                        // Confirm Passcode Entry
                        VStack(spacing: 12) {
                            Text("Confirm Passcode")
                                .font(.headline)
                            
                            HStack(spacing: 12) {
                                ForEach(0..<4, id: \.self) { index in
                                    Circle()
                                        .fill(index < confirmPasscode.count ? Color.blue : Color.gray.opacity(0.3))
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Text(index < confirmPasscode.count ? "•" : "")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                        }
                        
                        // Error message for passcode mismatch
                        if passcodeMismatch {
                            Text("Passcodes do not match")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 8)
                        }
                        
                        // Numeric Keypad
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                            ForEach(1...9, id: \.self) { number in
                                NumberButton(number: "\(number)") {
                                    addDigit("\(number)")
                                }
                                .disabled(isChanging)
                            }
                            
                            // Bottom row: Clear, 0, Delete
                            Button("Clear") {
                                clearPasscodes()
                            }
                            .buttonStyle(NumberButtonStyle())
                            .foregroundColor(.red)
                            .disabled(isChanging)
                            
                            NumberButton(number: "0") {
                                addDigit("0")
                            }
                            .disabled(isChanging)
                            
                            Button("⌫") {
                                deleteLastDigit()
                            }
                            .buttonStyle(NumberButtonStyle())
                            .foregroundColor(.orange)
                            .disabled(isChanging)
                        }
                        .padding(.horizontal, max(40, geometry.size.width * 0.1))
                        
                        // Change Button
                        Button("Change Passcode") {
                            changePasscode()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(newPasscode.count != 4 || confirmPasscode.count != 4 || isChanging)
                        .padding(.top, 20)
                        
                        if isChanging {
                            ProgressView("Changing passcode...")
                                .padding(.top, 10)
                        }
                        
                        // Bottom spacing to account for safe area
                        Color.clear
                            .frame(height: geometry.safeAreaInsets.bottom + 20)
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)
            }
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
        if newPasscode.count < 4 {
            newPasscode += digit
        } else if confirmPasscode.count < 4 {
            confirmPasscode += digit
        }
        
        // Clear mismatch error when user starts typing again
        if passcodeMismatch {
            passcodeMismatch = false
        }
    }
    
    private func deleteLastDigit() {
        if !confirmPasscode.isEmpty {
            confirmPasscode.removeLast()
        } else if !newPasscode.isEmpty {
            newPasscode.removeLast()
        }
        
        // Clear mismatch error when user starts editing
        if passcodeMismatch {
            passcodeMismatch = false
        }
    }
    
    private func clearPasscodes() {
        newPasscode = ""
        confirmPasscode = ""
        passcodeMismatch = false
    }
    
    private func changePasscode() {
        guard newPasscode.count == 4 && confirmPasscode.count == 4 else { return }
        guard newPasscode == confirmPasscode else {
            passcodeMismatch = true
            return
        }
        
        isChanging = true
        
        Task {
            do {
                // Update passcode in Supabase
                try await SupabaseManager.shared.updateChildPasscode(
                    newPasscode: newPasscode,
                    childDeviceId: childDevice.deviceId
                )
                
                // Get current device_owner name from Supabase
                let supabaseChildren = try await SupabaseManager.shared.getChildrenForParent()
                let currentChildName = supabaseChildren.first(where: { $0.device_id == childDevice.deviceId })?.device_owner ?? childDevice.childName
                
                // Update local storage with current name from Supabase
                let updatedPasscodeData = ChildPasscodeData(
                    deviceId: childDevice.deviceId,
                    childName: currentChildName, // Use current name from Supabase
                    passcode: newPasscode,
                    savedAt: Date()
                )
                
                if let data = try? JSONEncoder().encode(updatedPasscodeData) {
                    UserDefaults.standard.set(data, forKey: "ChildPasscode_\(childDevice.deviceId)")
                }
                
                await MainActor.run {
                    isChanging = false
                    onComplete()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isChanging = false
                }
            }
        }
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

// MARK: - ViewModel

@MainActor
class ParentPasscodeManagementViewModel: ObservableObject {
    @Published var childDevices: [ChildPasscodeData] = []
    @Published var isLoading = false
    
    func loadChildDevices() async {
        isLoading = true
        
        do {
            // Get child devices from Supabase with current device_owner names
            let supabaseChildren = try await SupabaseManager.shared.getChildrenForParent()
            print("[ParentPasscodeManagementViewModel] Retrieved \(supabaseChildren.count) children from Supabase")
            
            // Load child passcodes from local storage and match with Supabase data
            var devices: [ChildPasscodeData] = []
            
            for key in UserDefaults.standard.dictionaryRepresentation().keys {
                if key.hasPrefix("ChildPasscode_") {
                    if let data = UserDefaults.standard.data(forKey: key),
                       let passcodeData = try? JSONDecoder().decode(ChildPasscodeData.self, from: data) {
                        
                        // Find matching device in Supabase data to get current device_owner name
                        if let supabaseChild = supabaseChildren.first(where: { $0.device_id == passcodeData.deviceId }) {
                            // Create updated passcode data with current device_owner name from Supabase
                            let updatedPasscodeData = ChildPasscodeData(
                                deviceId: passcodeData.deviceId,
                                childName: supabaseChild.device_owner, // Use current name from Supabase
                                passcode: passcodeData.passcode,
                                savedAt: passcodeData.savedAt
                            )
                            devices.append(updatedPasscodeData)
                            print("[ParentPasscodeManagementViewModel] Matched device \(passcodeData.deviceId) with name: \(supabaseChild.device_owner)")
                        } else {
                            // If no match found in Supabase, keep local data but log warning
                            devices.append(passcodeData)
                            print("[ParentPasscodeManagementViewModel] Warning: Device \(passcodeData.deviceId) not found in Supabase, using local name: \(passcodeData.childName)")
                        }
                    }
                }
            }
            
            // Sort by saved date (newest first)
            devices.sort { $0.savedAt > $1.savedAt }
            
            childDevices = devices
            print("[ParentPasscodeManagementViewModel] Loaded \(devices.count) child devices with passcodes")
            
        } catch {
            print("[ParentPasscodeManagementViewModel] Failed to load children from Supabase: \(error)")
            
            // Fallback to local storage only
            var devices: [ChildPasscodeData] = []
            
            for key in UserDefaults.standard.dictionaryRepresentation().keys {
                if key.hasPrefix("ChildPasscode_") {
                    if let data = UserDefaults.standard.data(forKey: key),
                       let passcodeData = try? JSONDecoder().decode(ChildPasscodeData.self, from: data) {
                        devices.append(passcodeData)
                    }
                }
            }
            
            // Sort by saved date (newest first)
            devices.sort { $0.savedAt > $1.savedAt }
            
            childDevices = devices
        }
        
        isLoading = false
    }
    
    func resetPasscode(for childDevice: ChildPasscodeData) async {
        do {
            // Remove from Supabase
            try await SupabaseManager.shared.resetChildPasscode(deviceId: childDevice.deviceId)
            
            // Remove from local storage
            UserDefaults.standard.removeObject(forKey: "ChildPasscode_\(childDevice.deviceId)")
            
            // Reload devices
            await loadChildDevices()
        } catch {
            print("[ParentPasscodeManagementViewModel] Failed to reset passcode: \(error)")
        }
    }
}

#if DEBUG
struct ParentPasscodeManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ParentPasscodeManagementView()
    }
}
#endif
