import SwiftUI

enum SettingsControls {
    static func numberField(_ value: Binding<Double>, integersOnly: Bool = false) -> some View {
        NativeNumberField(
            value: value,
            style: integersOnly ? .integer : .decimal(maxFractionDigits: 2)
        )
        .frame(width: 90, height: 22)
    }

    static func switchToggle(_ isOn: Binding<Bool>) -> some View {
        NativeSwitch(isOn: isOn)
            .fixedSize()
            .frame(
                width: NativeSwitch.layoutSize.width,
                height: NativeSwitch.layoutSize.height,
                alignment: .trailing
            )
            .clipped()
    }
}
