//
//  IdentificationCardView.swift
//  GlimpseH4H
//

import SwiftUI

struct IdentificationCardView: View {
    let person: Person
    /// When present, shows "Face match" and optional confidence (e.g. 0.85 → "85%")
    var matchScore: Float?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(person.name)
                    .font(.headline)
                Spacer()
                if matchScore != nil {
                    Text(scoreLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            Text(person.relationship)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if matchScore != nil {
                Label("Face match", systemImage: "face.smiling")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    private var scoreLabel: String {
        guard let s = matchScore else { return "" }
        let pct = Int(round(s * 100))
        return "\(pct)% match"
    }
}
