import Foundation
import SwiftUI

// MARK: - Chat Message Types

enum MessageType: String, Codable, CaseIterable {
    case text = "text"
    case unlockRequest = "unlock_request"
    case unlockResponse = "unlock_response"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .text: return "Message"
        case .unlockRequest: return "Unlock Request"
        case .unlockResponse: return "Response"
        case .system: return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "message"
        case .unlockRequest: return "lock.open"
        case .unlockResponse: return "checkmark.shield"
        case .system: return "info.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .text: return .blue
        case .unlockRequest: return .orange
        case .unlockResponse: return .green
        case .system: return .gray
        }
    }
}

// MARK: - Unlock Request Status

enum UnlockRequestStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case denied = "denied"
    case expired = "expired"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .denied: return "Denied"
        case .expired: return "Expired"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .approved: return .green
        case .denied: return .red
        case .expired: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .approved: return "checkmark.circle"
        case .denied: return "xmark.circle"
        case .expired: return "exclamationmark.circle"
        }
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let senderId: String
    let senderName: String
    let receiverId: String
    let receiverName: String
    let messageType: MessageType
    let content: String
    let timestamp: Date
    let isRead: Bool
    
    // For unlock request messages
    let unlockRequestId: String?
    let appName: String?
    let requestedDuration: Int? // minutes
    let unlockStatus: UnlockRequestStatus?
    let parentResponse: String?
    
    init(
        id: UUID = UUID(),
        senderId: String,
        senderName: String,
        receiverId: String,
        receiverName: String,
        messageType: MessageType,
        content: String,
        timestamp: Date = Date(),
        isRead: Bool = false,
        unlockRequestId: String? = nil,
        appName: String? = nil,
        requestedDuration: Int? = nil,
        unlockStatus: UnlockRequestStatus? = nil,
        parentResponse: String? = nil
    ) {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.receiverId = receiverId
        self.receiverName = receiverName
        self.messageType = messageType
        self.content = content
        self.timestamp = timestamp
        self.isRead = isRead
        self.unlockRequestId = unlockRequestId
        self.appName = appName
        self.requestedDuration = requestedDuration
        self.unlockStatus = unlockStatus
        self.parentResponse = parentResponse
    }
    
    var isUnlockRequest: Bool {
        messageType == .unlockRequest
    }
    
    var isUnlockResponse: Bool {
        messageType == .unlockResponse
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case senderName = "sender_name"
        case receiverId = "receiver_id"
        case receiverName = "receiver_name"
        case messageType = "message_type"
        case content
        case timestamp
        case isRead = "is_read"
        case unlockRequestId = "unlock_request_id"
        case appName = "app_name"
        case requestedDuration = "requested_duration"
        case unlockStatus = "unlock_status"
        case parentResponse = "parent_response"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        senderId = try container.decode(String.self, forKey: .senderId)
        senderName = try container.decode(String.self, forKey: .senderName)
        receiverId = try container.decode(String.self, forKey: .receiverId)
        receiverName = try container.decode(String.self, forKey: .receiverName)
        messageType = try container.decode(MessageType.self, forKey: .messageType)
        content = try container.decode(String.self, forKey: .content)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        
        // Handle timestamp decoding with fallback
        if let timestampString = try? container.decode(String.self, forKey: .timestamp) {
            timestamp = ISO8601DateFormatter().date(from: timestampString) ?? Date()
        } else {
            timestamp = Date()
        }
        
        // Handle optional fields
        unlockRequestId = try container.decodeIfPresent(String.self, forKey: .unlockRequestId)
        appName = try container.decodeIfPresent(String.self, forKey: .appName)
        
        // Handle requestedDuration - might be string or int
        if let durationString = try? container.decode(String.self, forKey: .requestedDuration) {
            requestedDuration = Int(durationString)
        } else {
            requestedDuration = try container.decodeIfPresent(Int.self, forKey: .requestedDuration)
        }
        
        // Handle unlockStatus
        if let statusString = try? container.decode(String.self, forKey: .unlockStatus) {
            unlockStatus = UnlockRequestStatus(rawValue: statusString)
        } else {
            unlockStatus = nil
        }
        
        parentResponse = try container.decodeIfPresent(String.self, forKey: .parentResponse)
    }
}

// MARK: - Unlock Request

struct UnlockRequest: Identifiable, Codable {
    let id: UUID
    let childDeviceId: String
    let childName: String
    let appName: String
    let appBundleId: String
    let requestedDuration: Int // minutes
    let requestMessage: String?
    let timestamp: Date
    var status: UnlockRequestStatus
    var parentResponse: String?
    var respondedAt: Date?
    
