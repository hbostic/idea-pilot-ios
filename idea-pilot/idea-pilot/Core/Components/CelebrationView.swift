//
//  CelebrationView.swift
//  idea-pilot
//
//  Brief celebration shown when all Now-lane tasks are completed.
//  Displays a checkmark burst animation and an encouraging message.
//

import SwiftUI

/// Celebration view shown when the user completes all tasks in the Now lane.
///
/// Animates a checkmark icon with a spring scale effect, followed by
/// a text fade-in. Respects the Reduce Motion accessibility setting
/// by displaying all elements instantly when enabled.
struct CelebrationView: View {

    @State private var showCheckmark = false
    @State private var showMessage = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 80)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.theme.accent)
                .scaleEffect(showCheckmark ? 1.0 : 0.3)
                .opacity(showCheckmark ? 1 : 0)

            Text("All done for now!")
                .font(.theme.title2)
                .foregroundStyle(Color.theme.foreground)
                .opacity(showMessage ? 1 : 0)

            Text("Great work. Take a break or check your Next lane.")
                .font(.theme.subheadline)
                .foregroundStyle(Color.theme.mutedForeground)
                .multilineTextAlignment(.center)
                .opacity(showMessage ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if UIAccessibility.isReduceMotionEnabled {
                showCheckmark = true
                showMessage = true
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showCheckmark = true
                }
                withAnimation(.easeIn(duration: 0.3).delay(0.3)) {
                    showMessage = true
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("All done for now! Great work.")
    }
}
