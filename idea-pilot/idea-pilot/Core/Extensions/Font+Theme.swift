//
//  Font+Theme.swift
//  idea-pilot
//
//  Design system typography tokens.
//  Maps the web mockup's Inter type scale to SF Pro (iOS system font).
//

import SwiftUI

extension Font {

    /// Design system typography tokens for Idea Pilot.
    ///
    /// All sizes use SF Pro (system font). The web mockup uses Inter which
    /// has nearly identical metrics to SF Pro.
    ///
    /// Usage: `.font(.theme.title)`, `.font(.theme.body)`, etc.
    enum theme {

        // MARK: Display

        /// Large display heading. 34pt bold.
        /// Used for: auth screen title, large page titles.
        static let largeTitle: Font = .system(size: 34, weight: .bold)

        /// Screen title. 28pt bold.
        /// Used for: "Playbooks" list header, section headers.
        static let title: Font = .system(size: 28, weight: .bold)

        /// Secondary title. 22pt semibold.
        /// Used for: playbook name on home screen, sheet titles.
        static let title2: Font = .system(size: 22, weight: .semibold)

        /// Tertiary title. 20pt semibold.
        /// Used for: card headings, empty state titles.
        static let title3: Font = .system(size: 20, weight: .semibold)

        // MARK: Body

        /// Primary body text. 17pt medium.
        /// Used for: task card titles, form labels.
        static let body: Font = .system(size: 17, weight: .medium)

        /// Regular body text. 17pt regular.
        /// Used for: section content, notes, input text.
        static let bodyRegular: Font = .system(size: 17, weight: .regular)

        /// Secondary text. 15pt regular.
        /// Used for: task summaries, secondary descriptions.
        static let subheadline: Font = .system(size: 15, weight: .regular)

        // MARK: Captions & Labels

        /// Small caption. 13pt medium.
        /// Used for: time badges, lane counts, metadata.
        static let caption: Font = .system(size: 13, weight: .medium)

        /// Overline label. 11pt bold, intended for uppercased text.
        /// Used for: form field labels ("LANE", "ESTIMATE").
        static let overline: Font = .system(size: 11, weight: .bold)

        /// Badge text. 10pt bold.
        /// Used for: PhaseBadge, small status indicators.
        static let badge: Font = .system(size: 10, weight: .bold)

        // MARK: Tabular Figures

        /// Tabular (monospaced digits) caption for numeric display.
        /// Prevents layout shifts when values change (e.g., "90m" vs "120m").
        static let captionTabular: Font = .system(size: 13, weight: .semibold).monospacedDigit()

        /// Tabular body for larger numeric display.
        static let bodyTabular: Font = .system(size: 17, weight: .medium).monospacedDigit()
    }
}
