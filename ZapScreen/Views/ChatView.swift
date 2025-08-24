import SwiftUI

struct ChatView: View {
    @StateObject private var chatManager = ChatManager.shared
    @State private var selectedSession: ChatSession?
    @State private var messageInput = MessageInput()
    @State private var selectedFilter: ChatFilter = .all
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
                .padding()
                
                // Chat Sessions Content
                if chatManager.isLoading {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading chats...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if chatManager.chatSessions.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Family Members Found")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("Chat sessions will appear here when you have registered family members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredSessions) { session in
                                ChatSessionCard(session: session)
                                    .onTapGesture {
                                        selectedSession = session
                                    }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Family Chat")
            .navigationBarTitleDisplayMode(.inline)
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
                    await chatManager.loadChatSessions()
                    print("[ChatView] onAppear - Loaded \(chatManager.chatSessions.count) existing chat sessions")
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
            return chatManager.chatSessions.filter { session in
                true // For now, show all
            }
        case .responses:
            return chatManager.chatSessions.filter { session in
                true // For now, show all
            }
        case .pending:
            return chatManager.chatSessions.filter { session in
                true // For now, show all
            }
        }
    }
}

// MARK: - Chat Session Card (Standardized Design)

struct ChatSessionCard: View {
    let session: ChatSession
    
    private var displayName: String {
        guard let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") else {
            return session.childName
        }
        
        let currentDeviceId = groupDefaults.string(forKey: "ZapDeviceId") ?? ""
        
        if session.parentDeviceId == currentDeviceId {
            return session.childName
        } else if session.childDeviceId == currentDeviceId {
            return session.parentName ?? "Parent"
        } else {
            return session.childName
        }
    }
    
    private var avatarInitial: String {
        String(displayName.prefix(1)).uppercased()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(avatarInitial)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if let lastMessageAt = session.lastMessageAt {
                            Text(lastMessageAt, style: .relative)
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
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - Chat Detail View (Simplified)

struct ChatDetailView: View {
    let session: ChatSession
    @StateObject private var chatManager = ChatManager.shared
    @State private var messageInput = MessageInput()
    @State private var showingUnlockRequest = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            if chatManager.isLoading {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading messages...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if chatManager.currentMessages.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "message.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
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
        
        let messageText = messageInput.text
        messageInput.clear()
        
        Task {
            do {
                try await chatManager.sendMessage(
                    messageText,
                    sessionId: session.id
                )
            } catch {
                print("[ChatDetailView] Failed to send message: \(error)")
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

// MARK: - Message Bubble (Simplified)

struct MessageBubble: View {
    let message: ChatMessage
    @StateObject private var chatManager = ChatManager.shared
    
    private var isFromCurrentUser: Bool {
        guard let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") else {
            return false
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
                }
                
                // Timestamp
                Text(message.formattedTimestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Unlock Request Bubble (Simplified)

struct UnlockRequestBubble: View {
    let message: ChatMessage
    
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

// MARK: - Unlock Response Bubble (Simplified)

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

// MARK: - Message Input View (Simplified)

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

// MARK: - Unlock Request View (Simplified)

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
