import Foundation

protocol UsageProvider: Sendable {
    var id: String { get }
    var name: String { get }
    nonisolated func isAvailable() -> Bool
    nonisolated func fetchUsage() async throws -> ProviderSnapshot
}

private func normalizePercent(_ v: Double) -> Double {
    v <= 1.0 ? v * 100.0 : v
}

// MARK: - Claude (claude.ai subscription via Claude Code OAuth creds in Keychain)

struct ClaudeProvider: UsageProvider {
    let id = "claude"
    let name = "Claude"

    private struct OAuthCreds: Decodable {
        let accessToken: String
        let expiresAt: Double?

        enum CodingKeys: String, CodingKey { case accessToken, expiresAt }
    }

    private static func creds() -> OAuthCreds? {
        guard let raw = Shell.run("/usr/bin/security", [
            "find-generic-password", "-s", "Claude Code-credentials", "-w"
        ])?.trimmingCharacters(in: .whitespacesAndNewlines),
              let data = raw.data(using: .utf8),
              let root = try? JSONDecoder().decode([String: OAuthCreds].self, from: data),
              let oauth = root["claudeAiOauth"]
        else { return nil }
        return oauth
    }

    func isAvailable() -> Bool { Self.creds() != nil }

    func fetchUsage() async throws -> ProviderSnapshot {
        guard let creds = Self.creds() else {
            throw ProviderError(message: "Claude Code credentials not in Keychain")
        }
        if let exp = creds.expiresAt, Date(timeIntervalSince1970: exp / 1000) < Date() {
            throw ProviderError(message: "Claude OAuth token expired — run Claude Code once to refresh")
        }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            throw ProviderError(message: "Claude token rejected (401)")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        func window(_ key: String, _ label: String) -> UsageWindow? {
            guard let w = json[key] as? [String: Any],
                  let u = w["utilization"] as? Double else { return nil }
            var reset: Date? = nil
            if let r = w["resets_at"] as? String {
                reset = ISO8601DateFormatter().date(from: r)
            }
            return UsageWindow(label: label, usedPercent: normalizePercent(u), resetsAt: reset)
        }

        let windows = [window("five_hour", "5h"), window("seven_day", "7d")].compactMap { $0 }
        return ProviderSnapshot(
            providerID: id, name: name,
            plan: nil,
            windows: windows.isEmpty ? [UsageWindow(label: "5h", usedPercent: 0, resetsAt: nil)] : windows,
            balanceText: nil, updatedAt: Date(), status: .ok, errorDetail: nil
        )
    }
}

// MARK: - ChatGPT / Codex (subscription via ~/.codex/auth.json)

struct CodexProvider: UsageProvider {
    let id = "codex"
    let name = "ChatGPT"

