import Foundation

struct UsageWindow: Identifiable {
    var id: String { label }
    let label: String          // e.g. "5h", "7d"
    let usedPercent: Double    // 0...100
    let resetsAt: Date?

    var resetsIn: String? {
        guard let resetsAt else { return nil }
        let s = resetsAt.timeIntervalSinceNow
        if s <= 0 { return "now" }
        let h = Int(s) / 3600, m = (Int(s) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

enum ProviderStatus: Equatable {
    case ok
    case authNeeded
    case unavailable(String)
}

struct ProviderSnapshot: Identifiable {
    var id: String { providerID }
    let providerID: String
    let name: String
    let plan: String?
    let windows: [UsageWindow]
    let balanceText: String?
    let updatedAt: Date
    let status: ProviderStatus
    let errorDetail: String?

    var worstUsedPercent: Double { windows.map(\.usedPercent).max() ?? 0 }
}

struct ProviderError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
