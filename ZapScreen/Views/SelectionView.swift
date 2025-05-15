//
//  SelectionView.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import SwiftUI

enum UserRole: String, CaseIterable, Identifiable {
    case parent = "Parent"
    case child = "Child"
    var id: String { rawValue }

    static var selectionCases: [UserRole] {
        return [.parent, .child]
    }
}

struct SelectionView: View {
    let onSelect: (UserRole) -> Void
    var body: some View {
        VStack(spacing: 32) {
            Text("Who is using this device?")
                .font(.title)
                .padding(.top, 60)
            ForEach(UserRole.selectionCases) { role in
                Button(action: {
                    onSelect(role)
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.2))
                        Text(role.rawValue)
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                }
                .padding(.horizontal)
            }
            Spacer()
        }
        .padding()
    }
}
