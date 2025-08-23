import SwiftUI

struct ChatView: View {
    @StateObject private var chatManager = ChatManager.shared
    @State private var selectedSession: ChatSession?
    @State private var showingNewMessage = false
    @State private var messageInput = MessageInput()
    @State private var selectedFilter: ChatFilter = .all
    @State private var showingUnlockRequest = false
    @State private var selectedApp: String = ""
    @State private var selectedDuration: Int = 5
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with filter
                VStack(spacing: 12) {
                    HStack {
                        Text("Chat")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // No need for manual chat creation - chats are auto-created for family members
                        Text("Family Chats")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Filter Picker
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(ChatFilter.allCases, id: \.self) { filter in
                            HStack {
                                Image(systemName: filter.icon)
                                Text(filter.displayName)
                            }
                            .tag(filter)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Chat Sessions List
                if chatManager.isLoading {
                    Spacer()
                    ProgressView("Loading chats...")
                    Spacer()
                } else if chatManager.chatSessions.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Family Members Found")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("Chat sessions will appear here when you have registered family members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Go to Family Dashboard") {
                            // This would navigate to family dashboard to add members
                            print("Navigate to family dashboard")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(filteredSessions) { session in
                            ChatSessionRow(session: session)
                                .onTapGesture {
                                    selectedSession = session
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationBarHidden(true)
            // Remove manual chat creation - chats are auto-created for family members
            .navigationDestination(isPresented: Binding(
                get: { selectedSession != nil },
                set: { if !$0 { selectedSession = nil } }
            )) {
                if let session = selectedSession {
                    ChatDetailView(session: session)
                }
            }
            .onAppear {
                Task {
                    print("[ChatView] onAppear - Starting chat session loading...")
                    // First load existing chat sessions
                    await chatManager.loadChatSessions()
                    print("[ChatView] onAppear - Loaded \(chatManager.chatSessions.count) existing chat sessions")
                    // Then ensure chat sessions exist for all family members
                    await chatManager.loadFamilyMembersAndCreateChats()
                    print("[ChatView] onAppear - After family member sync, total sessions: \(chatManager.chatSessions.count)")
                }
            }
            .refreshable {
                await chatManager.loadChatSessions()
            }
        }
    }
    
    private var filteredSessions: [ChatSession] {
        switch selectedFilter {
        case .all:
            return chatManager.chatSessions
        case .unlockRequests:
            // Filter sessions that have unlock request messages
            return chatManager.chatSessions.filter { session in
                // This would need to be implemented with actual message filtering
                true // For now, show all
            }
        case .responses:
            // Filter sessions that have response messages
            return chatManager.chatSessions.filter { session in
                // This would need to be implemented with actual message filtering
                true // For now, show all
            }
        case .pending:
            // Filter sessions with pending requests
            return chatManager.chatSessions.filter { session in
                // This would need to be implemented with actual message filtering
                true // For now, show all
            }
        }
    }
}

// MARK: - Chat Session Row

struct ChatSessionRow: View {
    let session: ChatSession
    
    // Determine the display name based on current device's role
    private var displayName: String {
        // Get current device ID from group UserDefaults
        guard let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") else {
            return session.childName // Fallback if group defaults unavailable
        }
        
        let currentDeviceId = groupDefaults.string(forKey: "ZapDeviceId") ?? ""
        
        if session.parentDeviceId == currentDeviceId {
            // Current device is parent, show child name
            return session.childName
        } else if session.childDeviceId == currentDeviceId {
            // Current device is child, show parent name
            return session.parentName ?? "Parent"
        } else {
            // Fallback to child name if device role can't be determined
            return session.childName
        }
    }
    
    // Get first character for avatar
    private var avatarInitial: String {
        String(displayName.prefix(1)).uppercased()
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(avatarInitial)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if let lastMessageAt = session.lastMessageAt {
                        Text(lastMessageAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Last message")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if session.unreadCount > 0 {
                        Text("\(session.unreadCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Family-Based Chat System
// Chat sessions are automatically created for registered family members
// No manual chat creation needed

// MARK: - Chat Detail View

struct ChatDetailView: View {
    let session: ChatSession
    @StateObject private var chatManager = ChatManager.shared
    @State private var messageInput = MessageInput()
    @State private var showingUnlockRequest = false
    @State private var selectedApp = ""
    @State private var selectedDuration = 5
    @State private var showingAppPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            if chatManager.isLoading {
                Spacer()
                ProgressView("Loading messages...")
                Spacer()
            } else if chatManager.currentMessages.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "message.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No Messages Yet")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text("Start the conversation by sending a message")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatManager.currentMessages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .onChange(of: chatManager.currentMessages.count) { _ in
                        scrollToLatestMessage(proxy: proxy)
                    }
                    .onAppear {
                        // Scroll to latest message when view appears
                        scrollToLatestMessage(proxy: proxy)
                    }
                }
            }
            
            // Message Input
            MessageInputView(
                messageInput: $messageInput,
                onSend: sendMessage,
                onUnlockRequest: {
                    showingUnlockRequest = true
                }
            )
        }
        .navigationTitle(session.childName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Unlock Request") {
                    showingUnlockRequest = true
                }
                .font(.caption)
            }
        }
        .sheet(isPresented: $showingUnlockRequest) {
            UnlockRequestView(session: session)
        }
        .onAppear {
            Task {
                await chatManager.loadMessages(for: session.id)
            }
        }
        .refreshable {
            await chatManager.loadMessages(for: session.id)
        }
    }
    
