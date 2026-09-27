import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshots: [ProviderSnapshot] = []
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var demoMode = false
    @Published private(set) var refreshing = false

    private let providers: [UsageProvider] = [ClaudeProvider(), CodexProvider(), CursorProvider()]
    private var timer: Timer?
    private var demoForced = false
    let refreshInterval: TimeInterval = 60

    func forceDemo() {
        demoForced = true
        demoMode = true
        snapshots = DemoData.snapshots
    }

    func start() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task { @MainActor in await self.refresh() }
        }
    }

    func refresh() async {
        if demoForced { return }
        refreshing = true
        defer { refreshing = false }
        var found: [ProviderSnapshot] = []
        var errs: [String: String] = [:]
        for p in providers where p.isAvailable() {
            do {
                found.append(try await p.fetchUsage())
            } catch {
                errs[p.name] = error.localizedDescription
            }
        }
        if found.isEmpty && errs.isEmpty {
            demoMode = true
            snapshots = DemoData.snapshots
            errors = [:]
        } else {
            demoMode = false
            snapshots = found
            errors = errs
        }
    }

    var worst: ProviderSnapshot? { snapshots.max(by: { $0.worstUsedPercent < $1.worstUsedPercent }) }
}