    init(
        id: UUID = UUID(),
        childDeviceId: String,
        childName: String,
        appName: String,
        appBundleId: String,
        requestedDuration: Int,
        requestMessage: String? = nil,
        timestamp: Date = Date(),
        status: UnlockRequestStatus = .pending,
        parentResponse: String? = nil,
        respondedAt: Date? = nil
    ) {
        self.id = id
        self.childDeviceId = childDeviceId
        self.childName = childName
        self.appName = appName
        self.appBundleId = appBundleId
        self.requestedDuration = requestedDuration
        self.requestMessage = requestMessage
        self.timestamp = timestamp
        self.status = status
        self.parentResponse = parentResponse
        self.respondedAt = respondedAt
    }
    
    var isPending: Bool {
        status == .pending
    }
    
    var isExpired: Bool {
        // Consider expired if older than 24 hours
        Date().timeIntervalSince(timestamp) > 24 * 60 * 60
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case childDeviceId = "child_device_id"
        case childName = "child_name"
        case appName = "app_name"
        case appBundleId = "app_bundle_id"
        case requestedDuration = "requested_duration"
        case requestMessage = "request_message"
        case timestamp
        case status
        case parentResponse = "parent_response"
        case respondedAt = "responded_at"
    }
}

// MARK: - Chat Session

struct ChatSession: Identifiable, Codable {
    let id: String // Changed from UUID to String to match database format
    let parentDeviceId: String
    let childDeviceId: String
    let childName: String
    let parentName: String?
    let lastMessageAt: Date?
    let unreadCount: Int
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        parentDeviceId: String,
        childDeviceId: String,
        childName: String,
        parentName: String? = nil,
        lastMessageAt: Date? = nil,
        unreadCount: Int = 0,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.parentDeviceId = parentDeviceId
        self.childDeviceId = childDeviceId
        self.childName = childName
        self.parentName = parentName
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case parentDeviceId = "parent_device_id"
        case childDeviceId = "child_device_id"
        case childName = "child_name"
        case parentName = "parent_name"
        case lastMessageAt = "last_message_at"
        case unreadCount = "unread_count"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        parentDeviceId = try container.decode(String.self, forKey: .parentDeviceId)
        childDeviceId = try container.decode(String.self, forKey: .childDeviceId)
        childName = try container.decode(String.self, forKey: .childName)
        parentName = try container.decodeIfPresent(String.self, forKey: .parentName)
        unreadCount = try container.decode(Int.self, forKey: .unreadCount)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        
        // Handle date decoding with string fallback
        if let lastMessageAtString = try? container.decode(String.self, forKey: .lastMessageAt) {
            lastMessageAt = ISO8601DateFormatter().date(from: lastMessageAtString)
        } else {
            lastMessageAt = nil
        }
        
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
        } else {
            createdAt = Date()
        }
        
        if let updatedAtString = try? container.decode(String.self, forKey: .updatedAt) {
            updatedAt = ISO8601DateFormatter().date(from: updatedAtString) ?? Date()
        } else {
            updatedAt = Date()
        }
    }
}

// MARK: - Chat Statistics

struct ChatStatistics {
    let totalMessages: Int
    let unreadMessages: Int
    let pendingRequests: Int
    let approvedRequests: Int
    let deniedRequests: Int
    
    init(
        totalMessages: Int = 0,
        unreadMessages: Int = 0,
        pendingRequests: Int = 0,
        approvedRequests: Int = 0,
        deniedRequests: Int = 0
    ) {
        self.totalMessages = totalMessages
        self.unreadMessages = unreadMessages
        self.pendingRequests = pendingRequests
        self.approvedRequests = approvedRequests
        self.deniedRequests = deniedRequests
    }
}

// MARK: - Parent Info

struct ParentInfo: Codable {
    let parentDeviceId: String
    let parentName: String
    
    enum CodingKeys: String, CodingKey {
        case parentDeviceId = "parent_device_id"
        case parentName = "parent_name"
    }
}

// MARK: - Message Input

struct MessageInput {
    var text: String = ""
    var isTyping: Bool = false
    var selectedApp: String? = nil
    var selectedDuration: Int = 5 // default 5 minutes
    
    var isValid: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    mutating func clear() {
        text = ""
        selectedApp = nil
        selectedDuration = 5
    }
}

// MARK: - Chat Filter Options

enum ChatFilter: String, CaseIterable {
    case all = "all"
    case unlockRequests = "unlock_requests"
    case responses = "responses"
    case pending = "pending"
    
    var displayName: String {
        switch self {
        case .all: return "All Messages"
        case .unlockRequests: return "Unlock Requests"
        case .responses: return "Responses"
        case .pending: return "Pending"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "message"
        case .unlockRequests: return "lock.open"
        case .responses: return "checkmark.shield"
        case .pending: return "clock"
        }
    }
}
