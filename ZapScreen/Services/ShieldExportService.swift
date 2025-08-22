//
//  ShieldExportService.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import UIKit

class ShieldExportService {
    static let shared = ShieldExportService()
    
    private init() {}
    
    // MARK: - CSV Export
    
    func exportToCSV(data: ShieldExportData) -> String {
        var csv = "Family Shield Settings Report\n"
        csv += "Generated: \(data.formattedExportDate)\n"
        csv += "Family: \(data.familyName)\n"
        csv += "Total Children: \(data.totalChildren)\n"
        csv += "Total Apps: \(data.totalApps)\n"
        csv += "Total Shielded Apps: \(data.totalShieldedApps)\n"
        csv += "Total Unshielded Apps: \(data.totalUnshieldedApps)\n"
        csv += "Overall Shielded Percentage: \(String(format: "%.1f", data.overallShieldedPercentage))%\n\n"
        
        // Add headers
        csv += "Child Name,Device ID,App Name,Status,Shield Type,Unlock Expiry,Last Updated\n"
        
        // Add data rows
        for child in data.childrenData {
            // Add shielded apps
            for app in child.shieldedApps {
                csv += "\(child.childName),\(child.deviceId),\(app.appName),Shielded,\(app.shieldType),,\(app.formattedLastUpdated)\n"
            }
            
            // Add unshielded apps
            for app in child.unshieldedApps {
                let expiry = app.unlockExpiry?.formatted(date: .abbreviated, time: .shortened) ?? "No expiry"
                csv += "\(child.childName),\(child.deviceId),\(app.appName),Unshielded,Temporary,\(expiry),\(app.formattedLastUpdated)\n"
            }
        }
        
        return csv
    }
    
    // MARK: - PDF Export
    
    func exportToPDF(data: ShieldExportData) -> Data? {
        let pdfMetaData = [
            kCGPDFContextCreator: "ZapScreen",
            kCGPDFContextAuthor: "Family Shield Report",
            kCGPDFContextTitle: "Shield Settings Report"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let pdfData = renderer.pdfData { context in
            context.beginPage()
            
            let titleAttributes = [
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 24),
                NSAttributedString.Key.foregroundColor: UIColor.black
            ]
            
            let headerAttributes = [
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 16),
                NSAttributedString.Key.foregroundColor: UIColor.black
            ]
            
            let bodyAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
                NSAttributedString.Key.foregroundColor: UIColor.black
            ]
            
            let smallAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10),
                NSAttributedString.Key.foregroundColor: UIColor.darkGray
            ]
            
            var yPosition: CGFloat = 50
            
            // Title
            "Family Shield Settings Report".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40
            
            // Summary
            "Generated: \(data.formattedExportDate)".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: bodyAttributes)
            yPosition += 20
            
            "Family: \(data.familyName)".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: bodyAttributes)
            yPosition += 20
            
            "Total Children: \(data.totalChildren)".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: bodyAttributes)
            yPosition += 20
            
            "Total Apps: \(data.totalApps)".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: bodyAttributes)
            yPosition += 20
            
            "Overall Shielded Percentage: \(String(format: "%.1f", data.overallShieldedPercentage))%".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: bodyAttributes)
            yPosition += 40
            
            // Children details
            for child in data.childrenData {
                // Check if we need a new page
                if yPosition > 700 {
                    context.beginPage()
                    yPosition = 50
                }
                
                // Child header
                "\(child.childName) (\(child.deviceId))".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: headerAttributes)
                yPosition += 25
                
                "Total Apps: \(child.totalApps), Shielded: \(child.shieldedApps.count), Unshielded: \(child.unshieldedApps.count)".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: bodyAttributes)
                yPosition += 20
                
                // Apps list
                for app in child.shieldedApps {
                    let status = "🛡️ \(app.appName) - Shielded (\(app.shieldType))"
                    status.draw(at: CGPoint(x: 70, y: yPosition), withAttributes: bodyAttributes)
                    yPosition += 15
                }
                
                for app in child.unshieldedApps {
                    let expiry = app.unlockExpiry?.formatted(date: .abbreviated, time: .shortened) ?? "No expiry"
                    let status = "🔓 \(app.appName) - Unshielded (Expires: \(expiry))"
                    status.draw(at: CGPoint(x: 70, y: yPosition), withAttributes: bodyAttributes)
                    yPosition += 15
                }
                
                yPosition += 20
            }
        }
        
        return pdfData
    }
    
    // MARK: - File Management
    
    func saveToDocuments(data: Data, filename: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("[ShieldExportService] Failed to save file: \(error)")
            return nil
        }
    }
    
    func shareFile(data: Data, filename: String, from viewController: UIViewController) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            
            let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            // For iPad
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            viewController.present(activityViewController, animated: true)
            
        } catch {
            print("[ShieldExportService] Failed to save file for sharing: \(error)")
        }
    }
}
