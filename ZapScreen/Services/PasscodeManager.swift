import Foundation
import SwiftUI
import CryptoKit

@MainActor
class PasscodeManager: ObservableObject {
    static let shared = PasscodeManager()
    
    @Published var isPasscodeEnabled = false
    @Published var isLocked = true
    @Published var remainingAttempts = 3
    @Published var lockoutUntil: Date?
    @Published var lastActivity: Date = Date()
    
    private let maxAttempts = 3
    private let lockoutDuration: TimeInterval = 60 // 1 minute
    private let idleTimeout: TimeInterval = 30 // 30 seconds
    private var idleTimer: Timer?
    
    private init() {
        loadPasscodeSettings()
        startIdleTimer()
        setupAppStateObservers()
    }
    
    // MARK: - Passcode Management
    
    func setPasscode(_ passcode: String) async throws {
        guard passcode.count == 4 && passcode.allSatisfy({ $0.isNumber }) else {
            throw PasscodeError.invalidFormat
        }
        
        // Hash the passcode with salt
        let salt = generateSalt()
        let hashedPasscode = hashPasscode(passcode, salt: salt)
        
        // Save locally
        let settings = PasscodeSettings(
            hashedPasscode: hashedPasscode,
            salt: salt,
            isEnabled: true,
            createdAt: Date(),
            lastModified: Date(),
            failedAttempts: 0,
            lockoutUntil: nil
        )
        
        savePasscodeSettings(settings)
        isPasscodeEnabled = true
        isLocked = true
        
        // Start background sync to Supabase
        Task {
            await syncPasscodeToSupabase(passcode)
        }
        
        print("[PasscodeManager] Passcode set successfully")
    }
    
    func validatePasscode(_ passcode: String) -> PasscodeValidationResult {
        // Check if device is locked out
        if let lockoutUntil = lockoutUntil, Date() < lockoutUntil {
            return .locked(lockoutUntil)
        }
        
        // Check if passcode is correct
        guard let settings = loadPasscodeSettings(),
              let hashedInput = hashPasscode(passcode, salt: settings.salt),
              hashedInput == settings.hashedPasscode else {
            
            // Increment failed attempts
            var updatedSettings = settings
            updatedSettings.failedAttempts += 1
            
            if updatedSettings.failedAttempts >= maxAttempts {
                // Lock out the device
                updatedSettings.lockoutUntil = Date().addingTimeInterval(lockoutDuration)
                lockoutUntil = updatedSettings.lockoutUntil
                remainingAttempts = 0
            } else {
                remainingAttempts = maxAttempts - updatedSettings.failedAttempts
            }
            
            savePasscodeSettings(updatedSettings)
            return .invalid(remainingAttempts)
        }
        
        // Passcode is correct - reset failed attempts and unlock
        var updatedSettings = settings
        updatedSettings.failedAttempts = 0
        updatedSettings.lockoutUntil = nil
        savePasscodeSettings(updatedSettings)
        
        isLocked = false
        remainingAttempts = maxAttempts
        lockoutUntil = nil
        resetIdleTimer()
        
        return .valid
    }
    
    func lockDevice() {
        isLocked = true
        resetIdleTimer()
        print("[PasscodeManager] Device locked")
    }
    
    func unlockDevice() {
        isLocked = false
        resetIdleTimer()
        print("[PasscodeManager] Device unlocked")
    }
    
    func resetPasscode() async throws {
        // Clear local passcode settings
        UserDefaults.standard.removeObject(forKey: "PasscodeSettings")
        isPasscodeEnabled = false
        isLocked = false
        remainingAttempts = maxAttempts
        lockoutUntil = nil
        
        // Notify Supabase that passcode is reset
        Task {
            await SupabaseManager.shared.resetChildPasscode(deviceId: getCurrentDeviceId())
        }
        
        print("[PasscodeManager] Passcode reset successfully")
    }
    
