import SwiftUI
import AVFoundation
import Combine

struct QRCodeScannerView: View {
    @StateObject private var viewModel = QRCodeScannerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingRegistration = false
    @State private var showingPasscodeConfirmation = false
    @State private var scannedDeviceInfo: DeviceQRInfo?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera Preview or Error
                if viewModel.cameraPermissionGranted && viewModel.isSessionRunning {
                    GeometryReader { geometry in
                        CameraPreviewView(session: viewModel.session)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped() // Prevents overflow
                            .onAppear {
                                print("[QRCodeScannerView] Camera preview appeared with size: \(geometry.size)")
                            }
                    }
                    .ignoresSafeArea()
                    .clipped() // Additional clipping for safety
                } else if let error = viewModel.cameraError {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.slash.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        
                        Text("Camera Access Required")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Open Settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding()
                } else if viewModel.cameraPermissionGranted && !viewModel.isSessionRunning {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Starting camera...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .background(Color(.systemBackground))
                } else {
                    ProgressView("Requesting camera permission...")
                        .background(Color(.systemBackground))
                }
                
                // Overlay (only show when camera is available)
                if viewModel.cameraPermissionGranted {
                    VStack {
                    // Header
                    VStack(spacing: 8) {
                        Text("Scan Child Device QR Code")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Position the QR code within the frame")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.6))
                    )
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Scanning Frame
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 250, height: 250)
                        .background(Color.clear)
                    
                    Spacer()
                    
                    // Instructions
                    VStack(spacing: 12) {
                        Text("Make sure the QR code is clearly visible")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                }
                
                // Success Overlay
                if let deviceInfo = scannedDeviceInfo {
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.green)
                            
                            Text("QR Code Scanned!")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Device: \(deviceInfo.deviceName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Register Child Device") {
                            showingRegistration = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Scan Another") {
                            scannedDeviceInfo = nil
                            viewModel.startScanning()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
                    )
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showingRegistration) {
            if let deviceInfo = scannedDeviceInfo {
                ParentChildRegistrationView(deviceInfo: deviceInfo)
            }
        }
        .sheet(isPresented: $showingPasscodeConfirmation) {
            if let deviceInfo = scannedDeviceInfo {
                PasscodeConfirmationView(deviceInfo: deviceInfo)
            }
        }
        .onReceive(viewModel.scannedCodePublisher) { scannedString in
            handleScannedCode(scannedString)
        }
        .onAppear {
            viewModel.requestCameraPermission()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Forces portrait layout
        .onAppear {
            // Lock to portrait orientation
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
    }
    
    private func handleScannedCode(_ scannedString: String) {
        guard let jsonData = scannedString.data(using: .utf8),
              let deviceInfo = try? JSONDecoder().decode(DeviceQRInfo.self, from: jsonData) else {
            print("[QRCodeScannerView] Failed to decode scanned QR code")
            return
        }
        
        viewModel.stopScanning()
        scannedDeviceInfo = deviceInfo
        
        // Check if the QR code contains passcode hash
        if deviceInfo.passcodeHash != nil {
            // Show passcode confirmation if passcode is set
            showingPasscodeConfirmation = true
        } else {
            // Show regular registration if no passcode
            showingRegistration = true
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        // Force portrait orientation
        if #available(iOS 17.0, *) {
            previewLayer.connection?.videoRotationAngle = 0
        } else {
            previewLayer.connection?.videoOrientation = .portrait
        }
        
        // Ensure the preview layer is properly oriented (iOS 16 and below)
        if !ProcessInfo.processInfo.isiOSAppOnMac {
            previewLayer.connection?.videoOrientation = .portrait
        }
        
        view.layer.addSublayer(previewLayer)
        
        // Store the preview layer in the coordinator for later access
        context.coordinator.previewLayer = previewLayer
        
        print("[CameraPreviewView] Created preview layer with portrait orientation")
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update frame when view bounds change
        DispatchQueue.main.async {
            if let previewLayer = context.coordinator.previewLayer {
                let bounds = uiView.bounds
                previewLayer.frame = bounds
                print("[CameraPreviewView] Updated preview layer frame: \(bounds)")
                
                // Ensure the preview layer is properly configured
                if bounds.width > 0 && bounds.height > 0 {
                    // Always maintain portrait orientation
                    if #available(iOS 17.0, *) {
                        previewLayer.connection?.videoRotationAngle = 0
                    } else {
                        previewLayer.connection?.videoOrientation = .portrait
                    }
                    
                    // Force portrait orientation (iOS 16 and below)
                    if !ProcessInfo.processInfo.isiOSAppOnMac {
                        previewLayer.connection?.videoOrientation = .portrait
                    }
                    
                    print("[CameraPreviewView] Preview layer configured with valid bounds and portrait orientation")
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - QR Code Scanner ViewModel
class QRCodeScannerViewModel: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var cameraPermissionGranted = false
    @Published var cameraError: String?
    @Published var isSessionRunning = false
    let scannedCodePublisher = PassthroughSubject<String, Never>()
    
    let session = AVCaptureSession()
    
    func requestCameraPermission() {
        // Check if running on simulator
        #if targetEnvironment(simulator)
        print("[QRCodeScannerViewModel] Running on simulator - camera will not work")
        DispatchQueue.main.async {
            self.cameraError = "Camera is not available in iOS Simulator. Please test on a physical device."
        }
        return
        #endif
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.cameraPermissionGranted = true
                self.setupCamera()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.cameraPermissionGranted = true
                        self?.setupCamera()
                    } else {
                        self?.cameraError = "Camera access denied. Please enable camera access in Settings."
                        print("[QRCodeScannerViewModel] Camera access denied")
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.cameraError = "Camera access denied. Please enable camera access in Settings."
            }
            print("[QRCodeScannerViewModel] Camera access denied or restricted")
        @unknown default:
            DispatchQueue.main.async {
                self.cameraError = "Unknown camera authorization status"
            }
            print("[QRCodeScannerViewModel] Unknown camera authorization status")
        }
    }
    
    private func setupCamera() {
        print("[QRCodeScannerViewModel] Setting up camera...")
        
        // Configure session on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Begin configuration
            self.session.beginConfiguration()
            
            // Add video input
            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
                print("[QRCodeScannerViewModel] No video device available")
                DispatchQueue.main.async {
                    self.cameraError = "No camera available on this device"
                }
                return
            }
            
            let videoInput: AVCaptureDeviceInput
            
            do {
                videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            } catch {
                print("[QRCodeScannerViewModel] Failed to create video input: \(error)")
                DispatchQueue.main.async {
                    self.cameraError = "Failed to access camera: \(error.localizedDescription)"
                }
                return
            }
            
            if self.session.canAddInput(videoInput) {
                self.session.addInput(videoInput)
                print("[QRCodeScannerViewModel] Added video input")
            } else {
                print("[QRCodeScannerViewModel] Cannot add video input")
                DispatchQueue.main.async {
                    self.cameraError = "Cannot configure camera input"
                }
                return
            }
            
            // Add metadata output
            let metadataOutput = AVCaptureMetadataOutput()
            
            if self.session.canAddOutput(metadataOutput) {
                self.session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
                print("[QRCodeScannerViewModel] Added metadata output for QR codes")
            } else {
                print("[QRCodeScannerViewModel] Cannot add metadata output")
                DispatchQueue.main.async {
                    self.cameraError = "Cannot configure QR code detection"
                }
                return
            }
            
            // Commit configuration
            self.session.commitConfiguration()
            
            print("[QRCodeScannerViewModel] Camera setup completed successfully")
            
            // Start scanning
            DispatchQueue.main.async {
                self.startScanning()
            }
        }
    }
    
