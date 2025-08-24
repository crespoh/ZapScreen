//
//  UsageStatisticsComponents.swift
//  ZapScreen
//
//  Created by tongteknai on 18/5/25.
//

import SwiftUI

// MARK: - Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Usage Record Row Component
struct UsageRecordRow: View {
    let record: UsageRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.appName)
                    .font(.headline)
                
                Text(record.approvedDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(record.durationMinutes) min")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Text(record.approvedDate, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Add Usage Record View
struct AddUsageRecordView: View {
    @ObservedObject var viewModel: UsageStatisticsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var appName = ""
    @State private var durationMinutes = 15
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section("App Details") {
                    TextField("App Name", text: $appName)
                    
                    Stepper("Duration: \(durationMinutes) minutes", value: $durationMinutes, in: 1...120, step: 5)
                    
                    DatePicker("Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section {
                    Button("Add Record") {
                        // This would need to be implemented in the ViewModel
                        // For now, just dismiss
                        dismiss()
                    }
                    .disabled(appName.isEmpty)
                }
            }
            .navigationTitle("Add Usage Record")
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
}

// MARK: - App Status Card Component
struct AppStatusCard: View {
    let appName: String
    let isShielded: Bool
    let onRemove: () -> Void
    let showDeleteButton: Bool
    
    init(appName: String, isShielded: Bool, onRemove: @escaping () -> Void, showDeleteButton: Bool = true) {
        self.appName = appName
        self.isShielded = isShielded
        self.onRemove = onRemove
        self.showDeleteButton = showDeleteButton
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "app.fill")
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(appName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Image(systemName: isShielded ? "shield.fill" : "shield.slash")
                        .foregroundColor(isShielded ? .red : .green)
                        .font(.caption)
                    
                    Text(isShielded ? "Restricted" : "Unrestricted")
                        .font(.caption)
                        .foregroundColor(isShielded ? .red : .green)
                }
            }
            
            Spacer()
            
            // Delete button (only shown when showDeleteButton is true)
            if showDeleteButton {
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Add Activity Button Component
struct AddActivityButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Add Activity")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty State Component
struct EmptyStateView: View {
    let title: String
    let message: String
    let iconName: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
