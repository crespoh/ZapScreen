//
//  ShieldExportView.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import SwiftUI
import UIKit

struct ShieldExportView: View {
    @StateObject private var viewModel = ShieldExportViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportOptions = false
    @State private var showingShareSheet = false
    @State private var exportData: Data?
    @State private var exportFilename = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                    
                    Text("Export Shield Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Generate reports of your family's shield configurations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Export Options
                VStack(spacing: 16) {
                    // Format Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Export Format")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            ForEach(ExportFormat.allCases) { format in
                                Button(action: {
                                    viewModel.selectedFormat = format
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: format.icon)
                                            .font(.title2)
                                            .foregroundColor(viewModel.selectedFormat == format ? .white : .accentColor)
                                        
                                        Text(format.rawValue)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(viewModel.selectedFormat == format ? .white : .primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(viewModel.selectedFormat == format ? Color.accentColor : Color.secondary.opacity(0.1))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Filter Options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Filter Options")
                            .font(.headline)
                        
                        // Date Range
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date Range")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("Date Range", selection: $viewModel.exportFilter.dateRange) {
                                ForEach(ShieldExportDateRange.allCases) { range in
                                    Text(range.rawValue).tag(range)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Include Options
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Include")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 20) {
                                Toggle("Shielded Apps", isOn: $viewModel.exportFilter.includeShielded)
                                Toggle("Unshielded Apps", isOn: $viewModel.exportFilter.includeUnshielded)
                            }
                        }
                    }
                    
                    // Children Selection
                    if !viewModel.availableChildren.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Children to Include")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.availableChildren, id: \.deviceId) { child in
                                        Button(action: {
                                            viewModel.toggleChildSelection(child.deviceId)
                                        }) {
                                            Text(child.childName)
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .fill(viewModel.exportFilter.selectedChildren.contains(child.deviceId) ? Color.accentColor : Color.secondary.opacity(0.2))
                                                )
                                                .foregroundColor(viewModel.exportFilter.selectedChildren.contains(child.deviceId) ? .white : .primary)
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Export Button
                Button(action: {
                    Task {
                        await exportData()
                    }
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        
                        Text(viewModel.isExporting ? "Generating..." : "Export Report")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isExporting)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        viewModel.resetFilters()
                    }
                    .disabled(!viewModel.exportFilter.hasActiveFilters)
                }
            }
        }
        .onAppear {
            viewModel.loadAvailableChildren()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let data = exportData {
                ShareSheet(activityItems: [data])
            }
        }
    }
    
    private func exportData() async {
        viewModel.isExporting = true
        
        do {
            let exportData = try await viewModel.generateExportData()
            
            let data: Data
            let filename: String
            
            switch viewModel.selectedFormat {
            case .csv:
                let csvString = ShieldExportService.shared.exportToCSV(data: exportData)
                data = csvString.data(using: .utf8) ?? Data()
                filename = "shield_settings_\(Date().formatted(date: .abbreviated, time: .omitted)).csv"
                
            case .pdf:
                if let pdfData = ShieldExportService.shared.exportToPDF(data: exportData) {
                    data = pdfData
                    filename = "shield_settings_\(Date().formatted(date: .abbreviated, time: .omitted)).pdf"
                } else {
                    throw NSError(domain: "ExportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PDF"])
                }
            }
            
            self.exportData = data
            self.exportFilename = filename
            
            await MainActor.run {
                viewModel.isExporting = false
                showingShareSheet = true
            }
            
        } catch {
            await MainActor.run {
                viewModel.isExporting = false
                viewModel.error = error
            }
        }
    }
}

// MARK: - Share Sheet for UIKit Integration

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ShieldExportView()
}
