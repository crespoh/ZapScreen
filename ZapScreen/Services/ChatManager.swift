import Foundation
import SwiftUI
import Combine
import UIKit

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
            
            // Get current device ID instead of family account ID
            guard let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") else { 
                throw ChatError.notAuthenticated 
            }
            var currentDeviceId = groupDefaults.string(forKey: "ZapDeviceId") ?? ""
            
            // Fallback to UIDevice identifier if ZapDeviceId is empty
            if currentDeviceId.isEmpty {
                let fallbackId = UIDevice.current.identifierForVendor?.uuidString
                print("[ChatManager] loadChatSessions - UIDevice fallback ID: '\(fallbackId ?? "nil")'")
                
                if let fallbackId = fallbackId, !fallbackId.isEmpty {
                    currentDeviceId = fallbackId
                    print("[ChatManager] loadChatSessions - Using UIDevice fallback: \(currentDeviceId)")
                } else {
                    // Generate a random UUID as last resort
                    currentDeviceId = UUID().uuidString
                    print("[ChatManager] loadChatSessions - Generated random device ID: \(currentDeviceId)")
                }
            }
            
            print("[ChatManager] loadChatSessions - Current device ID: \(currentDeviceId)")
            
            let response = try await SupabaseManager.shared.client
                .from("chat_sessions")
                .select()
                .or("parent_device_id.eq.\(currentDeviceId),child_device_id.eq.\(currentDeviceId)")
                .order("last_message_at", ascending: false)
                .execute()
            
            let data = response.data
            print("[ChatManager] Raw response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            
            let sessions = try JSONDecoder().decode([ChatSession].self, from: data)
            
            // Transform sessions to show the correct participant name
            let transformedSessions = sessions.map { session in
                transformSessionForDisplay(session, currentDeviceId: currentDeviceId)
            }
            
            chatSessions = transformedSessions
            print("[ChatManager] Loaded \(sessions.count) chat sessions: \(transformedSessions.map { $0.childName })")
            print("[ChatManager] Final sessions for display:")
            for (index, session) in transformedSessions.enumerated() {
                print("[ChatManager]   Session \(index): id=\(session.id), parent=\(session.parentDeviceId), child=\(session.childDeviceId), name=\(session.childName)")
            }
            
        } catch {
            errorMessage = "Failed to load chat sessions: \(error.localizedDescription)"
            print("[ChatManager] Error loading chat sessions: \(error)")
        }
        
        isLoading = false
    }
    
    /// Automatically create chat sessions for registered family members
    /// This function works bidirectionally:
    /// - If current device is parent: creates session with child
    /// - If current device is child: creates session with parent
    func createChatSessionForFamilyMember(otherDeviceId: String, otherDeviceName: String) async throws -> ChatSession {
        await restoreSessionFromAppGroup()
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id.uuidString else {
            throw ChatError.notAuthenticated
        }
        
        guard let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") else { throw ChatError.notAuthenticated }
        var currentDeviceId = groupDefaults.string(forKey: "ZapDeviceId") ?? ""
        
        // Fallback to UIDevice identifier if ZapDeviceId is empty
        if currentDeviceId.isEmpty {
            let fallbackId = UIDevice.current.identifierForVendor?.uuidString
            print("[ChatManager] UIDevice fallback ID: '\(fallbackId ?? "nil")'")
            
            if let fallbackId = fallbackId, !fallbackId.isEmpty {
                currentDeviceId = fallbackId
                print("[ChatManager] Using UIDevice fallback: \(currentDeviceId)")
            } else {
                // Generate a random UUID as last resort
                currentDeviceId = UUID().uuidString
                print("[ChatManager] Generated random device ID: \(currentDeviceId)")
            }
        }
        
        print("[ChatManager] Creating chat session - Current device: \(currentDeviceId), Other device: \(otherDeviceId) (\(otherDeviceName))")
        
        // Determine if current device is parent or child by checking parent_child relationships
        print("[ChatManager] Checking if device \(currentDeviceId) is parent...")
        let isCurrentDeviceParent = try await checkIfDeviceIsParent(deviceId: currentDeviceId)
        print("[ChatManager] Device is parent: \(isCurrentDeviceParent)")
        
        let parentDeviceId: String
        let childDeviceId: String
        let childName: String
        
        var currentDeviceName = groupDefaults.string(forKey: "DeviceName") ?? ""
        
        // Fallback to device model if DeviceName is not set
        if currentDeviceName.isEmpty {
            currentDeviceName = UIDevice.current.model
            print("[ChatManager] Using device model as name: \(currentDeviceName)")
        }
        
        print("[ChatManager] Current device name: '\(currentDeviceName)'")
        
        if isCurrentDeviceParent {
            // Current device is parent, other device is child
            parentDeviceId = currentDeviceId
            childDeviceId = otherDeviceId
            childName = otherDeviceName
            print("[ChatManager] Current device is parent, creating session with child")
        } else {
            // Current device is child, other device is parent
            parentDeviceId = otherDeviceId
            childDeviceId = currentDeviceId
            childName = currentDeviceName // Use actual child device name
            print("[ChatManager] Current device is child, creating session with parent")
        }
        
        // Check if chat session already exists
        let existingSessions = chatSessions.filter { session in
            (session.parentDeviceId == parentDeviceId && session.childDeviceId == childDeviceId) ||
            (session.parentDeviceId == childDeviceId && session.childDeviceId == parentDeviceId)
        }
        
        if !existingSessions.isEmpty {
            print("[ChatManager] Chat session already exists between these devices")
            return existingSessions.first!
        }
        
        let parentName = isCurrentDeviceParent ? currentDeviceName : otherDeviceName
        print("[ChatManager] Final parent name: '\(parentName)'")
        
        // Ensure we have a meaningful parent name
        let finalParentName = parentName.isEmpty ? "Parent Device" : parentName
        print("[ChatManager] Final parent name after validation: '\(finalParentName)'")
        
        let session = ChatSession(
            parentDeviceId: parentDeviceId,
            childDeviceId: childDeviceId,
            childName: childName,
            parentName: finalParentName
        )
        
        print("[ChatManager] Session created - Parent ID: '\(session.parentDeviceId)', Child ID: '\(session.childDeviceId)', Parent Name: '\(session.parentName ?? "nil")', Child Name: '\(session.childName)'")
        
        let insertData = [
            "parent_device_id": session.parentDeviceId,
            "child_device_id": session.childDeviceId,
            "child_name": session.childName,
            "parent_name": finalParentName
        ]
        
        print("[ChatManager] Inserting chat session with data: \(insertData)")
        print("[ChatManager] Parent device ID: \(parentDeviceId)")
        print("[ChatManager] Child device ID: \(childDeviceId)")
        
        do {
            // Try direct insert first
            let response = try await SupabaseManager.shared.client
                .from("chat_sessions")
                .insert(insertData)
                .execute()
            
            let data = response.data
            let createdSession = try JSONDecoder().decode([ChatSession].self, from: data).first!
            
            // Transform the session for display based on current user role
            let transformedSession = transformSessionForDisplay(createdSession, currentDeviceId: currentDeviceId)
            
            // Add to local sessions
            chatSessions.insert(transformedSession, at: 0)
            
            print("[ChatManager] Successfully created chat session via direct insert")
            return transformedSession
            
        } catch {
            print("[ChatManager] Direct insert failed: \(error)")
            print("[ChatManager] Trying fallback function...")
            
            do {
                // Fallback: Use the improved RPC function
                let response = try await SupabaseManager.shared.client
                    .rpc("create_chat_session_simple", params: [
                        "p_parent_device_id": parentDeviceId,
                        "p_child_device_id": childDeviceId,
                        "p_child_name": childName,
                        "p_parent_name": finalParentName
                    ])
                    .execute()
                
                let data = response.data
                print("[ChatManager] RPC response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                
                // Decode the full session data returned by the RPC function
                // RPC returns a single object, not an array
                let createdSession = try JSONDecoder().decode(ChatSession.self, from: data)
                print("[ChatManager] Successfully decoded session from RPC response: \(createdSession.id)")
                print("[ChatManager] Created session: \(createdSession.id) for \(createdSession.childName)")
                
                // Transform the session for display based on current user role
                let transformedSession = transformSessionForDisplay(createdSession, currentDeviceId: currentDeviceId)
                
                // Add to local sessions
                chatSessions.insert(transformedSession, at: 0)
                
                print("[ChatManager] Successfully created chat session via RPC function")
                return transformedSession
                
            } catch {
                print("[ChatManager] RPC function also failed: \(error)")
                // If both methods fail, check if session already exists
                if error.localizedDescription.contains("duplicate key") {
                    print("[ChatManager] Session already exists, trying to load existing session...")
                    // Try to load the existing session
                    await loadChatSessions()
                    let existingSession = chatSessions.first { session in
                        session.childDeviceId == childDeviceId
                    }
                    if let existing = existingSession {
                        print("[ChatManager] Found existing session: \(existing.id)")
                        return existing
                    }
                }
                throw error
            }
        }
    }
    
    /// Set device name in UserDefaults for persistent storage
    private func ensureDeviceNameIsSet() {
        guard let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") else { return }
        var currentDeviceId = groupDefaults.string(forKey: "DeviceName") ?? ""
    }
    
    /// Load family members and create chat sessions automatically
    /// This function works bidirectionally based on the current device's role
    func loadFamilyMembersAndCreateChats() async {
        await restoreSessionFromAppGroup()
        
        // Ensure device name is set in UserDefaults
        ensureDeviceNameIsSet()
        
        guard SupabaseManager.shared.client.auth.currentUser?.id.uuidString != nil else {
            print("[ChatManager] No authenticated user found")
            return
        }
        
        guard let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") else { return }
        let currentDeviceId = groupDefaults.string(forKey: "ZapDeviceId") ?? ""
        
        // Debug: Check what device ID we have
        print("[ChatManager] Current device ID from UserDefaults: '\(currentDeviceId)'")
        
        // If ZapDeviceId is empty, try to get it from the device
        let deviceId = currentDeviceId.isEmpty ? UIDevice.current.identifierForVendor?.uuidString ?? "" : currentDeviceId
        print("[ChatManager] Using device ID: '\(deviceId)'")
        
        do {
            print("[ChatManager] Loading family members...")
            
            // Determine if current device is parent or child
            let isCurrentDeviceParent = try await checkIfDeviceIsParent(deviceId: deviceId)
            
            if isCurrentDeviceParent {
                // Current device is parent - get all children
                print("[ChatManager] Current device is parent, loading children...")
                let familyMembers = try await SupabaseManager.shared.getChildrenForParent()
                print("[ChatManager] Found \(familyMembers.count) children: \(familyMembers.map { $0.device_owner })")
                
                // Create chat sessions for each child
                for member in familyMembers {
                    print("[ChatManager] Creating chat session for child: \(member.device_owner) (ID: \(member.device_id))")
                    _ = try await createChatSessionForFamilyMember(
                        otherDeviceId: member.device_id,
                        otherDeviceName: member.device_owner
                    )
                }
                
                print("[ChatManager] Created chat sessions for \(familyMembers.count) children")
                
            } else {
                // Current device is child - get all parents
                print("[ChatManager] Current device is child, loading parents...")
                let parentDevices = try await SupabaseManager.shared.getParentsForChild()
                
                // Map SupabaseParentDevice to ParentInfo structure
                let parents = parentDevices.map { device in
                    ParentInfo(
                        parentDeviceId: device.device_id,
                        parentName: device.parent_name
                    )
                }
                
                print("[ChatManager] Found \(parents.count) parents: \(parents.map { $0.parentName })")
                
                // Create chat sessions for each parent
                for parent in parents {
                    print("[ChatManager] Creating chat session for parent: \(parent.parentName) (ID: \(parent.parentDeviceId))")
                    _ = try await createChatSessionForFamilyMember(
                        otherDeviceId: parent.parentDeviceId,
                        otherDeviceName: parent.parentName
                    )
                }
                
                print("[ChatManager] Created chat sessions for \(parents.count) parents")
            }
            
            print("[ChatManager] Total chat sessions now: \(chatSessions.count)")
            
        } catch {
            print("[ChatManager] Error loading family members: \(error)")
        }
    }
    
    // MARK: - Messages Management
    
    func loadMessages(for sessionId: String, limit: Int = 50) async {
        isLoading = true
        errorMessage = nil
        // Clean up the sessionId by removing extra quotes
        let cleanSessionId = sessionId.replacingOccurrences(of: "\"", with: "")
        currentSessionId = UUID(uuidString: cleanSessionId) ?? UUID()
        
        do {
            await restoreSessionFromAppGroup()
            
            let response = try await SupabaseManager.shared.client
                .rpc("get_chat_messages", params: [
                    "p_session_id": cleanSessionId,
                    "p_limit": String(limit),
                    "p_offset": "0"
                ])
                .execute()
            
            let data = response.data
            print("[ChatManager] Load messages response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            let messages = try JSONDecoder().decode([ChatMessage].self, from: data)
            
            // Debug timestamps
            for (index, message) in messages.enumerated() {
                print("[ChatManager] Message \(index): timestamp = \(message.timestamp), formatted = \(message.formattedTimestamp)")
            }
            
            // The database now returns messages in ASC order (oldest first), so we can use them directly
            // This ensures chronological order: oldest messages at top, newest at bottom
            currentMessages = messages
            print("[ChatManager] Using messages in chronological order (oldest first)")
            print("[ChatManager] Loaded \(messages.count) messages for session: \(sessionId)")
            
        } catch {
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
            print("[ChatManager] Error loading messages: \(error)")
        }
        
        isLoading = false
    }
    
    func sendMessage(_ content: String, type: MessageType = .text, sessionId: String) async throws {
        await restoreSessionFromAppGroup()
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id.uuidString else {
            throw ChatError.notAuthenticated
        }
        
        // Get device ID and name from group UserDefaults
        guard let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") else {
            throw ChatError.notAuthenticated
        }

        let deviceId = groupDefaults.string(forKey: "ZapDeviceId") ?? ""
        let deviceName = groupDefaults.string(forKey: "DeviceName") ?? "Unknown Device"
        
        // Clean up the sessionId by removing extra quotes
        let cleanSessionId = sessionId.replacingOccurrences(of: "\"", with: "")
        
        // Get session information to determine receiver
        let sessionResponse = try await SupabaseManager.shared.client
            .from("chat_sessions")
            .select()
            .eq("id", value: cleanSessionId)
            .single()
            .execute()
        
        let sessionData = sessionResponse.data
        let session = try JSONDecoder().decode(ChatSession.self, from: sessionData)
        
        // Determine receiver information based on session
        let receiverId: String
        let receiverName: String
        
        if deviceId == session.parentDeviceId {
            // Sender is parent, receiver is child
            receiverId = session.childDeviceId
            receiverName = session.childName
        } else {
            // Sender is child, receiver is parent
            receiverId = session.parentDeviceId
            receiverName = "Parent"
        }
        
        let message = ChatMessage(
            senderId: deviceId,
            senderName: deviceName,
            receiverId: receiverId,
            receiverName: receiverName,
            messageType: type,
            content: content
        )
        
        let response = try await SupabaseManager.shared.client
            .from("chat_messages")
            .insert([
                "session_id": cleanSessionId,
                "sender_id": message.senderId,
                "sender_name": message.senderName,
                "receiver_id": message.receiverId,
                "receiver_name": message.receiverName,
                "message_type": message.messageType.rawValue,
                "content": message.content
            ])
            .execute()
        
        let data = response.data
        print("[ChatManager] Insert response data: \(String(data: data, encoding: .utf8) ?? "nil")")
        
        // Handle the response - it might be empty when RLS is disabled
        if data.isEmpty {
            // Create a local message object since the response is empty
            let localMessage = ChatMessage(
                id: UUID(),
                senderId: message.senderId,
                senderName: message.senderName,
                receiverId: message.receiverId,
                receiverName: message.receiverName,
                messageType: message.messageType,
                content: message.content,
                timestamp: Date() // Use current time for local message
            )
            currentMessages.append(localMessage)
            print("[ChatManager] Created local message since response was empty")
        } else {
            // Try to decode the response
            do {
                let createdMessage = try JSONDecoder().decode([ChatMessage].self, from: data).first!
                currentMessages.append(createdMessage)
                print("[ChatManager] Successfully decoded response message with timestamp: \(createdMessage.timestamp)")
            } catch {
                print("[ChatManager] Failed to decode response: \(error)")
                // Create a local message as fallback
                let localMessage = ChatMessage(
                    id: UUID(),
                    senderId: message.senderId,
                    senderName: message.senderName,
                    receiverId: message.receiverId,
                    receiverName: message.receiverName,
                    messageType: message.messageType,
                    content: message.content,
                    timestamp: Date() // Use current time for local message
                )
                currentMessages.append(localMessage)
                print("[ChatManager] Created local message as fallback")
            }
        }
        
        // Update session last message time
        await updateSessionLastMessage(sessionId: cleanSessionId)
        
        print("[ChatManager] Sent message: \(content)")
    }
    
    func sendUnlockRequest(appName: String, appBundleId: String, duration: Int, message: String?, sessionId: String) async throws {
        await restoreSessionFromAppGroup()
        guard (SupabaseManager.shared.client.auth.currentUser?.id.uuidString) != nil else {
            throw ChatError.notAuthenticated
        }
        
        guard let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") else { throw ChatError.notAuthenticated }
        let deviceId = groupDefaults.string(forKey: "ZapDeviceId") ?? ""
        let deviceName = groupDefaults.string(forKey: "DeviceName") ?? "Unknown Device"
        
        // Create unlock request
        let unlockRequest = UnlockRequest(
            childDeviceId: deviceId,
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
        
        // Get session information to determine receiver for unlock request message
        let sessionResponse = try await SupabaseManager.shared.client
            .from("chat_sessions")
            .select()
            .eq("id", value: sessionId)
            .single()
            .execute()
        
        let sessionData = sessionResponse.data
        let session = try JSONDecoder().decode(ChatSession.self, from: sessionData)
        
        // Determine receiver information based on session
        let receiverId: String
        let receiverName: String
        
        if deviceId == session.parentDeviceId {
            // Sender is parent, receiver is child
            receiverId = session.childDeviceId
            receiverName = session.childName
        } else {
            // Sender is child, receiver is parent
            receiverId = session.parentDeviceId
            receiverName = "Parent"
        }
        
        // Send chat message about the unlock request
        let content = "Requested to unlock \(appName) for \(duration) minutes"
        let chatMessage = ChatMessage(
            senderId: deviceId,
            senderName: deviceName,
            receiverId: receiverId,
            receiverName: receiverName,
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
                "session_id": sessionId,
                "sender_id": chatMessage.senderId,
                "sender_name": chatMessage.senderName,
                "receiver_id": chatMessage.receiverId,
                "receiver_name": chatMessage.receiverName,
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
        // Clean up the sessionId by removing extra quotes
        let cleanSessionId = sessionId.replacingOccurrences(of: "\"", with: "")
        await updateSessionLastMessage(sessionId: cleanSessionId)
        
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
    
    func respondToUnlockRequest(requestId: String, status: UnlockRequestStatus, response: String?) async throws {
        await restoreSessionFromAppGroup()
        
        _ = try await SupabaseManager.shared.client
            .rpc("update_unlock_request_status", params: [
                "p_request_id": requestId,
                "p_status": status.rawValue,
                "p_parent_response": response
            ])
            .execute()
        
        // Update local pending requests
        if let index = pendingRequests.firstIndex(where: { $0.id.uuidString == requestId }) {
            pendingRequests[index].status = status
            pendingRequests[index].parentResponse = response
            pendingRequests[index].respondedAt = Date()
        }
        
        // If approved, trigger the unlock
        if status == .approved {
            if let request = pendingRequests.first(where: { $0.id.uuidString == requestId }) {
                try await triggerAppUnlock(request: request)
            }
        }
        
        print("[ChatManager] Responded to unlock request: \(status.rawValue)")
    }
    
    // MARK: - Private Methods
    
    /// Check if a device is a parent by looking up parent_child relationships
    private func checkIfDeviceIsParent(deviceId: String) async throws -> Bool {
        
        print("[ChatManager] checkIfDeviceIsParent: \(deviceId)")
        
        let response = try await SupabaseManager.shared.client
            .from("devices")
            .select("device_id")
            .eq("device_id", value: deviceId)
            .eq("is_parent", value: true)
            .execute()
        
        let data = response.data
        print("[ChatManager] checkIfDeviceIsParent - Raw response data: \(String(data: data, encoding: .utf8) ?? "nil")")
        print("[ChatManager] checkIfDeviceIsParent - Data count: \(data.count) bytes")
        print("[ChatManager] checkIfDeviceIsParent - Data is empty: \(data.isEmpty)")
        
        // Check what the raw string actually contains
        let rawString = String(data: data, encoding: .utf8) ?? ""
        print("[ChatManager] checkIfDeviceIsParent - Raw string length: \(rawString.count)")
        print("[ChatManager] checkIfDeviceIsParent - Raw string is empty: \(rawString.isEmpty)")
        
        // Try to decode and show the actual records
        do {
            let records = try JSONDecoder().decode([[String: String]].self, from: data)
            print("[ChatManager] checkIfDeviceIsParent - Decoded records: \(records)")
            print("[ChatManager] checkIfDeviceIsParent - Records count: \(records.count)")
            return !records.isEmpty
        } catch {
            print("[ChatManager] checkIfDeviceIsParent - Failed to decode records: \(error)")
            // If decoding fails, check if it's truly empty by string content
            return !rawString.isEmpty && rawString != "[]"
        }
    }
    
    /// Transform a session for display based on current user role
    private func transformSessionForDisplay(_ session: ChatSession, currentDeviceId: String) -> ChatSession {
                
        print("[ChatManager] Transform session - Original: parent=\(session.parentDeviceId), child=\(session.childDeviceId), name=\(session.childName)")
        print("[ChatManager] Transform session - Current device: \(currentDeviceId)")
        
        if session.parentDeviceId == currentDeviceId {
            // Current device is parent, show child name
            print("[ChatManager] Transform session - Device is parent, keeping original display")
            return session
        } else if session.childDeviceId == currentDeviceId {
            // Current device is child, create a session showing parent
            print("[ChatManager] Transform session - Device is child, swapping for 'Parent' display")
            let displayName = session.parentName ?? "Parent"
            let transformed = ChatSession(
                id: session.id,
                parentDeviceId: session.childDeviceId, // Swap for display
                childDeviceId: session.parentDeviceId, // Swap for display
                childName: displayName, // Show parent name or "Parent" as fallback
                parentName: session.childName, // Swap: child name becomes parent name for display
                lastMessageAt: session.lastMessageAt,
                unreadCount: session.unreadCount,
                isActive: session.isActive,
                createdAt: session.createdAt,
                updatedAt: session.updatedAt
            )
            print("[ChatManager] Transform session - Transformed: parent=\(transformed.parentDeviceId), child=\(transformed.childDeviceId), name=\(transformed.childName)")
            return transformed
        } else {
            // Neither parent nor child matches current device - this shouldn't happen
            print("[ChatManager] Transform session - WARNING: Current device not found in session")
            return session
        }
    }
    
    private func updateSessionLastMessage(sessionId: String) async {
        do {
            _ = try await SupabaseManager.shared.client
                .from("chat_sessions")
                .update(["last_message_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: sessionId)
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
                    await self?.loadMessages(for: sessionId.uuidString)
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
