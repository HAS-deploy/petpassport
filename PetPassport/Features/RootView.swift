import SwiftUI

struct RootView: View {
    @EnvironmentObject private var petStore: PetProfileStore
    @EnvironmentObject private var purchases: PurchaseManager

    var body: some View {
        NavigationStack {
            if petStore.pets.isEmpty {
                OnboardingView()
            } else {
                HomeView()
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(PurchaseManager())
        .environmentObject(PetProfileStore())
        .environmentObject(SettingsStore())
}
