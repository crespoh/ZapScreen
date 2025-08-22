import Foundation
import SwiftUI
import Combine

@MainActor
class ChatManager: ObservableObject {
    static let shared = ChatManager()
    
    @Published var chatSessions: [ChatSession] = []
    @Published var currentMessages: [ChatMessage] = []
    @Published var pendingRequests: [UnlockRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var currentSessionId: UUID?
    private var autoRefreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAutoRefresh()
    }
    
    deinit {
        autoRefreshTimer?.invalidate()
    }
    
    // MARK: - Chat Sessions Management
    
    func loadChatSessions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            await restoreSessionFromAppGroup()
            guard let userId = SupabaseManager.shared.client.auth.currentUser?.id.uuidString else {
                throw ChatError.notAuthenticated
            }
            
            let response = try await SupabaseManager.shared.client
                .from("chat_sessions")
                .select()
                .or("parent_device_id.eq.\(userId),child_device_id.eq.\(userId)")
                .order("last_message_at", ascending: false)
                .execute()
            
            let data = response.data
            let sessions = try JSONDecoder().decode([ChatSession].self, from: data)
            
            chatSessions = sessions
            print("[ChatManager] Loaded \(sessions.count) chat sessions")
            
        } catch {
            errorMessage = "Failed to load chat sessions: \(error.localizedDescription)"
            print("[ChatManager] Error loading chat sessions: \(error)")
        }
        
        isLoading = false
    }
    
    /// Automatically create chat sessions for registered family members
    func createChatSessionForFamilyMember(childDeviceId: String, childName: String) async throws -> ChatSession {
        await restoreSessionFromAppGroup()
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id.uuidString else {
            throw ChatError.notAuthenticated
        }
        
        // Check if chat session already exists
        let existingSessions = chatSessions.filter { session in
            session.childDeviceId == childDeviceId
        }
        
        if !existingSessions.isEmpty {
            print("[ChatManager] Chat session already exists for child: \(childName)")
            return existingSessions.first!
        }
        
        let session = ChatSession(
            parentDeviceId: userId,
            childDeviceId: childDeviceId,
            childName: childName
        )
        
        let response = try await SupabaseManager.shared.client
            .from("chat_sessions")
            .insert([
                "parent_device_id": session.parentDeviceId,
                "child_device_id": session.childDeviceId,
                "child_name": session.childName
            ])
            .execute()
        
        let data = response.data
        let createdSession = try JSONDecoder().decode([ChatSession].self, from: data).first!
        
        // Add to local sessions
        chatSessions.insert(createdSession, at: 0)
        
        print("[ChatManager] Created chat session for family member: \(childName)")
        return createdSession
    }
    
    /// Load family members and create chat sessions automatically
    func loadFamilyMembersAndCreateChats() async {
        await restoreSessionFromAppGroup()
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id.uuidString else {
            print("[ChatManager] No authenticated user found")
            return
        }
        
        do {
            // Get family members from existing family system
            let familyMembers = try await SupabaseManager.shared.getChildrenForParent()
            
            // Create chat sessions for each family member
            for member in familyMembers {
                try await createChatSessionForFamilyMember(
                    childDeviceId: member.device_id,
                    childName: member.child_name
                )
            }
            
            print("[ChatManager] Created chat sessions for \(familyMembers.count) family members")
            
        } catch {
            print("[ChatManager] Error loading family members: \(error)")
        }
    }
    
    // MARK: - Messages Management
    
    func loadMessages(for sessionId: UUID, limit: Int = 50) async {
        isLoading = true
        errorMessage = nil
        currentSessionId = sessionId
        
        do {
            await restoreSessionFromAppGroup()
            
            let response = try await SupabaseManager.shared.client
                .rpc("get_chat_messages", params: [
                    "p_session_id": sessionId.uuidString,
                    "p_limit": String(limit),
                    "p_offset": "0"
                ])
                .execute()
            
            let data = response.data
            let messages = try JSONDecoder().decode([ChatMessage].self, from: data)
            
            // Reverse to show oldest first
            currentMessages = messages.reversed()
            print("[ChatManager] Loaded \(messages.count) messages for session: \(sessionId)")
            
        } catch {
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
            print("[ChatManager] Error loading messages: \(error)")
        }
        
        isLoading = false
    }
    
    func sendMessage(_ content: String, type: MessageType = .text, sessionId: UUID) async throws {
        await restoreSessionFromAppGroup()
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id.uuidString else {
            throw ChatError.notAuthenticated
        }
        
        let deviceName = UserDefaults.standard.string(forKey: "DeviceName") ?? "Unknown Device"
        
        let message = ChatMessage(
            senderId: userId,
            senderName: deviceName,
            messageType: type,
            content: content
        )
        
        let response = try await SupabaseManager.shared.client
            .from("chat_messages")
            .insert([
                "session_id": sessionId.uuidString,
                "sender_id": message.senderId,
                "sender_name": message.senderName,
                "message_type": message.messageType.rawValue,
                "content": message.content
            ])
            .execute()
        
        let data = response.data
        let createdMessage = try JSONDecoder().decode([ChatMessage].self, from: data).first!
        
        // Add to current messages
        currentMessages.append(createdMessage)
        
        // Update session last message time
        await updateSessionLastMessage(sessionId: sessionId)
        
        print("[ChatManager] Sent message: \(content)")
    }
    
    func sendUnlockRequest(appName: String, appBundleId: String, duration: Int, message: String?, sessionId: UUID) async throws {
        await restoreSessionFromAppGroup()
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id.uuidString else {
            throw ChatError.notAuthenticated
        }
        
        let deviceName = UserDefaults.standard.string(forKey: "DeviceName") ?? "Unknown Device"
        
        // Create unlock request
        let unlockRequest = UnlockRequest(
            childDeviceId: userId,
            childName: deviceName,
            appName: appName,
            appBundleId: appBundleId,
            requestedDuration: duration,
            requestMessage: message
        )
        
        let requestResponse = try await SupabaseManager.shared.client
            .from("unlock_requests")
            .insert([
                "child_device_id": unlockRequest.childDeviceId,
                "child_name": unlockRequest.childName,
                "app_name": unlockRequest.appName,
                "app_bundle_id": unlockRequest.appBundleId,
                "requested_duration": String(unlockRequest.requestedDuration),
                "request_message": unlockRequest.requestMessage
            ])
            .execute()
        
        let requestData = requestResponse.data
        let createdRequest = try JSONDecoder().decode([UnlockRequest].self, from: requestData).first!
        
        // Send chat message about the unlock request
        let content = "Requested to unlock \(appName) for \(duration) minutes"
        let chatMessage = ChatMessage(
            senderId: userId,
            senderName: deviceName,
            messageType: .unlockRequest,
            content: content,
            unlockRequestId: createdRequest.id.uuidString,
            appName: appName,
            requestedDuration: duration,
            unlockStatus: .pending
        )
        
        let messageResponse = try await SupabaseManager.shared.client
            .from("chat_messages")
            .insert([
                "session_id": sessionId.uuidString,
                "sender_id": chatMessage.senderId,
                "sender_name": chatMessage.senderName,
                "message_type": chatMessage.messageType.rawValue,
                "content": chatMessage.content,
                "unlock_request_id": chatMessage.unlockRequestId,
                "app_name": chatMessage.appName,
                "requested_duration": chatMessage.requestedDuration.map(String.init),
                "unlock_status": chatMessage.unlockStatus?.rawValue
            ])
            .execute()
        
        let messageData = messageResponse.data
        let createdMessage = try JSONDecoder().decode([ChatMessage].self, from: messageData).first!
        
        // Add to current messages
        currentMessages.append(createdMessage)
        
        // Update session last message time
        await updateSessionLastMessage(sessionId: sessionId)
        
        print("[ChatManager] Sent unlock request for \(appName)")
    }
    
    // MARK: - Unlock Request Management
    
    func loadPendingRequests() async {
        isLoading = true
        errorMessage = nil
        
        do {
            await restoreSessionFromAppGroup()
            guard let userId = SupabaseManager.shared.client.auth.currentUser?.id.uuidString else {
                throw ChatError.notAuthenticated
            }
            
            let response = try await SupabaseManager.shared.client
                .rpc("get_pending_unlock_requests", params: [
                    "p_parent_device_id": userId
                ])
                .execute()
            
            let data = response.data
            let requests = try JSONDecoder().decode([UnlockRequest].self, from: data)
            
            pendingRequests = requests
            print("[ChatManager] Loaded \(requests.count) pending requests")
            
        } catch {
            errorMessage = "Failed to load pending requests: \(error.localizedDescription)"
            print("[ChatManager] Error loading pending requests: \(error)")
        }
        
        isLoading = false
    }
    
    func respondToUnlockRequest(requestId: UUID, status: UnlockRequestStatus, response: String?) async throws {
        await restoreSessionFromAppGroup()
        
        _ = try await SupabaseManager.shared.client
            .rpc("update_unlock_request_status", params: [
                "p_request_id": requestId.uuidString,
                "p_status": status.rawValue,
                "p_parent_response": response
            ])
            .execute()
        
        // Update local pending requests
        if let index = pendingRequests.firstIndex(where: { $0.id == requestId }) {
            pendingRequests[index].status = status
            pendingRequests[index].parentResponse = response
            pendingRequests[index].respondedAt = Date()
        }
        
        // If approved, trigger the unlock
        if status == .approved {
            if let request = pendingRequests.first(where: { $0.id == requestId }) {
                try await triggerAppUnlock(request: request)
            }
        }
        
        print("[ChatManager] Responded to unlock request: \(status.rawValue)")
    }
    
    // MARK: - Private Methods
    
    private func updateSessionLastMessage(sessionId: UUID) async {
        do {
            _ = try await SupabaseManager.shared.client
                .from("chat_sessions")
                .update(["last_message_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: sessionId.uuidString)
                .execute()
        } catch {
            print("[ChatManager] Failed to update session last message: \(error)")
        }
    }
    
    private func triggerAppUnlock(request: UnlockRequest) async throws {
        // This would integrate with the existing ShieldManager to unlock the app
        // For now, we'll just log it
        print("[ChatManager] Triggering unlock for \(request.appName) for \(request.requestedDuration) minutes")
        
        // TODO: Integrate with ShieldManager.temporarilyUnlockApplication
        // ShieldManager.shared.temporarilyUnlockApplication(...)
    }
    
    private func setupAutoRefresh() {
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if let sessionId = self?.currentSessionId {
                    await self?.loadMessages(for: sessionId)
                }
                await self?.loadPendingRequests()
            }
        }
    }
    
    private func restoreSessionFromAppGroup() async {
        await SupabaseManager.shared.restoreSessionFromAppGroup()
    }
}

// MARK: - Chat Errors

enum ChatError: Error, LocalizedError {
    case notAuthenticated
    case sessionNotFound
    case invalidMessage
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You are not authenticated"
        case .sessionNotFound:
            return "Chat session not found"
        case .invalidMessage:
            return "Invalid message format"
        case .networkError:
            return "Network error occurred"
        }
    }
}
