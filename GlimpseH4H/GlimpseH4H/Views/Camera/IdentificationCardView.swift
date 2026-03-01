//
//  IdentificationCardView.swift
//  GlimpseH4H
//

import SwiftUI

struct IdentificationCardView: View {
    let person: Person

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(person.name)
                .font(.headline)
            Text(person.relationship)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !person.conversationSummary.isEmpty {
                Text(person.conversationSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .fill(AppTheme.cardBackground.opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
    }
}
