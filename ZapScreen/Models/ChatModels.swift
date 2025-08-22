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
}

// MARK: - Chat Session

struct ChatSession: Identifiable, Codable {
    let id: UUID
    let parentDeviceId: String
    let childDeviceId: String
    let childName: String
    let lastMessageAt: Date
    let unreadCount: Int
    let isActive: Bool
    
    init(
        id: UUID = UUID(),
        parentDeviceId: String,
        childDeviceId: String,
        childName: String,
        lastMessageAt: Date = Date(),
        unreadCount: Int = 0,
        isActive: Bool = true
    ) {
        self.id = id
        self.parentDeviceId = parentDeviceId
        self.childDeviceId = childDeviceId
        self.childName = childName
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
        self.isActive = isActive
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
