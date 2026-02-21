//
//  PhaseBadge.swift
//  idea-pilot
//
//  A colored badge indicating a playbook's lifecycle phase.
//

import SwiftUI

/// Displays a playbook's lifecycle phase as a small colored pill badge.
///
/// Each phase (PROOF, STRUCTURE, REPEATABILITY, GROWTH) has a distinct color.
/// The badge uses a tinted background with matching text and border.
///
/// Usage:
/// ```swift
/// PhaseBadge(phase: .proof)
/// ```
struct PhaseBadge: View {

    /// The playbook lifecycle phases.
    ///
    /// Each phase maps to a distinct color from the design system.
    /// This enum will be replaced by the domain model enum in Issue #5.
    enum Phase: String, CaseIterable, Sendable {
        case proof = "PROOF"
        case structure = "STRUCTURE"
        case repeatability = "REPEATABILITY"
        case growth = "GROWTH"

        /// The display color for this phase.
        var color: Color {
            switch self {
            case .proof:         return Color.theme.phaseProof
            case .structure:     return Color.theme.phaseStructure
            case .repeatability: return Color.theme.phaseRepeatability
            case .growth:        return Color.theme.phaseGrowth
            }
        }
    }

    let phase: Phase

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
        ForEach(PhaseBadge.Phase.allCases, id: \.self) { phase in
            PhaseBadge(phase: phase)
        }
    }
    .padding()
    .themeBackground()
}
