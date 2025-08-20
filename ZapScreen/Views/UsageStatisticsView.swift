//
//  UsageStatisticsView.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import SwiftUI

struct UsageStatisticsView: View {
    @StateObject private var viewModel = UsageStatisticsViewModel()
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.usageStatistics.isEmpty {
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
                } else {
                    ForEach(viewModel.usageStatistics) { stat in
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
            }
            .navigationTitle("Usage Statistics")
            .onAppear {
                viewModel.loadUsageStatistics()
            }
            .refreshable {
                viewModel.loadUsageStatistics()
            }
        }
    }
}

#Preview {
    UsageStatisticsView()
}
