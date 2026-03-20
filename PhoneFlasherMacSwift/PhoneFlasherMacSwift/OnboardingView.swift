import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, subtitle: String)] = [
        (
            "bolt.fill",
            "Welcome to PhoneFlasher",
            "The easiest way to flash Android firmware on your Mac.\nSupports Samsung, Pixel, LG, and OnePlus devices."
        ),
        (
            "arrow.down.circle.fill",
            "Download Tools Automatically",
            "PhoneFlasher downloads Google Platform Tools (ADB & Fastboot) for you.\nNo terminal commands required."
        ),
        (
            "iphone.and.arrow.forward",
            "Flash with Confidence",
            "Select your firmware images and flash them with a single click.\nBuilt-in safety checks keep your device protected."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Page content
            VStack(spacing: 24) {
                Image(systemName: pages[currentPage].icon)
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                    .frame(height: 80)

                Text(pages[currentPage].title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(pages[currentPage].subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            Spacer()

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 32)

            // Buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation { currentPage -= 1 }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("Continue") {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("Get Started") {
                        hasCompletedOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(width: 560, height: 480)
    }
}
