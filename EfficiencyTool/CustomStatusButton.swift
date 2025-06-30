import AppKit

// UN-USED
class CustomStatusButton: NSStatusBarButton {
    var onRightClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.type == .rightMouseDown || event.modifierFlags.contains(.control) {
            onRightClick?()
        } else {
            _ = self.target?.perform(self.action, with: self)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }
}
