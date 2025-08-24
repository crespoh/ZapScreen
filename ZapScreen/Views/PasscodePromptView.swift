import SwiftUI

struct PasscodePromptView: View {
    @StateObject private var passcodeManager = PasscodeManager.shared
    @State private var enteredPasscode = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isCheckingSupabase = false
    @State private var isValidating = false
    @State private var lockoutTimer: Timer?
    @State private var remainingLockoutTime: Int = 0
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 20)
                    
                    // Center content vertically
                    VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                
                Text("Shield Management Locked")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Enter passcode to access shield settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Passcode Display
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < enteredPasscode.count ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text(index < enteredPasscode.count ? "•" : "")
                                .font(.title2)
                                .foregroundColor(.white)
                        )
                }
            }
            .padding(.vertical, 20)
            
            // Status Messages
            if let lockoutUntil = passcodeManager.lockoutUntil, remainingLockoutTime > 0 {
                VStack(spacing: 4) {
                    Text("Too many failed attempts")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Text("Try again in \(remainingLockoutTime) seconds")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else if passcodeManager.remainingAttempts < 3 {
                Text("\(passcodeManager.remainingAttempts) attempts remaining")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            // Instructions
            Text("Enter 4-digit passcode")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Numeric Keypad
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                ForEach(1...9, id: \.self) { number in
                    NumberButton(number: "\(number)") {
                        addDigit("\(number)")
                    }
                    .disabled(isLockedOut || isCheckingSupabase || isValidating)
                }
                
                // Bottom row: Clear, 0, Delete
                Button("Clear") {
                    clearPasscode()
                }
                .buttonStyle(NumberButtonStyle())
                .foregroundColor(.red)
                .disabled(isLockedOut || isCheckingSupabase || isValidating)
                
                NumberButton(number: "0") {
                    addDigit("0")
                }
                .disabled(isLockedOut || isCheckingSupabase || isValidating)
                
                Button("⌫") {
                    deleteLastDigit()
                }
                .buttonStyle(NumberButtonStyle())
                .foregroundColor(.orange)
                .disabled(isLockedOut || isCheckingSupabase || isValidating)
            }
            .padding(.horizontal, 40)
            
            // Unlock Button
            Button("Unlock") {
                validatePasscode()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(enteredPasscode.count != 4 || isLockedOut || isCheckingSupabase || isValidating)
            .padding(.top, 20)
            
            if isCheckingSupabase {
                ProgressView("Checking for updates...")
                    .padding(.top, 10)
            }
            
            if isValidating {
                ProgressView("Validating...")
                    .padding(.top, 10)
            }
            
            // Help Text
            Text("Ask your parent to unlock this section")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 20)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 30)
                .frame(minHeight: geometry.size.height)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .background(Color(.systemBackground))
        .onAppear {
            // ✅ FIX: Don't check Supabase automatically - this prevents the auto-deactivation bug
            // The passcode prompt should remain active until correct passcode is entered
            startLockoutTimer()
        }
        .onDisappear {
            stopLockoutTimer()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var isLockedOut: Bool {
        passcodeManager.lockoutUntil != nil && passcodeManager.lockoutUntil! > Date()
    }
    
    private func addDigit(_ digit: String) {
        guard enteredPasscode.count < 4 else { return }
        enteredPasscode += digit
    }
    
    private func deleteLastDigit() {
        guard !enteredPasscode.isEmpty else { return }
        enteredPasscode.removeLast()
    }
    
    private func clearPasscode() {
        enteredPasscode = ""
    }
    
    private func validatePasscode() {
        guard enteredPasscode.count == 4 else { return }
        
        isValidating = true
        
        // ✅ REFACTOR: Now async validation that checks Supabase first
        Task {
            let result = await passcodeManager.validatePasscode(enteredPasscode)
            
            await MainActor.run {
                switch result {
                case .valid:
                    // Passcode is correct - device will be unlocked
                    isValidating = false
                    enteredPasscode = ""
                    
                case .invalid(let remainingAttempts):
                    // Passcode is incorrect
                    isValidating = false
                    enteredPasscode = ""
                    errorMessage = "Incorrect passcode. \(remainingAttempts) attempts remaining."
                    showingError = true
                    
                case .locked(let lockoutUntil):
                    // Device is locked out
                    isValidating = false
                    enteredPasscode = ""
                    let timeRemaining = max(0, Int(lockoutUntil.timeIntervalSinceNow))
                    errorMessage = "Device locked. Try again after \(timeRemaining) seconds."
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - Timer Management
    
    private func startLockoutTimer() {
        // Stop any existing timer
        stopLockoutTimer()
        
        // Start a timer that updates every second
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateLockoutDisplay()
        }
        
        // Initial update
        updateLockoutDisplay()
    }
    
    private func stopLockoutTimer() {
        lockoutTimer?.invalidate()
        lockoutTimer = nil
    }
    
    private func updateLockoutDisplay() {
        guard let lockoutUntil = passcodeManager.lockoutUntil else {
            remainingLockoutTime = 0
            return
        }
        
        let timeRemaining = Int(lockoutUntil.timeIntervalSinceNow)
        
        // Only show positive values
        if timeRemaining > 0 {
            remainingLockoutTime = timeRemaining
        } else {
            // Lockout has expired - reset failed attempts
            remainingLockoutTime = 0
            passcodeManager.resetFailedAttempts()
            
            // Force view update by triggering a state change
            DispatchQueue.main.async {
                // This will trigger a view refresh
            }
        }
    }
}

#if DEBUG
struct PasscodePromptView_Previews: PreviewProvider {
    static var previews: some View {
        PasscodePromptView()
    }
}
#endif
