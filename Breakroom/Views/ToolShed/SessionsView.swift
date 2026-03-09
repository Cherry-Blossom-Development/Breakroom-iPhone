import SwiftUI

struct SessionsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sessions")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.purple)
                    Text("Track and manage your recording sessions")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Coming Soon card
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 56))
                        .foregroundStyle(.purple)

                    Text("Coming Soon")
                        .font(.title2.weight(.semibold))

                    Text("Sessions is currently in early access. Full functionality is on its way!")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(48)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SessionsView()
    }
}
