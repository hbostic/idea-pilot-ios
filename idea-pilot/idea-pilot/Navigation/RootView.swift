//
//  RootView.swift
//  idea-pilot
//
//  Created by Harold Bostic on 2/21/26.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "airplane")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)

                Text("Idea Pilot")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("Helping you land on the tarmac of execution")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

#Preview {
    RootView()
}
