//
//  EmptyStateView.swift
//  idea-pilot
//
//  A generic, reusable empty-state component with an SF Symbol icon,
//  title, message, and an optional call-to-action button.
//

import SwiftUI

/// A centered empty-state view with icon, title, message, and optional CTA.
///
/// Used when a list or screen has no content to display. Follows the
/// project pattern: 48pt muted icon, title2 heading, subheadline message,
/// and an optional primary-styled action button.
struct EmptyStateView: View {

    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 80)

            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.theme.mutedForeground)

            VStack(spacing: 8) {
                Text(title)
                    .font(.theme.title2)
                    .foregroundStyle(Color.theme.foreground)

                Text(message)
                    .font(.theme.subheadline)
                    .foregroundStyle(Color.theme.mutedForeground)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let onAction {
                Button {
                    onAction()
                } label: {
                    Text(actionTitle)
                        .font(.theme.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.theme.primaryForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: .theme.radiusMd))
                        .shadow(color: Color.theme.primary.opacity(0.4), radius: 12, y: 4)
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
