import SwiftUI

/// Shown when the local database cannot be opened (e.g. schema mismatch). User must confirm before data is erased.
struct DatabaseRecoveryView: View {
    let error: Error
    let onEraseConfirmed: () -> Void

    @State private var showConfirm = false

    var body: some View {
        FocusScreenBackground()
            .overlay {
                VStack(spacing: 20) {
                    Text("Local data can’t be opened")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(FocusPalette.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("This usually happens after an app update changes how data is stored. Your information is still on this screen only—we have not uploaded it because the app could not read the database.")
                        .font(.subheadline)
                        .foregroundStyle(FocusPalette.textSecondary)
                        .multilineTextAlignment(.leading)

                    Text("You can erase local HealthApp data on this device and start fresh. This removes your profile, plans, workout logs, nutrition logs, and weight entries. It cannot be undone.")
                        .font(.caption)
                        .foregroundStyle(FocusPalette.textSecondary)
                        .multilineTextAlignment(.leading)

                    DisclosureGroup("Technical detail") {
                        Text(String(describing: error))
                            .font(.caption2)
                            .foregroundStyle(FocusPalette.textSecondary.opacity(0.9))
                            .textSelection(.enabled)
                    }
                    .tint(FocusPalette.accent)

                    Button("Erase local data and continue") {
                        showConfirm = true
                    }
                    .buttonStyle(FocusPrimaryButtonStyle())
                }
                .padding(24)
            }
            .alert("Erase all local data?", isPresented: $showConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Erase", role: .destructive) { onEraseConfirmed() }
            } message: {
                Text("Profile, plans, and logs on this device will be permanently deleted.")
            }
    }
}
