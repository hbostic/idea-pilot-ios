//
//  View+Theme.swift
//  idea-pilot
//
//  Design system view modifiers and button styles.
//

import SwiftUI

// MARK: - Press Feedback Button Style

/// A button style that applies a subtle scale-down spring animation on press.
///
/// Matches the web mockup's `active:scale-[0.98]` interaction pattern.
/// Used for all tappable cards, primary buttons, and interactive elements.
///
/// Usage:
/// ```swift
/// Button("Tap me") { ... }
///     .buttonStyle(.pressable)
/// ```
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// A button style with subtle press-down spring feedback (scale 0.98).
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Card Style Modifier

/// Applies the standard card appearance: dark card background, subtle border,
/// rounded corners.
///
/// Matches the recurring `bg-card border border-white/5 rounded-2xl` pattern
/// from the web mockup.
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.theme.card)
            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusLg))
            .overlay(
                RoundedRectangle(cornerRadius: .theme.radiusLg)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }
}

extension View {
    /// Applies the Idea Pilot card style: dark background, subtle border, rounded corners.
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Glass Effect Modifier

/// Applies the iOS glass morphism effect used for the tab bar and overlays.
///
/// Matches the web mockup's `.ios-glass` class:
/// `bg-black/70 backdrop-blur-xl border-t border-white/10`
struct GlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(0.7))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 0.5)
            }
    }
}

extension View {
    /// Applies the glass-effect style with blur and subtle top border.
    func glassStyle() -> some View {
        modifier(GlassModifier())
    }
}

// MARK: - Reduce Motion Support

extension View {
    /// Conditionally applies an animation, respecting the Reduce Motion accessibility setting.
    ///
    /// When Reduce Motion is enabled, animations are replaced with instant transitions.
    ///
    /// - Parameter animation: The animation to apply when Reduce Motion is off.
    func motionSafe(_ animation: Animation) -> some View {
        transaction { transaction in
            if UIAccessibility.isReduceMotionEnabled {
                transaction.animation = nil
            } else {
                transaction.animation = animation
            }
        }
    }
}

// MARK: - Theme Background

extension View {
    /// Applies the app's pure black background extending into safe areas.
    func themeBackground() -> some View {
        self
            .background(Color.theme.background.ignoresSafeArea())
    }
}
