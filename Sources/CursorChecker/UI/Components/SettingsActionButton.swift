import AppKit
import SwiftUI

/// AppKit button for settings rows — more reliable than SwiftUI `Button` inside scroll views.
struct SettingsActionButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Representable(title: title, isEnabled: isEnabled, action: action)
            .fixedSize(horizontal: true, vertical: false)
    }

    private struct Representable: NSViewRepresentable {
        let title: String
        var isEnabled: Bool
        let action: () -> Void

        func makeCoordinator() -> Coordinator {
            Coordinator(action: action)
        }

        func makeNSView(context: Context) -> SettingsActionButtonHost {
            let button = NSButton(title: title, target: context.coordinator, action: #selector(Coordinator.clicked))
            button.bezelStyle = .rounded
            button.controlSize = .regular
            button.isEnabled = isEnabled
            return SettingsActionButtonHost(button: button)
        }

        func updateNSView(_ host: SettingsActionButtonHost, context: Context) {
            host.button.title = title
            host.button.isEnabled = isEnabled
            host.invalidateIntrinsicContentSize()
        }

        final class Coordinator: NSObject {
            let action: () -> Void

            init(action: @escaping () -> Void) {
                self.action = action
            }

            @objc func clicked() {
                action()
            }
        }
    }
}

/// Keeps the AppKit button at its natural width instead of stretching across the row.
final class SettingsActionButtonHost: NSView {
    let button: NSButton

    init(button: NSButton) {
        self.button = button
        super.init(frame: .zero)
        addSubview(button)
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        button.intrinsicContentSize
    }

    override func layout() {
        super.layout()
        let size = button.intrinsicContentSize
        button.frame = NSRect(
            x: bounds.width - size.width,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}
