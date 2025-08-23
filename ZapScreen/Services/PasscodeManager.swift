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
    private let lockoutDuration: TimeInterval = 10 // 1 minute
    private let idleTimeout: TimeInterval = 30 // 30 seconds
    private var idleTimer: Timer?
    
    private init() {
        _ = loadPasscodeSettings()
        setupAppStateObservers()
        // Start timer only if passcode is enabled to avoid unnecessary timers
        if isPasscodeEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startIdleTimer()
            }
        }
    }
    
    // MARK: - Passcode Management
    
    func setPasscode(_ passcode: String) async throws {
        guard passcode.count == 4 && passcode.allSatisfy({ $0.isNumber }) else {
            throw PasscodeError.invalidFormat
        }
        
        // Hash the passcode with salt
        let salt = generateSalt()
        guard let hashedPasscode = hashPasscode(passcode, salt: salt) else {
            throw PasscodeError.invalidFormat
        }
        
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
        lastActivity = Date()
        
        // Start idle timer now that passcode is enabled
        DispatchQueue.main.async { [weak self] in
            self?.startIdleTimer()
        }
        
        // Start background sync to Supabase
        Task {
            await syncPasscodeToSupabase(passcode)
        }
        
        print("[PasscodeManager] Passcode set successfully")
    }
    
    /// Save an already-hashed passcode from Supabase (no rehashing needed)
    private func saveHashedPasscode(_ hashedPasscode: String) async throws {
        // Generate a new salt for the local storage
        let salt = generateSalt()
        
        // Save locally with the hashed passcode from Supabase
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
        lastActivity = Date()
        
        // Start idle timer now that passcode is enabled
        DispatchQueue.main.async { [weak self] in
            self?.startIdleTimer()
        }
        
        print("[PasscodeManager] Hashed passcode saved from Supabase successfully")
    }
    
    /// Force lock the device immediately (useful after passcode setup)
    func forceLockDevice() {
        isLocked = true
        lastActivity = Date()
        print("[PasscodeManager] Device force locked")
    }
    
    func validatePasscode(_ passcode: String) -> PasscodeValidationResult {
        // Check if device is locked out
        if let lockoutUntil = lockoutUntil, Date() < lockoutUntil {
            return .locked(lockoutUntil)
        }
        
        // Check if passcode is correct
        guard let settings = loadPasscodeSettings() else {
            return .invalid(remainingAttempts)
        }
        
        guard let hashedInput = hashPasscode(passcode, salt: settings.salt),
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
        lastActivity = Date()
        resetIdleTimer()
        print("[PasscodeManager] Device locked")
    }
    
    func unlockDevice() {
        isLocked = false
        resetIdleTimer()
        print("[PasscodeManager] Device unlocked")
    }
    
    /// Reset failed attempts when lockout expires
    func resetFailedAttempts() {
        guard var settings = loadPasscodeSettings() else { return }
        
        // Reset failed attempts and lockout
        settings.failedAttempts = 0
        settings.lockoutUntil = nil
        
        // Save updated settings
        savePasscodeSettings(settings)
        
        // Reset manager state
        remainingAttempts = maxAttempts
        lockoutUntil = nil
        
        print("[PasscodeManager] Failed attempts reset after lockout expiration")
    }
    
    func resetPasscode() async throws {
        // Clear local passcode settings
        UserDefaults.standard.removeObject(forKey: "PasscodeSettings")
        isPasscodeEnabled = false
        isLocked = false
        remainingAttempts = maxAttempts
        lockoutUntil = nil
        
        // Stop idle timer when passcode is reset
        stopIdleTimer()
        
        // Notify Supabase that passcode is reset
        Task {
            try? await SupabaseManager.shared.resetChildPasscode(deviceId: getCurrentDeviceId())
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
            let latestHashedPasscode = try await SupabaseManager.shared.getLatestChildPasscode(
                deviceId: getCurrentDeviceId()
            )
            
            print("[PasscodeManager] Retrieved hashed passcode from Supabase: \(latestHashedPasscode ?? "nil")")

            if let hashedPasscode = latestHashedPasscode {
                // Update local passcode if different (no need to rehash since it's already hashed)
                if let currentSettings = loadPasscodeSettings(),
                   hashedPasscode != currentSettings.hashedPasscode {
                    
                    // Save the hashed passcode directly without rehashing
                    try await saveHashedPasscode(hashedPasscode)
                    print("[PasscodeManager] Updated local hashed passcode from Supabase")
                    return hashedPasscode
                }
            }
        } catch {
            print("[PasscodeManager] Failed to check Supabase for latest passcode: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Idle Timer Management
    
    private func startIdleTimer() {
        // Ensure we're on the main thread for timer operations
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.startIdleTimer()
            }
            return
        }
        
        // Safety check to prevent crashes
        guard !isLocked else { return }
        
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleIdleTimeout()
            }
        }
    }
    
    private func resetIdleTimer() {
        // Ensure we're on the main thread for timer operations
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.resetIdleTimer()
            }
            return
        }
        
        // Safety check to prevent crashes
        guard !isLocked else { return }
        
        idleTimer?.invalidate()
        idleTimer = nil
        lastActivity = Date()
        startIdleTimer()
    }
    
    private func stopIdleTimer() {
        // Ensure we're on the main thread for timer operations
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.stopIdleTimer()
            }
            return
        }
        
        idleTimer?.invalidate()
        idleTimer = nil
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
            Task { @MainActor in
                self?.handleAppDidEnterBackground()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppWillEnterForeground()
            }
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
        
        // Set locked state based on saved settings
        // If passcode is enabled, device should be locked by default
        // unless it was recently unlocked (within idle timeout)
        if settings.isEnabled {
            if let lockoutUntil = settings.lockoutUntil, Date() < lockoutUntil {
                // Device is in lockout period
                isLocked = true
            } else {
                // Check if device should be locked due to inactivity
                let timeSinceLastActivity = Date().timeIntervalSince(settings.lastModified)
                isLocked = timeSinceLastActivity > idleTimeout
            }
        } else {
            isLocked = false
        }
        
        return settings
    }
    
    // MARK: - Deinitialization
    
    deinit {
        // Directly invalidate timer in deinit since we can't call @MainActor methods
        idleTimer?.invalidate()
        idleTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

struct PasscodeSettings: Codable {
    let hashedPasscode: String
    let salt: String
    let isEnabled: Bool
    let createdAt: Date
    var lastModified: Date
    var failedAttempts: Int
    var lockoutUntil: Date?
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
