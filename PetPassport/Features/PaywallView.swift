import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "pawprint.circle.fill")
                    .resizable().scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.tint)

                VStack(spacing: 6) {
                    Text("Pet Passport Pro")
                        .font(.title.bold())
                    Text(PricingConfig.proHeadline)
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(PricingConfig.proSubheadline)
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(PricingConfig.proBenefits, id: \.self) { benefit in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.tint)
                            Text(benefit)
                                .font(.body)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)

                Button {
                    Task { await purchases.purchase() }
                } label: {
                    if purchases.purchaseInFlight {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("Unlock Pro — \(priceLabel)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(purchases.purchaseInFlight || purchases.product == nil)
                .padding(.horizontal, 24)

                Button("Restore purchases") {
                    Task { await purchases.restore() }
                }
                .font(.footnote)
                .disabled(purchases.purchaseInFlight)

                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        Link("Terms of Service", destination: termsURL)
                        Text("·").foregroundStyle(.secondary)
                        Link("Privacy Policy", destination: privacyURL)
                    }
                    .font(.footnote)

                    Text("One-time purchase. Not a subscription. No recurring charges.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 8)

                if let err = purchases.lastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 24)
        }
        .navigationTitle("Pro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { dismiss() }
            }
        }
        .onChange(of: purchases.isPro) { newValue in
            if newValue { dismiss() }
        }
    }

    private var priceLabel: String {
        purchases.product?.displayPrice ?? PricingConfig.proFallbackDisplayPrice
    }

    private var termsURL: URL {
        URL(string: "https://has-deploy.github.io/petpassport/terms.html")!
    }

    private var privacyURL: URL {
        URL(string: "https://has-deploy.github.io/petpassport/privacy.html")!
    }
}
