import AppKit
import SwiftUI

final class NotchViewModel: ObservableObject {
    @Published var expanded = false

    static let collapsedSize = NSSize(width: 240, height: 30)
    static let expandedSize = NSSize(width: 400, height: 320)
}

final class NotchPanel: NSPanel {
    let viewModel = NotchViewModel()

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: NotchViewModel.collapsedSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .init(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isMovable = false
        positionAtNotch(size: NotchViewModel.collapsedSize)
    }

    func attach(contentView: NSView) {
        self.contentView = contentView
        let tracking = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        )
        contentView.addTrackingArea(tracking)
    }

    private func positionAtNotch(size: NSSize) {
        guard let screen = NSScreen.main else { return }
        let x = screen.frame.midX - size.width / 2
        let y = screen.frame.maxY - size.height
        setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }

    override func mouseEntered(with event: NSEvent) { setExpanded(true) }
    override func mouseExited(with event: NSEvent) { setExpanded(false) }

    func setExpanded(_ expanded: Bool) {
        guard viewModel.expanded != expanded else { return }
        viewModel.expanded = expanded
        let size = expanded ? NotchViewModel.expandedSize : NotchViewModel.collapsedSize
        guard let screen = NSScreen.main else { return }
        let target = NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width, height: size.height
        )
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(target, display: true)
        }
    }
}
