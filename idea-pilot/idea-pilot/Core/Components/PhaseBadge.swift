//
//  PhaseBadge.swift
//  idea-pilot
//
//  A colored badge indicating a playbook's lifecycle phase.
//

import SwiftUI

/// Displays a playbook's lifecycle phase as a small colored pill badge.
///
/// Each phase (PROOF, STRUCTURE, REPEATABILITY, GROWTH) has a distinct color
/// defined on the `PlaybookPhase` enum.
///
/// Usage:
/// ```swift
/// PhaseBadge(phase: .proof)
/// ```
struct PhaseBadge: View {

    let phase: PlaybookPhase

    var body: some View {
        Text(phase.rawValue)
            .font(.theme.badge)
            .tracking(1.0)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(phase.color)
            .background(phase.color.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(phase.color.opacity(0.2), lineWidth: 1)
            )
            .accessibilityLabel("Phase: \(phase.rawValue.capitalized)")
    }
}

#Preview("All Phases") {
    VStack(spacing: 12) {
        ForEach(PlaybookPhase.allCases, id: \.self) { phase in
            PhaseBadge(phase: phase)
        }
    }
    .padding()
    .themeBackground()
}