    private var authURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")
    }

    private func auth() -> (token: String, accountID: String?)? {
        guard let data = try? Data(contentsOf: authURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let access = tokens["access_token"] as? String
        else { return nil }
        return (access, tokens["account_id"] as? String)
    }

    func isAvailable() -> Bool { auth() != nil }

    func fetchUsage() async throws -> ProviderSnapshot {
        guard let (token, accountID) = auth() else {
            throw ProviderError(message: "Codex CLI auth.json not found")
        }
        var req = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let accountID { req.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id") }
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            throw ProviderError(message: "ChatGPT session expired — run `codex` once to refresh")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        func window(_ w: [String: Any]?, _ label: String) -> UsageWindow? {
            guard let w, let pct = w["used_percent"] as? Double else { return nil }
            var reset: Date? = nil
            if let r = w["reset_at"] as? Double { reset = Date(timeIntervalSince1970: r) }
            return UsageWindow(label: label, usedPercent: pct, resetsAt: reset)
        }

        let rl = json["rate_limit"] as? [String: Any]
        let windows = [
            window(rl?["primary_window"] as? [String: Any], "5h"),
            window(rl?["secondary_window"] as? [String: Any], "7d"),
        ].compactMap { $0 }

        var balance: String? = nil
        if let credits = json["credits"] as? [String: Any],
           let b = credits["balance"] as? String { balance = "\(b) credits" }

        return ProviderSnapshot(
            providerID: id, name: name,
            plan: (json["plan_type"] as? String)?.capitalized,
            windows: windows,
            balanceText: balance, updatedAt: Date(), status: .ok, errorDetail: nil
        )
    }
}

// MARK: - Cursor (dashboard session token from the Cursor app)

struct CursorProvider: UsageProvider {
    let id = "cursor"
    let name = "Cursor"

    private var dbURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }

    private func accessToken() -> String? {
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return nil }
        guard let raw = Shell.run("/usr/bin/sqlite3", [
            "-readonly", dbURL.path,
            "SELECT value FROM ItemTable WHERE key LIKE 'cursorAuth/%' OR key LIKE '%accessToken%' LIMIT 10"
        ]) else { return nil }
        for line in raw.split(separator: "\n") {
            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tok = (json["accessToken"] ?? json["access_token"]) as? String {
                return tok
            }
            let s = String(line)
            if s.count > 50, s.contains("eyJ") { return s } // raw JWT-ish value
        }
        return nil
    }

    func isAvailable() -> Bool { accessToken() != nil }

    func fetchUsage() async throws -> ProviderSnapshot {
        guard let tok = accessToken() else {
            throw ProviderError(message: "Cursor session token not found")
        }
        var req = URLRequest(url: URL(string: "https://cursor.com/api/usage-summary")!)
        req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        req.setValue("WorkosCursorSessionToken=\(tok)", forHTTPHeaderField: "Cookie")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 || http.statusCode == 403 {
            throw ProviderError(message: "Cursor session expired — open the Cursor app")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        var windows: [UsageWindow] = []
        if let ind = json["individualUsage"] as? [String: Any],
           let plan = ind["plan"] as? [String: Any],
           let limit = plan["limit"] as? Double, limit > 0,
           let used = plan["used"] as? Double {
            var reset: Date? = nil
            if let end = json["billingCycleEnd"] as? String {
                reset = ISO8601DateFormatter().date(from: end)
            }
            windows.append(UsageWindow(label: "cycle", usedPercent: used / limit * 100, resetsAt: reset))
        }
        let planName = json["membershipType"] as? String
        return ProviderSnapshot(
            providerID: id, name: name,
            plan: planName?.capitalized,
            windows: windows,
            balanceText: nil, updatedAt: Date(), status: .ok, errorDetail: nil
        )
    }
}

// MARK: - Demo data (used with --demo or when no credentials exist)

enum DemoData {
    static var snapshots: [ProviderSnapshot] {
        [
            ProviderSnapshot(
                providerID: "claude", name: "Claude", plan: "Max",
                windows: [
                    UsageWindow(label: "5h", usedPercent: 62, resetsAt: Date().addingTimeInterval(1.7 * 3600)),
                    UsageWindow(label: "7d", usedPercent: 34, resetsAt: Date().addingTimeInterval(3.4 * 86400)),
                ],
                balanceText: nil, updatedAt: Date(), status: .ok, errorDetail: nil),
            ProviderSnapshot(
                providerID: "codex", name: "ChatGPT", plan: "Plus",
                windows: [
                    UsageWindow(label: "5h", usedPercent: 21, resetsAt: Date().addingTimeInterval(4.2 * 3600)),
                    UsageWindow(label: "7d", usedPercent: 55, resetsAt: Date().addingTimeInterval(2.1 * 86400)),
                ],
                balanceText: "12.0 credits", updatedAt: Date(), status: .ok, errorDetail: nil),
            ProviderSnapshot(
                providerID: "cursor", name: "Cursor", plan: "Pro",
                windows: [
                    UsageWindow(label: "cycle", usedPercent: 88, resetsAt: Date().addingTimeInterval(9 * 86400)),
                ],
                balanceText: nil, updatedAt: Date(), status: .ok, errorDetail: nil),
        ]
    }
}
