//
//  RequiredTextField.swift
//  GlimpseH4H
//

import SwiftUI

struct RequiredTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label) (required)")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder.isEmpty ? label : placeholder, text: $text)
        }
    }
}
