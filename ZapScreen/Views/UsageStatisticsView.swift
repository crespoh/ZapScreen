//
//  UsageStatisticsView.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import SwiftUI

struct UsageStatisticsView: View {
    @StateObject private var viewModel = UsageStatisticsViewModel()
    @State private var showingDateRangePicker = false
    @State private var showingSortOptions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Summary Header
                summaryHeader
                
                // Filter and Sort Controls
                filterSortControls
                
                // Statistics List
                statisticsList
            }
            .navigationTitle("Usage Statistics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Filter") {
                        showingDateRangePicker = true
                    }
                }
            }
            .sheet(isPresented: $showingDateRangePicker) {
                DateRangePickerView(selectedRange: $viewModel.selectedDateRange)
            }
            .onAppear {
                viewModel.loadUsageStatistics()
            }
            .refreshable {
                viewModel.loadUsageStatistics()
            }
        }
    }
    
    private var summaryHeader: some View {
        VStack(spacing: 12) {
            Text(viewModel.selectedDateRange.displayName)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(viewModel.summaryStatistics.totalApps)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(viewModel.summaryStatistics.totalRequests)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Requests")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(viewModel.summaryStatistics.totalMinutes)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var filterSortControls: some View {
        HStack {
            Button(action: { showingSortOptions = true }) {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(viewModel.sortOption.rawValue)
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
            
            Spacer()
            
            Text(viewModel.selectedDateRange.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var statisticsList: some View {
        List {
            if viewModel.usageStatistics.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.usageStatistics) { stat in
                    enhancedStatisticsRow(stat)
                }
            }
        }
        .actionSheet(isPresented: $showingSortOptions) {
            ActionSheet(
                title: Text("Sort By"),
                buttons: UsageStatisticsViewModel.SortOption.allCases.map { option in
                    .default(Text(option.rawValue)) {
                        viewModel.changeSortOption(option)
                    }
                } + [.cancel()]
            )
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Usage Statistics")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Statistics will appear here once apps have been approved for unshielding")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
    }
    
    private func enhancedStatisticsRow(_ stat: UsageStatistics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stat.appName)
                    .font(.headline)
                Spacer()
                Text("\(stat.totalRequestsApproved) requests")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Total time approved:")
                    .font(.subheadline)
                Spacer()
                Text("\(stat.totalTimeApprovedMinutes) minutes")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            // Date-based usage indicators
            HStack(spacing: 16) {
                if stat.todayUsage.minutes > 0 {
                    VStack(alignment: .leading) {
                        Text("Today")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(stat.todayUsage.minutes)m")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                if stat.thisWeekUsage.minutes > 0 {
                    VStack(alignment: .leading) {
                        Text("This Week")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(stat.thisWeekUsage.minutes)m")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                if stat.thisMonthUsage.minutes > 0 {
                    VStack(alignment: .leading) {
                        Text("This Month")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(stat.thisMonthUsage.minutes)m")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
                
                Spacer()
            }
            
            if let lastDate = stat.lastApprovedDate {
                HStack {
                    Text("Last approved:")
                        .font(.caption)
                    Spacer()
                    Text(lastDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    UsageStatisticsView()
}
