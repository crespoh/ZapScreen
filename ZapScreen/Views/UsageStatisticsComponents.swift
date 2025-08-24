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