    func startScanning() {
        guard !self.isSessionRunning else { 
            print("[QRCodeScannerViewModel] Session already running")
            return 
        }
        
        print("[QRCodeScannerViewModel] Starting camera session...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.session.startRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = true
                self.isScanning = true
                print("[QRCodeScannerViewModel] Camera session started successfully")
            }
        }
    }
    
    func stopScanning() {
        guard self.isSessionRunning else { 
            print("[QRCodeScannerViewModel] Session not running")
            return 
        }
        
        print("[QRCodeScannerViewModel] Stopping camera session...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.session.stopRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = false
                self.isScanning = false
                print("[QRCodeScannerViewModel] Camera session stopped")
            }
        }
    }
    
    func checkSessionStatus() {
        print("[QRCodeScannerViewModel] Session isRunning: \(session.isRunning)")
        print("[QRCodeScannerViewModel] Published isSessionRunning: \(isSessionRunning)")
        print("[QRCodeScannerViewModel] Published isScanning: \(isScanning)")
        print("[QRCodeScannerViewModel] Published cameraPermissionGranted: \(cameraPermissionGranted)")
        print("[QRCodeScannerViewModel] Session inputs: \(session.inputs.count)")
        print("[QRCodeScannerViewModel] Session outputs: \(session.outputs.count)")
        
        if let input = session.inputs.first as? AVCaptureDeviceInput {
            let deviceName = input.device.localizedName ?? "Unknown Device"
            print("[QRCodeScannerViewModel] Input device: \(deviceName)")
        }
        
        if let output = session.outputs.first as? AVCaptureMetadataOutput {
            print("[QRCodeScannerViewModel] Output types: \(output.metadataObjectTypes)")
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension QRCodeScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        print("[QRCodeScannerViewModel] Received \(metadataObjects.count) metadata objects")
        
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let stringValue = metadataObject.stringValue {
            print("[QRCodeScannerViewModel] Scanned QR code: \(stringValue)")
            scannedCodePublisher.send(stringValue)
        } else {
            print("[QRCodeScannerViewModel] No valid QR code found in metadata objects")
        }
    }
}

// MARK: - Preview
struct QRCodeScannerView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeScannerView()
    }
}
