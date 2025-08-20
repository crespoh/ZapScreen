//
//  DateRangePickerView.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import SwiftUI

struct DateRangePickerView: View {
    @Binding var selectedRange: DateRange
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Quick Filters") {
                    ForEach([DateRange.today, .yesterday, .thisWeek, .lastWeek, .thisMonth, .lastMonth, .allTime], id: \.displayName) { range in
                        Button(action: {
                            selectedRange = range
                            dismiss()
                        }) {
                            HStack {
                                Text(range.displayName)
                                Spacer()
                                if selectedRange.displayName == range.displayName {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Select Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DateRangePickerView(selectedRange: .constant(.allTime))
}
