import SwiftUI

struct PasscodePromptView: View {
    @StateObject private var passcodeManager = PasscodeManager.shared
    @State private var enteredPasscode = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isValidating = false
    @State private var lockoutTimer: Timer?
    @State private var remainingLockoutTime: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            VStack(spacing: 10) {
                // Lock Icon
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Passcode Required")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.top, 40)
                
                // Passcode Display
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index < enteredPasscode.count ? Color.blue : Color(.systemGray4))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text(index < enteredPasscode.count ? "•" : "")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                }
                .padding(.vertical, 20)
                
                // Status Messages
                if let _ = passcodeManager.lockoutUntil, remainingLockoutTime > 0 {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Too many failed attempts")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        
                        Text("Try again in \(remainingLockoutTime) seconds")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
                    .padding(.horizontal)
                } else if passcodeManager.remainingAttempts < 3 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(passcodeManager.remainingAttempts) attempts remaining")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.1))
                    )
                    .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // Numeric Keypad
            VStack(spacing: 20) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    ForEach(1...9, id: \.self) { number in
                        NumberButton(number: "\(number)") {
                            addDigit("\(number)")
                        }
                        .disabled(isLockedOut || isValidating)
                    }
                    
                    // Bottom row: Clear, 0, Delete
                    Button("Clear") {
                        clearPasscode()
                    }
                    .buttonStyle(NumberButtonStyle())
                    .foregroundColor(.red)
                    .disabled(isLockedOut || isValidating)
                    
                    NumberButton(number: "0") {
                        addDigit("0")
                    }
                    .disabled(isLockedOut || isValidating)
                    
                    Button("⌫") {
                        deleteLastDigit()
                    }
                    .buttonStyle(NumberButtonStyle())
                    .foregroundColor(.orange)
                    .disabled(isLockedOut || isValidating)
                }
                .padding(.horizontal, 40)
                
                if isValidating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Validating...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)
                }
            }
            
            // Help Text - Increased spacing from keypad
            VStack(spacing: 8) {
                Text("Ask your parent to unlock this section")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40) // Increased from implicit spacing to 40
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 20)
        .background(Color(.systemBackground))
        .onAppear {
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
        
        // Automatically validate when 4 digits are entered
        if enteredPasscode.count == 4 {
            validatePasscode()
        }
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
        
        // Async validation that checks Supabase first
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
