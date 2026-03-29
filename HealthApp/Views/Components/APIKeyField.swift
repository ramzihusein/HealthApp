import SwiftUI
import UIKit

/// Plain `TextField` + paste button so clipboard paste works reliably (SwiftUI `SecureField` often blocks paste on iOS).
struct APIKeyField: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.body.monospaced())

            Button {
                if let s = UIPasteboard.general.string {
                    text = s.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } label: {
                Label("Paste from clipboard", systemImage: "doc.on.clipboard")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(FocusPalette.accent)

            Text("Shown as plain text so copy, paste, and editing work reliably. Avoid screen recording while your key is visible.")
                .font(.caption2)
                .foregroundStyle(FocusPalette.textSecondary)
        }
    }
}
