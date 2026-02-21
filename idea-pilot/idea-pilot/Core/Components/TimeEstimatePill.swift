//
//  TimeEstimatePill.swift
//  idea-pilot
//
//  A pill-shaped badge displaying a task's time estimate.
//

import SwiftUI

/// Displays a task's estimated duration as a compact pill badge.
///
/// Shows the value in minutes with an "m" suffix (e.g., "90m").
/// Supports two visual modes:
/// - **Display mode** (default): muted neutral style, used on task cards.
/// - **Selected mode**: primary-tinted, used in estimate pickers.
///
/// Usage:
/// ```swift
/// TimeEstimatePill(minutes: 90)
/// TimeEstimatePill(minutes: 120, isSelected: true)
/// ```
struct TimeEstimatePill: View {

    /// The estimated duration in minutes.
    let minutes: Int

    /// Whether this pill is in a selected state (e.g., in an estimate picker).
    var isSelected: Bool = false

    var body: some View {
        Text("\(minutes)m")
            .font(.theme.captionTabular)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusSm))
            .overlay(
                RoundedRectangle(cornerRadius: .theme.radiusSm)
                    .stroke(borderColor, lineWidth: 1)
            )
            .accessibilityLabel("\(minutes) minutes estimated")
    }

    private var foregroundColor: Color {
        isSelected ? Color.theme.primary : Color.theme.mutedForeground
    }

    private var backgroundColor: Color {
        isSelected ? Color.theme.primary.opacity(0.2) : Color.theme.secondary
    }

    private var borderColor: Color {
        isSelected ? Color.theme.primary.opacity(0.5) : Color.clear
    }
}

/// A horizontal row of time estimate options for selection.
///
/// Used in Quick Add and Task Detail sheets for selecting task duration.
/// Default options are 30, 60, 90, 120, and 180 minutes.
///
/// Usage:
/// ```swift
/// TimeEstimatePickerRow(selected: $estimate)
/// ```
struct TimeEstimatePickerRow: View {

    @Binding var selected: Int

    /// Available time options in minutes.
    let options: [Int]

    init(selected: Binding<Int>, options: [Int] = [30, 60, 90, 120, 180]) {
        self._selected = selected
        self.options = options
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { mins in
                Button {
                    selected = mins
                } label: {
                    TimeEstimatePill(minutes: mins, isSelected: selected == mins)
                }
                .buttonStyle(.pressable)
            }
        }
    }
}

#Preview("Time Estimate Pills") {
    struct PreviewWrapper: View {
        @State private var estimate = 60

        var body: some View {
            VStack(spacing: 24) {
                Text("Display mode (task card)")
                    .font(.theme.caption)
                    .foregroundStyle(Color.theme.mutedForeground)
                HStack(spacing: 8) {
                    TimeEstimatePill(minutes: 30)
                    TimeEstimatePill(minutes: 90)
                    TimeEstimatePill(minutes: 120)
                }

                Text("Picker mode (selected: \(estimate)m)")
                    .font(.theme.caption)
                    .foregroundStyle(Color.theme.mutedForeground)
                TimeEstimatePickerRow(selected: $estimate)
            }
            .padding()
            .themeBackground()
        }
    }
    return PreviewWrapper()
}
