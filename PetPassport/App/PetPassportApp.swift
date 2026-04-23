import SwiftUI

@main
struct PetPassportApp: App {
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var petStore = PetProfileStore()
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(purchases)
                .environmentObject(petStore)
                .environmentObject(settings)
                .task { await purchases.loadProducts() }
                .task { await purchases.observeTransactions() }
        }
    }
}
