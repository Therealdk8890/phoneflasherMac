import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var store: StoreKitManager
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("PhoneFlasher Pro")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Unlock the full power of PhoneFlasher")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            // Features grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(ProFeature.allCases) { feature in
                        featureCard(feature)
                    }
                }
                .padding(.horizontal, 32)
            }
            .frame(maxHeight: 280)

            Spacer()

            // Purchase section
            VStack(spacing: 16) {
                if store.isProUnlocked {
                    Label("You have PhoneFlasher Pro!", systemImage: "checkmark.seal.fill")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                } else if let product = store.proProduct {
                    Button {
                        Task {
                            isPurchasing = true
                            _ = await store.purchase(product)
                            isPurchasing = false
                        }
                    } label: {
                        HStack {
                            if isPurchasing {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            }
                            Text("Upgrade for \(product.displayPrice)")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: 280)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isPurchasing)

                    Button("Restore Purchases") {
                        Task {
                            await store.restorePurchases()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else if store.isLoading {
                    ProgressView("Loading...")
                } else {
                    Text("Unable to load pricing. Please try again later.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Retry") {
                        Task { await store.loadProducts() }
                    }
                    .buttonStyle(.bordered)
                }

                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Text("One-time purchase. No subscription required.")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.bottom, 32)
        }
        .frame(width: 560, height: 620)
    }

    private func featureCard(_ feature: ProFeature) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feature.icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(feature.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.06))
        )
    }
}