    private func sendMessage() {
        guard messageInput.isValid else { return }
        
        // Store the message text before clearing
        let messageText = messageInput.text
        
        // Clear the input immediately for better UX
        messageInput.clear()
        
        Task {
            do {
                try await chatManager.sendMessage(
                    messageText,
                    sessionId: session.id
                )
            } catch {
                print("[ChatDetailView] Failed to send message: \(error)")
                // Restore the message text if sending failed
                await MainActor.run {
                    messageInput.text = messageText
                }
            }
        }
    }
    
    private func scrollToLatestMessage(proxy: ScrollViewProxy) {
        guard !chatManager.currentMessages.isEmpty else { return }
        
        if let lastMessage = chatManager.currentMessages.last {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    @StateObject private var chatManager = ChatManager.shared
    
    private var isFromCurrentUser: Bool {
        // Get device ID from group UserDefaults for consistency
        guard let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") else {
            return false // Fallback if group defaults unavailable
        }
        
        let currentDeviceId = groupDefaults.string(forKey: "ZapDeviceId") ?? ""
        return message.senderId == currentDeviceId
    }
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message content
                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 8) {
                    if message.isUnlockRequest {
                        UnlockRequestBubble(message: message)
                    } else if message.isUnlockResponse {
                        UnlockResponseBubble(message: message)
                    } else {
                        Text(message.content)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(isFromCurrentUser ? Color.blue : Color(.systemGray6))
                            .foregroundColor(isFromCurrentUser ? .white : .primary)
                            .cornerRadius(18)
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                    }
                }
                
                // Timestamp and sender name
                HStack {
                    if !isFromCurrentUser {
                        Text(message.senderName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                    
//                    Spacer()
                    
                    Text(message.formattedTimestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)
                }
                .padding(.horizontal, 4)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Unlock Request Bubble

struct UnlockRequestBubble: View {
    let message: ChatMessage
    @StateObject private var chatManager = ChatManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lock.open")
                    .foregroundColor(.orange)
                Text("Unlock Request")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let appName = message.appName {
                    Text("App: \(appName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                if let duration = message.requestedDuration {
                    Text("Duration: \(duration) minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Unlock Response Bubble

struct UnlockResponseBubble: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.shield")
                    .foregroundColor(.green)
                Text("Response")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let status = message.unlockStatus {
                    HStack {
                        Image(systemName: status.icon)
                            .foregroundColor(status.color)
                        Text(status.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(status.color)
                    }
                }
                
                if let response = message.parentResponse {
                    Text(response)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Message Input View

struct MessageInputView: View {
    @Binding var messageInput: MessageInput
    let onSend: () -> Void
    let onUnlockRequest: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                Button(action: onUnlockRequest) {
                    Image(systemName: "lock.open")
                        .font(.title3)
                        .foregroundColor(.orange)
                }
                
                TextField("Type a message...", text: $messageInput.text, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)
                
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .disabled(!messageInput.isValid)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Unlock Request View

struct UnlockRequestView: View {
    let session: ChatSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatManager = ChatManager.shared
    @State private var selectedApp = ""
    @State private var selectedDuration = 5
    @State private var requestMessage = ""
    @State private var isSending = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "lock.open")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Request App Unlock")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Ask your parent to unlock an app for you")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("App Name")
                            .font(.headline)
                        
                        TextField("Enter app name", text: $selectedApp)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration (minutes)")
                            .font(.headline)
                        
                        Picker("Duration", selection: $selectedDuration) {
                            ForEach([5, 10, 15, 30, 60], id: \.self) { duration in
                                Text("\(duration) minutes").tag(duration)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message (optional)")
                            .font(.headline)
                        
                        TextField("Why do you need this app?", text: $requestMessage, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(2...4)
                    }
                }
                .padding(.horizontal)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                Button("Send Request") {
                    sendUnlockRequest()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedApp.isEmpty || isSending)
                .padding(.bottom, 20)
            }
            .navigationTitle("Unlock Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sendUnlockRequest() {
        guard !selectedApp.isEmpty else { return }
        
        isSending = true
        errorMessage = ""
        
        Task {
            do {
                try await chatManager.sendUnlockRequest(
                    appName: selectedApp,
                    appBundleId: selectedApp.lowercased().replacingOccurrences(of: " ", with: "_"),
                    duration: selectedDuration,
                    message: requestMessage.isEmpty ? nil : requestMessage,
                    sessionId: session.id
                )
                
                await MainActor.run {
                    isSending = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSending = false
                }
            }
        }
    }
}

#if DEBUG
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
    }
}
#endif
