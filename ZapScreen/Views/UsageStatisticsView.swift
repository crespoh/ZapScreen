//
//  UsageStatisticsView.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import SwiftUI
import Charts

struct UsageStatisticsView: View {
    @StateObject private var viewModel = UsageStatisticsViewModel()
    @State private var selectedTimeRange: TimeRange = .today
    @State private var showingAddRecord = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Time range picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Statistics content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Summary cards
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            StatCard(
                                title: "Total Time",
                                value: viewModel.totalTimeFormatted,
                                color: .blue
                            )
                            StatCard(
                                title: "Total Requests",
                                value: "\(viewModel.totalRequests)",
                                color: .green
                            )
                        }
                        .padding(.horizontal)
                        
                        // Chart
                        if !viewModel.usageData.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Usage Over Time")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                Chart {
                                    ForEach(viewModel.usageData, id: \.date) { data in
                                        BarMark(
                                            x: .value("Date", data.date, unit: .day),
                                            y: .value("Minutes", data.minutes)
                                        )
                                        .foregroundStyle(Color.blue.gradient)
                                    }
                                }
                                .frame(height: 200)
                                .padding(.horizontal)
                            }
                        }
                        
                        // Usage records list
                        if !viewModel.usageRecords.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent Usage")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                LazyVStack(spacing: 8) {
                                    ForEach(viewModel.usageRecords, id: \.id) { record in
                                        UsageRecordRow(record: record)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Empty state
                        if viewModel.usageData.isEmpty && viewModel.usageRecords.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                
                                Text("No usage data available")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Usage statistics will appear here once you start using apps")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Usage Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddRecord = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRecord) {
                AddUsageRecordView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadUsageStatistics(for: selectedTimeRange)
            }
            .onChange(of: selectedTimeRange) { _, newRange in
                viewModel.loadUsageStatistics(for: newRange)
            }
            .refreshable {
                viewModel.loadUsageStatistics(for: selectedTimeRange)
            }
        }
    }
}

#Preview {
    UsageStatisticsView()
}
