import SwiftUI
import SwiftData

struct SetEntryRow: View {
    @Bindable var set: LoggedSetEntry
    var usePounds: Bool

    private var weightBinding: Binding<Double> {
        Binding(
            get: { usePounds ? MeasureConversion.kgToLb(set.weightKg) : set.weightKg },
            set: { set.weightKg = usePounds ? MeasureConversion.lbToKg($0) : $0 }
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("Set \(set.setIndex + 1)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FocusPalette.textSecondary)
                .frame(width: 44, alignment: .leading)
            TextField("Reps", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 72)

            Text("×")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(FocusPalette.textSecondary)
                .frame(minWidth: 16)

            TextField(usePounds ? "lb" : "kg", value: weightBinding, format: .number.precision(.fractionLength(1)))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 88)
        }
    }
}