    // MARK: - Supabase Sync
    
    func syncPasscodeToSupabase(_ passcode: String) async {
        do {
            try await SupabaseManager.shared.syncChildPasscode(
                passcode: passcode,
                deviceId: getCurrentDeviceId()
            )
            print("[PasscodeManager] Passcode synced to Supabase successfully")
        } catch {
            print("[PasscodeManager] Failed to sync passcode to Supabase: \(error)")
            // Will retry later when network is available
        }
    }
    
    func checkSupabaseForLatestPasscode() async -> String? {
        do {
            let latestPasscode = try await SupabaseManager.shared.getLatestChildPasscode(
                deviceId: getCurrentDeviceId()
            )
            
            if let latest = latestPasscode {
                // Update local passcode if different
                if let currentSettings = loadPasscodeSettings(),
                   let currentHash = hashPasscode(latest, salt: currentSettings.salt),
                   currentHash != currentSettings.hashedPasscode {
                    
                    try await setPasscode(latest)
                    print("[PasscodeManager] Updated local passcode from Supabase")
                    return latest
                }
            }
        } catch {
            print("[PasscodeManager] Failed to check Supabase for latest passcode: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Idle Timer Management
    
    private func startIdleTimer() {
        resetIdleTimer()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleIdleTimeout()
            }
        }
    }
    
    private func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
        lastActivity = Date()
        startIdleTimer()
    }
    
    private func handleIdleTimeout() {
        if !isLocked {
            lockDevice()
            print("[PasscodeManager] Device locked due to idle timeout")
        }
    }
    
    // MARK: - App State Management
    
    private func setupAppStateObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidEnterBackground()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillEnterForeground()
        }
    }
    
    private func handleAppDidEnterBackground() {
        if !isLocked {
            lockDevice()
            print("[PasscodeManager] Device locked due to app entering background")
        }
    }
    
    private func handleAppWillEnterForeground() {
        // Check if still authorized or need to re-authenticate
        if !isLocked && Date().timeIntervalSince(lastActivity) > idleTimeout {
            lockDevice()
            print("[PasscodeManager] Device locked due to inactivity")
        }
    }
    
    // MARK: - Utility Methods
    
    private func generateSalt() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<16).map { _ in letters.randomElement()! })
    }
    
    private func hashPasscode(_ passcode: String, salt: String) -> String? {
        let combined = passcode + salt
        guard let data = combined.data(using: .utf8) else { return nil }
        
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func getCurrentDeviceId() -> String {
        let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        return groupDefaults?.string(forKey: "ZapDeviceId") ?? ""
    }
    
    // MARK: - Local Storage
    
    private func savePasscodeSettings(_ settings: PasscodeSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "PasscodeSettings")
        }
    }
    
    private func loadPasscodeSettings() -> PasscodeSettings? {
        guard let data = UserDefaults.standard.data(forKey: "PasscodeSettings"),
              let settings = try? JSONDecoder().decode(PasscodeSettings.self, from: data) else {
            return nil
        }
        
        // Update published properties
        isPasscodeEnabled = settings.isEnabled
        remainingAttempts = maxAttempts - settings.failedAttempts
        lockoutUntil = settings.lockoutUntil
        
        return settings
    }
    
    // MARK: - Deinitialization
    
    deinit {
        idleTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

struct PasscodeSettings: Codable {
    let hashedPasscode: String
    let salt: String
    let isEnabled: Bool
    let createdAt: Date
    let lastModified: Date
    let failedAttempts: Int
    let lockoutUntil: Date?
}

enum PasscodeValidationResult {
    case valid
    case invalid(Int) // remaining attempts
    case locked(Date) // lockout until
}

enum PasscodeError: Error, LocalizedError {
    case invalidFormat
    case notSet
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Passcode must be exactly 4 digits"
        case .notSet:
            return "No passcode has been set"
        case .networkError:
            return "Network error occurred"
        }
    }
}
