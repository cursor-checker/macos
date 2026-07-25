import AppKit
import SwiftUI

/// Numeric NSTextField — filters non-digits without clearing, cursor jumps to end on focus.
struct NativeNumberField: NSViewRepresentable {
    @Binding var value: Double
    var style: NumericInputStyle = .decimal(maxFractionDigits: 2)

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value, style: style)
    }

    func makeNSView(context: Context) -> EndSelectionNumberField {
        let field = EndSelectionNumberField()
        field.bezelStyle = .roundedBezel
        field.alignment = .right
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        field.delegate = context.coordinator
        field.numericStyle = style
        field.stringValue = context.coordinator.format(value)
        field.onSanitizedText = { [weak coordinator = context.coordinator] text in
            coordinator?.textDidSanitize(text)
        }
        context.coordinator.field = field
        return field
    }

    func updateNSView(_ field: EndSelectionNumberField, context: Context) {
        context.coordinator.value = $value
        context.coordinator.style = style
        field.numericStyle = style
        field.onSanitizedText = { [weak coordinator = context.coordinator] text in
            coordinator?.textDidSanitize(text)
        }
        guard field.currentEditor() == nil else { return }
        let displayed = context.coordinator.format(value)
        if field.stringValue != displayed {
            field.stringValue = displayed
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var value: Binding<Double>
        var style: NumericInputStyle
        weak var field: EndSelectionNumberField?

        init(value: Binding<Double>, style: NumericInputStyle) {
            self.value = value
            self.style = style
        }

        func format(_ value: Double) -> String {
            style.format(value)
        }

        func textDidSanitize(_ text: String) {
            guard !text.isEmpty, let number = style.parse(text) else { return }
            if abs(number - value.wrappedValue) > 0.0001 {
                value.wrappedValue = number
            }
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            guard let field = obj.object as? EndSelectionNumberField else { return }
            field.lastValidText = field.stringValue
            field.moveCursorToEnd()
        }

        @objc func control(_ control: NSControl, textView: NSTextView,
                            shouldChangeTextIn affectedCharRange: NSRange,
                            replacementString: String?) -> Bool {
            proposesValidNumber(control.stringValue, range: affectedCharRange, replacement: replacementString ?? "")
        }

        func control(_ control: NSControl, textView: NSTextView,
                     shouldChangeTextInRanges affectedRanges: [NSValue],
                     replacementStrings: [String]) -> Bool {
            var proposed = control.stringValue as NSString
            for (rangeValue, replacement) in zip(affectedRanges, replacementStrings) {
                let range = rangeValue.rangeValue
                proposed = proposed.replacingCharacters(in: range, with: replacement) as NSString
            }
            return style.isValidPartial(style.sanitize(String(proposed)))
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            let text = style.sanitize(field.stringValue)
            if text.isEmpty {
                field.stringValue = format(value.wrappedValue)
                return
            }
            if let number = style.parse(text) {
                value.wrappedValue = number
                field.stringValue = format(number)
            } else {
                field.stringValue = format(value.wrappedValue)
            }
        }

        private func proposesValidNumber(_ current: String, range: NSRange, replacement: String) -> Bool {
            if replacement.isEmpty { return true }
            let proposed = (current as NSString).replacingCharacters(in: range, with: replacement)
            return style.isValidPartial(style.sanitize(proposed))
        }
    }
}

enum NumericInputStyle: Equatable {
    case integer
    case decimal(maxFractionDigits: Int)

    func isValidPartial(_ text: String) -> Bool {
        switch self {
        case .integer:
            return text.isEmpty || text.range(of: #"^\d+$"#, options: .regularExpression) != nil
        case .decimal(let maxFractionDigits):
            let pattern = #"^\d*\.?\d{0,\#(maxFractionDigits)}$"#
            return text.isEmpty || text.range(of: pattern, options: .regularExpression) != nil
        }
    }

    func sanitize(_ text: String) -> String {
        switch self {
        case .integer:
            return String(text.filter(\.isNumber))
        case .decimal(let maxFractionDigits):
            var result = ""
            var hasSeparator = false
            var fractionDigits = 0
            for char in text {
                if char.isNumber {
                    if hasSeparator {
                        guard fractionDigits < maxFractionDigits else { continue }
                        fractionDigits += 1
                    }
                    result.append(char)
                } else if (char == "." || char == ",") && !hasSeparator {
                    hasSeparator = true
                    result.append(".")
                }
            }
            return result
        }
    }

    func parse(_ text: String) -> Double? {
        switch self {
        case .integer:
            let digits = sanitize(text)
            guard !digits.isEmpty else { return nil }
            return Double(digits)
        case .decimal:
            var normalized = text.trimmingCharacters(in: .whitespaces)
            while normalized.hasSuffix(".") { normalized.removeLast() }
            guard !normalized.isEmpty else { return nil }
            return Double(normalized)
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .integer:
            return String(Int(value.rounded()))
        case .decimal(let maxFractionDigits):
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = maxFractionDigits
            formatter.usesGroupingSeparator = false
            formatter.decimalSeparator = "."
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }
    }
}

/// Select-all-on-click would steal focus UX; we always park the caret at the end instead.
final class EndSelectionNumberField: NSTextField {
    var numericStyle: NumericInputStyle = .decimal(maxFractionDigits: 2)
    var onSanitizedText: ((String) -> Void)?
    var lastValidText = ""
    private var changeObserver: NSObjectProtocol?

    deinit {
        if let changeObserver { NotificationCenter.default.removeObserver(changeObserver) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard changeObserver == nil else { return }
        changeObserver = NotificationCenter.default.addObserver(
            forName: NSControl.textDidChangeNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            self?.sanitizeInPlace()
        }
    }

    override func mouseDown(with event: NSEvent) {
        if window?.firstResponder !== currentEditor() {
            window?.makeFirstResponder(self)
        }
        moveCursorToEnd()
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok {
            DispatchQueue.main.async { [weak self] in self?.moveCursorToEnd() }
        }
        return ok
    }

    func moveCursorToEnd() {
        guard let editor = currentEditor() as? NSTextView else { return }
        let length = (editor.string as NSString).length
        editor.selectedRange = NSRange(location: length, length: 0)
    }

    private func sanitizeInPlace() {
        let cleaned = numericStyle.sanitize(stringValue)
        if cleaned != stringValue {
            stringValue = cleaned
        }
        guard numericStyle.isValidPartial(stringValue) else {
            stringValue = lastValidText
            moveCursorToEnd()
            return
        }
        lastValidText = stringValue
        onSanitizedText?(stringValue)
        moveCursorToEnd()
    }
}
