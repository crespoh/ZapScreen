import SwiftUI
import CoreImage.CIFilterBuiltins
import CryptoKit

struct ChildQRCodeView: View {
    @StateObject private var viewModel = ChildQRCodeViewModel()
    @StateObject private var passcodeManager = PasscodeManager.shared
    @State private var showingPasscodeSetup = false
    @State private var passcode = ""
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                        
                        Text("Child Device QR Code")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Set passcode and show QR code to your parent")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 10)
                    .padding(.horizontal)
                
                // Passcode Setup Section
                if !passcodeManager.isPasscodeEnabled {
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                            
                            Text("Set Shield Management Passcode")
                                .font(.headline)
                            
                            Text("This passcode will protect shield settings from unauthorized access")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                        
                        Button("Set Passcode") {
                            showingPasscodeSetup = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal)
                } else {
                    // Passcode Status
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Passcode Set")
                                .font(.headline)
                        }
                        
                        Text("Shield settings are now protected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                    )
                    .padding(.horizontal)
                }
                
                // QR Code Display
                VStack(spacing: 16) {
                    Spacer(minLength: 20)
                    if let qrCodeImage = viewModel.qrCodeImage {
                        Image(uiImage: qrCodeImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250, height: 250)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 250, height: 250)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(1.5)
                            )
                    }
                    
                    Text("Scan this QR code with your parent's device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Spacer(minLength: 20)
                }
                
                // Device Information
                VStack(spacing: 16) {
                    Text("Device Information")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        infoRow(title: "Device Name", value: viewModel.deviceName)
                        infoRow(title: "Device ID", value: viewModel.deviceId)
                        infoRow(title: "Status", value: viewModel.isRegistered ? "Registered" : "Not Registered")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    if viewModel.isRegistered {
                        Button("View Registration Details") {
                            // TODO: Show registration details
                            print("Show registration details")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button("Refresh QR Code") {
                        viewModel.generateQRCode()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.bottom, 100) // Increased padding to account for tab bar
                }
                .frame(minHeight: geometry.size.height)
            }
            .sheet(isPresented: $showingPasscodeSetup) {
                PasscodeSetupView(passcode: $passcode)
                    .onDisappear {
                        if passcodeManager.isPasscodeEnabled {
                            // Passcode was set successfully, regenerate QR code with passcode hash
                            viewModel.generateQRCodeWithPasscode()
                        }
                    }
            }
        }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        viewModel.shareQRCode()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 0)
            }
            .onAppear {
                viewModel.loadDeviceInfo()
                viewModel.generateQRCode()
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

// MARK: - Child QR Code ViewModel
class ChildQRCodeViewModel: ObservableObject {
    @Published var qrCodeImage: UIImage?
    @Published var deviceName = ""
    @Published var deviceId = ""
    @Published var isRegistered = false
    
    private let context = CIContext()
    private let qrGenerator = CIFilter.qrCodeGenerator()
    
    func loadDeviceInfo() {
        deviceName = UIDevice.current.name
        deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
        checkRegistrationStatus()
    }
    
    func generateQRCode() {
        generateQRCodeWithPasscode()
    }
    
    func generateQRCodeWithPasscode() {
        // Get device token from UserDefaults if available
        let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        let deviceToken = groupDefaults?.string(forKey: "DeviceToken")
        
        print("[ChildQRCodeViewModel] Device token available: \(deviceToken != nil)")
        if let token = deviceToken {
            print("[ChildQRCodeViewModel] Device token: \(String(token.prefix(20)))...")
        }
        
        // Get passcode hash if available
        var passcodeHash: String? = nil
        if let data = UserDefaults.standard.data(forKey: "PasscodeSettings"),
           let settings = try? JSONDecoder().decode(PasscodeSettings.self, from: data) {
            passcodeHash = settings.hashedPasscode
            print("[ChildQRCodeViewModel] Passcode hash available: \(passcodeHash != nil)")
        }
        
        let deviceInfo = DeviceQRInfo(
            deviceName: deviceName,
            deviceId: deviceId,
            timestamp: Date(),
            deviceToken: deviceToken,
            passcodeHash: passcodeHash
        )
        
        guard let jsonData = try? JSONEncoder().encode(deviceInfo),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("[ChildQRCodeViewModel] Failed to encode device info")
            return
        }
        
        qrCodeImage = generateQRCode(from: jsonString)
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        qrGenerator.setValue(string.data(using: .utf8), forKey: "inputMessage")
        
        guard let outputImage = qrGenerator.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func checkRegistrationStatus() {
        // TODO: Check if this device is already registered
        // For now, assume not registered
        isRegistered = false
    }
    
    func shareQRCode() {
        guard let qrCodeImage = qrCodeImage else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [qrCodeImage],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Device QR Info Model
struct DeviceQRInfo: Codable {
    let deviceName: String
    let deviceId: String
    let timestamp: Date
    let deviceToken: String? // Optional device token for push notifications
    let passcodeHash: String? // Hash of the passcode for verification
}

// MARK: - Preview
struct ChildQRCodeView_Previews: PreviewProvider {
    static var previews: some View {
        ChildQRCodeView()
    }
}
