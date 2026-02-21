//
//  LaneChip.swift
//  idea-pilot
//
//  A selectable chip for task lane (NOW / NEXT / LATER).
//

import SwiftUI

/// A horizontal set of selectable lane chips for task lane assignment.
///
/// Used in Quick Add (CaptureSheet) and Task Detail for lane selection.
/// The selected chip has a filled white background; unselected chips have
/// a muted secondary background.
///
/// Usage:
/// ```swift
/// LaneChipGroup(selected: $selectedLane)
/// ```
struct LaneChipGroup: View {

    /// The task lane options.
    ///
    /// This enum will be replaced by the domain model enum in Issue #5.
    enum Lane: String, CaseIterable, Sendable {
        case now = "NOW"
        case next = "NEXT"
        case later = "LATER"
    }

    @Binding var selected: Lane

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Lane.allCases, id: \.self) { lane in
                LaneChip(
                    lane: lane,
                    isSelected: selected == lane,
                    action: { selected = lane }
                )
            }
        }
    }
}

/// A single lane chip button.
///
/// When selected: white background, black text, white border.
/// When unselected: secondary/muted background, muted text, no border.
struct LaneChip: View {

    let lane: LaneChipGroup.Lane
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(lane.rawValue)
                .font(.theme.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? Color.black : Color.theme.mutedForeground)
                .background(isSelected ? Color.white : Color.theme.secondary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: .theme.radiusSm))
                .overlay(
                    RoundedRectangle(cornerRadius: .theme.radiusSm)
                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(lane.rawValue) lane")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Lane Chips") {
    struct PreviewWrapper: View {
        @State private var lane: LaneChipGroup.Lane = .later

        var body: some View {
            VStack(spacing: 16) {
                Text("Selected: \(lane.rawValue)")
                    .font(.theme.body)
                    .foregroundStyle(.white)
                LaneChipGroup(selected: $lane)
            }
            .padding()
            .themeBackground()
        }
    }
    return PreviewWrapper()
}
