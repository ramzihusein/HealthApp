import SwiftUI
import SwiftData

struct SetEntryRow: View {
    @Bindable var set: LoggedSetEntry
    var usePounds: Bool
    var onPersist: (() -> Void)? = nil

    private var weightBinding: Binding<Double> {
        Binding(
            get: { usePounds ? MeasureConversion.kgToLb(set.weightKg) : set.weightKg },
            set: { newVal in
                set.weightKg = usePounds ? MeasureConversion.lbToKg(newVal) : newVal
                onPersist?()
            }
        )
    }

    private var repsTextBinding: Binding<String> {
        Binding(
            get: { set.reps == 0 ? "" : "\(set.reps)" },
            set: { newVal in
                let digits = newVal.filter { $0.isNumber }
                set.reps = Int(digits) ?? 0
                onPersist?()
            }
        )
    }

    private var weightUnit: String { usePounds ? "lb" : "kg" }

    var body: some View {
        HStack(spacing: 10) {
            Text("Set \(set.setIndex + 1)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FocusPalette.textSecondary)
                .frame(width: 44, alignment: .leading)

            TextField("0", value: weightBinding, format: .number.precision(.fractionLength(1)))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 88)

            Text(weightUnit)
                .font(.caption.weight(.medium))
                .foregroundStyle(FocusPalette.textSecondary)
                .frame(minWidth: 28, alignment: .leading)

            Text("×")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(FocusPalette.textSecondary)
                .frame(minWidth: 12)

            TextField("0", text: repsTextBinding)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 56)

            Text("reps")
                .font(.caption.weight(.medium))
                .foregroundStyle(FocusPalette.textSecondary)
        }
    }
}
