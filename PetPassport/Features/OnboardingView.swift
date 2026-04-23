import SwiftUI

struct OnboardingView: View {
    @State private var showingAddPet = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "pawprint.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text("My Pet Passport")
                    .font(.largeTitle.bold())
                Text("Plan your pet's international trip without guessing the paperwork.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
            Button {
                showingAddPet = true
            } label: {
                Text("Add Your First Pet")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)

            Text("Takes about a minute. Data stays on your device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
        }
        .sheet(isPresented: $showingAddPet) {
            PetProfileEditor(mode: .create)
        }
    }
}

#Preview {
    NavigationStack { OnboardingView() }
        .environmentObject(PetProfileStore())
}
