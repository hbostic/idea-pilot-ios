//
//  Color+Theme.swift
//  idea-pilot
//
//  Design system color tokens.
//  Source of truth: docs/design/Dark-Theme-Design/client/src/index.css
//

import SwiftUI

// MARK: - HSL to SwiftUI Color Helper

extension Color {

    /// Creates a Color from CSS-style HSL values.
    ///
    /// - Parameters:
    ///   - hue: Hue angle in degrees (0–360)
    ///   - saturation: Saturation percentage (0–100)
    ///   - lightness: Lightness percentage (0–100)
    ///   - opacity: Opacity (0–1, default 1)
    fileprivate static func hsl(
        _ hue: Double,
        _ saturation: Double,
        _ lightness: Double,
        opacity: Double = 1
    ) -> Color {
        let h = hue / 360.0
        let s = saturation / 100.0
        let l = lightness / 100.0

        let brightness = l + s * min(l, 1 - l)
        let hsbSaturation = brightness == 0 ? 0 : 2 * (1 - l / brightness)

        return Color(
            hue: h,
            saturation: hsbSaturation,
            brightness: brightness,
            opacity: opacity
        )
    }
}

// MARK: - Theme Color Namespace

extension Color {

    /// Design system color tokens for Idea Pilot.
    ///
    /// All values derived from the Dark Future iOS theme CSS variables.
    /// Usage: `Color.theme.primary`, `Color.theme.background`, etc.
    enum theme {

        // MARK: Surfaces

        /// Pure black background. CSS: `0 0% 0%`
        static let background = Color.black

        /// Pure white foreground text. CSS: `0 0% 100%`
        static let foreground = Color.white

        /// Dark gray card surface. CSS: `240 5% 8%`
        static let card = Color.hsl(240, 5, 8)

        /// Card foreground (white). CSS: `0 0% 100%`
        static let cardForeground = Color.white

        /// Popover/sheet surface. CSS: `240 5% 10%`
        static let popover = Color.hsl(240, 5, 10)

        /// Popover foreground (white). CSS: `0 0% 100%`
        static let popoverForeground = Color.white

        // MARK: Brand

        /// Electric blue/purple primary. CSS: `250 100% 65%`
        static let primary = Color.hsl(250, 100, 65)

        /// Primary foreground (white). CSS: `0 0% 100%`
        static let primaryForeground = Color.white

        /// Neon green accent for completion/success. CSS: `150 100% 50%`
        static let accent = Color.hsl(150, 100, 50)

        /// Accent foreground (black for contrast). CSS: `0 0% 0%`
        static let accentForeground = Color.black

        // MARK: Neutrals

        /// Secondary surface. CSS: `240 5% 15%`
        static let secondary = Color.hsl(240, 5, 15)

        /// Secondary foreground (white). CSS: `0 0% 100%`
        static let secondaryForeground = Color.white

        /// Muted surface (same as secondary). CSS: `240 5% 15%`
        static let muted = Color.hsl(240, 5, 15)

        /// Muted/disabled text. CSS: `240 5% 65%`
        static let mutedForeground = Color.hsl(240, 5, 65)

        // MARK: Semantic

        /// Destructive red for delete/cancel actions. CSS: `0 100% 60%`
        static let destructive = Color.hsl(0, 100, 60)

        /// Destructive foreground (white). CSS: `0 0% 100%`
        static let destructiveForeground = Color.white

        // MARK: Borders & Focus

        /// Default border color. CSS: `240 5% 15%`
        static let border = Color.hsl(240, 5, 15)

        /// Input field border. CSS: `240 5% 15%`
        static let input = Color.hsl(240, 5, 15)

        /// Focus ring color. CSS: `250 100% 65%`
        static let ring = Color.hsl(250, 100, 65)

        // MARK: Phase Badge Colors

        /// PROOF phase — blue
        static let phaseProof = Color.blue

        /// STRUCTURE phase — purple
        static let phaseStructure = Color.purple

        /// REPEATABILITY phase — orange
        static let phaseRepeatability = Color.orange

        /// GROWTH phase — green
        static let phaseGrowth = Color.green
    }
}

// MARK: - Theme Radius Tokens

extension CGFloat {

    /// Design system corner radius tokens.
    ///
    /// Derived from CSS `--radius: 1rem` (16pt).
    enum theme {
        /// Small radius: 12pt. CSS: `calc(var(--radius) - 4px)`
        static let radiusSm: CGFloat = 12

        /// Medium radius: 14pt. CSS: `calc(var(--radius) - 2px)`
        static let radiusMd: CGFloat = 14

        /// Large radius (base): 16pt. CSS: `var(--radius)`
        static let radiusLg: CGFloat = 16

        /// Extra-large radius: 20pt. CSS: `calc(var(--radius) + 4px)`
        static let radiusXl: CGFloat = 20
    }
}
