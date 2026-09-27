import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel!
    private var store: UsageStore!

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = UsageStore()
        if CommandLine.arguments.contains("--demo") {
            store.forceDemo()
        }
        panel = NotchPanel()
        let root = NotchContentView(store: store, viewModel: panel.viewModel) { [weak self] in
            Task { @MainActor in await self?.store.refresh() }
        }
        panel.attach(contentView: NSHostingView(rootView: root))
        panel.orderFrontRegardless()
        store.start()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
