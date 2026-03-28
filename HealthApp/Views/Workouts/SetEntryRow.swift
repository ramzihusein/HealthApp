import SwiftUI
import SwiftData

struct SetEntryRow: View {
    @Bindable var set: LoggedSetEntry

    var body: some View {
        HStack(spacing: 12) {
            Text("Set \(set.setIndex + 1)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FocusPalette.textSecondary)
                .frame(width: 44, alignment: .leading)
            TextField("Reps", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 80)

            TextField("kg", value: $set.weightKg, format: .number.precision(.fractionLength(1)))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 90)
        }
    }
}
