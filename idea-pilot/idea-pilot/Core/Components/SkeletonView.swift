//
//  SkeletonView.swift
//  idea-pilot
//
//  Shimmer skeleton loaders for loading states. Provides a gradient
//  pulse animation (1500ms loop) that replaces plain ProgressView
//  spinners with content-shaped placeholders.
//

import SwiftUI

// MARK: - Shimmer Modifier

/// Applies a diagonal gradient shimmer animation to any view.
///
/// The gradient sweeps left-to-right on a 1.5-second loop.
/// When Reduce Motion is enabled, displays a static muted placeholder
/// with no animation.
struct ShimmerModifier: ViewModifier {

    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        if UIAccessibility.isReduceMotionEnabled {
            content
                .overlay(Color.theme.mutedForeground.opacity(0.15))
        } else {
            content
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.12),
                            Color.white.opacity(0),
                        ],
                        startPoint: .init(x: phase - 0.5, y: 0.5),
                        endPoint: .init(x: phase + 0.5, y: 0.5)
                    )
                )
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                    ) {
                        phase = 2
                    }
                }
        }
    }
}

extension View {
    /// Adds a shimmer animation overlay for loading placeholders.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Row

/// A single placeholder row matching the approximate shape of a card.
struct SkeletonRow: View {

    var height: CGFloat = 72

    var body: some View {
        RoundedRectangle(cornerRadius: .theme.radiusLg)
            .fill(Color.theme.card)
            .frame(height: height)
            .shimmer()
    }
}

// MARK: - Skeleton List

/// A vertical stack of shimmer placeholder rows for list loading states.
///
/// Replaces the generic `ProgressView()` + text pattern with
/// content-shaped skeletons per the UX spec.
struct SkeletonList: View {

    var rowCount: Int = 3
    var rowHeight: CGFloat = 72
    var spacing: CGFloat = 12

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<rowCount, id: \.self) { _ in
                SkeletonRow(height: rowHeight)
            }
        }
    }
}
