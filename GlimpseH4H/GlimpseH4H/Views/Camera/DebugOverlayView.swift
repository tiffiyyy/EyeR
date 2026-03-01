//
//  DebugOverlayView.swift
//  GlimpseH4H
//
//  Debug panel for USB testing: face detection, embedding comparison, and cosine similarity.
//

import SwiftUI

struct DebugOverlayView: View {
    @ObservedObject var pipeline: IdentificationPipeline

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "ant.circle.fill")
                    .foregroundStyle(.orange)
                Text("Debug")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
            }
            Divider()
            row("Face detected", value: pipeline.debugFaceCount > 0 ? "Yes (\(pipeline.debugFaceCount))" : "No")
            row("Comparing embeddings", value: pipeline.debugIsComparing ? "Yes" : "No")
            if let pct = pipeline.debugLastCosinePercent {
                let name = pipeline.debugBestMatchName ?? "?"
                row("Best match", value: "\(name) (\(Int(pct))%)")
            } else {
                row("Best match", value: "—")
            }
            if let pct = pipeline.debugLastSecondBestPercent {
                let name = pipeline.debugSecondBestMatchName ?? "?"
                row("Second match", value: "\(name) (\(Int(pct))%)")
            } else {
                row("Second match", value: "—")
            }
            row("Threshold", value: "\(pipeline.debugMatchThresholdPercent)%")
            row("Match", value: pipeline.debugDidMatch ? "Yes" : "No")
        }
        .font(.caption)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        )
        .padding(8)
    }

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
}
