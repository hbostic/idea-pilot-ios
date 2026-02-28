//
//  ErrorBannerView.swift
//  idea-pilot
//
//  Reusable inline error banner. Non-blocking, styled with the
//  theme destructive color and a subtle border.
//

import SwiftUI

/// A non-blocking inline error banner with an icon and message.
///
/// Replaces per-screen copy-pasted error banners with a single
/// shared component. Styled with destructive color, 0.1 opacity
/// background, and a subtle border.
struct ErrorBannerView: View {

    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
            Text(message)
                .font(.theme.subheadline)
        }
        .foregroundStyle(Color.theme.destructive)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.theme.destructive.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: .theme.radiusMd)
                .stroke(Color.theme.destructive.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}
