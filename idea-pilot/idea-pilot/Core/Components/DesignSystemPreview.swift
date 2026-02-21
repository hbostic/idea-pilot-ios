//
//  DesignSystemPreview.swift
//  idea-pilot
//
//  Preview-only gallery of all design system tokens and components.
//  Open this file in Xcode Previews for visual verification.
//

import SwiftUI

// MARK: - Design System Gallery Preview

#Preview("Design System Gallery") {
    ScrollView {
        VStack(alignment: .leading, spacing: 32) {

            // MARK: Colors

            sectionHeader("Colors")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                colorSwatch("bg", Color.theme.background)
                colorSwatch("card", Color.theme.card)
                colorSwatch("popover", Color.theme.popover)
                colorSwatch("secondary", Color.theme.secondary)
                colorSwatch("muted", Color.theme.muted)
                colorSwatch("primary", Color.theme.primary)
                colorSwatch("accent", Color.theme.accent)
                colorSwatch("destructive", Color.theme.destructive)
                colorSwatch("border", Color.theme.border)
                colorSwatch("ring", Color.theme.ring)
            }

            // MARK: Typography

            sectionHeader("Typography")
            VStack(alignment: .leading, spacing: 8) {
                Text("Large Title").font(.theme.largeTitle)
                Text("Title").font(.theme.title)
                Text("Title 2").font(.theme.title2)
                Text("Title 3").font(.theme.title3)
                Text("Body").font(.theme.body)
                Text("Body Regular").font(.theme.bodyRegular)
                Text("Subheadline").font(.theme.subheadline)
                Text("Caption").font(.theme.caption)
                Text("OVERLINE").font(.theme.overline)
                Text("Badge").font(.theme.badge)
                Text("1234567890").font(.theme.captionTabular)
            }
            .foregroundStyle(Color.theme.foreground)

            // MARK: Phase Badges

            sectionHeader("Phase Badges")
            HStack(spacing: 8) {
                ForEach(PlaybookPhase.allCases, id: \.self) { phase in
                    PhaseBadge(phase: phase)
                }
            }

            // MARK: Lane Chips

            sectionHeader("Lane Chips")
            LaneChipGroup(selected: .constant(.now))

            // MARK: Time Estimate Pills

            sectionHeader("Time Estimates")
            VStack(alignment: .leading, spacing: 12) {
                Text("Display mode").font(.theme.caption).foregroundStyle(Color.theme.mutedForeground)
                HStack(spacing: 8) {
                    TimeEstimatePill(minutes: 30)
                    TimeEstimatePill(minutes: 60)
                    TimeEstimatePill(minutes: 90)
                    TimeEstimatePill(minutes: 120)
                }
                Text("Selected mode").font(.theme.caption).foregroundStyle(Color.theme.mutedForeground)
                HStack(spacing: 8) {
                    TimeEstimatePill(minutes: 30)
                    TimeEstimatePill(minutes: 60, isSelected: true)
                    TimeEstimatePill(minutes: 90)
                    TimeEstimatePill(minutes: 120)
                }
            }

            // MARK: Card Style

            sectionHeader("Card Style")
            VStack(alignment: .leading, spacing: 8) {
                Text("Task Title Here")
                    .font(.theme.body)
                    .foregroundStyle(.white)
                Text("Secondary info")
                    .font(.theme.subheadline)
                    .foregroundStyle(Color.theme.mutedForeground)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()

            // MARK: Button Styles

            sectionHeader("Press Feedback")
            Button {} label: {
                Text("Pressable Button")
                    .font(.theme.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: .theme.radiusLg))
            }
            .buttonStyle(.pressable)

            Button {} label: {
                Text("Destructive Button")
                    .font(.theme.body)
                    .foregroundStyle(Color.theme.destructive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: .theme.radiusLg)
                            .stroke(Color.theme.destructive.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.pressable)

            // MARK: Glass Effect

            sectionHeader("Glass Effect")
            HStack {
                Spacer()
                Text("Tab Bar Glass")
                    .font(.theme.caption)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.vertical, 12)
            .glassStyle()
            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusLg))
        }
        .padding(20)
    }
    .themeBackground()
}

// MARK: - Preview Helpers

@ViewBuilder
private func sectionHeader(_ title: String) -> some View {
    Text(title.uppercased())
        .font(.theme.overline)
        .foregroundStyle(Color.theme.mutedForeground)
}

@ViewBuilder
private func colorSwatch(_ name: String, _ color: Color) -> some View {
    VStack(spacing: 4) {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        Text(name)
            .font(.system(size: 9))
            .foregroundStyle(Color.theme.mutedForeground)
    }
}
