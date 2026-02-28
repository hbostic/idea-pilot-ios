//
//  OfflineBannerView.swift
//  idea-pilot
//
//  A subtle persistent banner shown when the device has no network
//  connectivity. Observes NetworkMonitor.isConnected.
//

import SwiftUI

/// A subtle offline indicator shown at the top of screen content.
///
/// Observes a `NetworkMonitor` and displays a compact gray banner
/// when `isConnected` is false. Animates in/out with a slide+fade
/// transition respecting Reduce Motion.
struct OfflineBannerView: View {

    let networkMonitor: NetworkMonitor

    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 12, weight: .semibold))
                Text("Offline — showing cached data")
                    .font(.theme.caption)
            }
            .foregroundStyle(Color.theme.mutedForeground)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(Color.theme.secondary)
            .clipShape(RoundedRectangle(cornerRadius: .theme.radiusSm))
            .transition(.move(edge: .top).combined(with: .opacity))
            .motionSafe(.easeInOut(duration: 0.3))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Offline. Showing cached data.")
        }
    }
}
