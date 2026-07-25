import AppKit
import SwiftUI

/// Native macOS switch — the same control used in System Settings.
struct NativeSwitch: NSViewRepresentable {
    @Binding var isOn: Bool

    private static let targetHeight: CGFloat = 20
    static var layoutSize: NSSize {
        ScaledSwitchHost.scaledSize(forHeight: targetHeight)
    }

    func makeNSView(context: Context) -> ScaledSwitchHost {
        let host = ScaledSwitchHost(targetHeight: Self.targetHeight)
        let control = NSSwitch()
        control.state = isOn ? .on : .off
        control.target = context.coordinator
        control.action = #selector(Coordinator.changed(_:))
        host.embed(control)
        return host
    }

    func updateNSView(_ host: ScaledSwitchHost, context: Context) {
        guard let control = host.switchControl else { return }
        let newState: NSControl.StateValue = isOn ? .on : .off
        guard control.state != newState else { return }
        control.state = newState
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isOn: $isOn)
    }

    final class Coordinator: NSObject {
        var isOn: Binding<Bool>

        init(isOn: Binding<Bool>) {
            self.isOn = isOn
        }

        @objc func changed(_ sender: NSSwitch) {
            isOn.wrappedValue = sender.state == .on
        }
    }
}

/// Host view that scales NSSwitch to a target height while preserving aspect ratio.
final class ScaledSwitchHost: NSView {
    private static let naturalSize = NSSize(width: 54, height: 24)

    private(set) var switchControl: NSSwitch?
    private let scaledSize: NSSize

    static func scaledSize(forHeight height: CGFloat) -> NSSize {
        let scale = height / naturalSize.height
        return NSSize(width: naturalSize.width * scale, height: height)
    }

    init(targetHeight: CGFloat) {
        scaledSize = Self.scaledSize(forHeight: targetHeight)
        super.init(frame: NSRect(origin: .zero, size: scaledSize))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { nil }

    override var isOpaque: Bool { false }

    func embed(_ control: NSSwitch) {
        switchControl = control
        control.frame = NSRect(origin: .zero, size: scaledSize)
        control.bounds = NSRect(origin: .zero, size: Self.naturalSize)
        addSubview(control)
    }

    override func layout() {
        super.layout()
        guard let control = switchControl else { return }
        // Only reposition — resetting bounds each layout pass breaks NSSwitch animation.
        control.frame.origin = NSPoint(
            x: bounds.width - scaledSize.width,
            y: (bounds.height - scaledSize.height) / 2
        )
    }

    override var intrinsicContentSize: NSSize { scaledSize }
}
