// UpdateChecker.swift — drop this into NotchMirror/

import Foundation
import AppKit

final class UpdateChecker {

    // ── Change these to your GitHub repo ──────────────────────────────────
    private static let repoOwner = "sharanch"
    private static let repoName  = "notchmirror-mac"
    // ──────────────────────────────────────────────────────────────────────

    private static let apiURL = URL(string:
        "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
    )!

    /// Call once on launch. Shows an alert only when a newer version exists.
    static func checkForUpdates(silent: Bool = false) {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard
                error == nil,
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tagName = json["tag_name"] as? String,
                let htmlURL = json["html_url"] as? String
            else {
                if !silent { print("UpdateChecker: failed to fetch release info") }
                return
            }

            let latest  = tagName.trimmingCharacters(in: .init(charactersIn: "v"))
            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

            guard isNewer(latest, than: current) else {
                print("UpdateChecker: up to date (\(current))")
                return
            }

            DispatchQueue.main.async {
                showUpdateAlert(currentVersion: current,
                                latestVersion: latest,
                                releaseURL: htmlURL)
            }
        }.resume()
    }

    // MARK: – Private helpers

    private static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = versionTuple(remote)
        let l = versionTuple(local)
        return r.0 > l.0
            || (r.0 == l.0 && r.1 > l.1)
            || (r.0 == l.0 && r.1 == l.1 && r.2 > l.2)
    }

    private static func versionTuple(_ v: String) -> (Int, Int, Int) {
        let parts = v.split(separator: ".").compactMap { Int($0) }
        return (parts.indices.contains(0) ? parts[0] : 0,
                parts.indices.contains(1) ? parts[1] : 0,
                parts.indices.contains(2) ? parts[2] : 0)
    }

    private static func showUpdateAlert(currentVersion: String,
                                        latestVersion: String,
                                        releaseURL: String) {
        let alert = NSAlert()
        alert.messageText     = "Update Available"
        alert.informativeText = "NotchMirror \(latestVersion) is available (you have \(currentVersion))."
        alert.alertStyle      = .informational
        alert.addButton(withTitle: "Download Update")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: releaseURL) {
            NSWorkspace.shared.open(url)
        }
    }
}