import AppKit

enum DockIcon {
    private static var preferredVisible = false
    private static var promotionCount = 0

    static func setPreferredVisible(_ visible: Bool) {
        preferredVisible = visible
        syncPolicy()
    }

    static func beginPromotion() {
        promotionCount += 1
        syncPolicy()
    }

    static func endPromotion() {
        promotionCount = max(0, promotionCount - 1)
        syncPolicy()
    }

    private static var shouldShowInDock: Bool {
        preferredVisible || promotionCount > 0
    }

    private static func syncPolicy() {
        let policy: NSApplication.ActivationPolicy = shouldShowInDock ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
    }
}
