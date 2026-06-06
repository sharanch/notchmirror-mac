// UpdateChecker.swift

import Foundation
import AppKit

final class UpdateChecker {

    private static let repoOwner = "sharanch"
    private static let repoName  = "notchmirror-mac"
    private static let installedVersionKey = "installedVersion"

    private static let apiURL = URL(string:
        "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
    )!

    static func checkForUpdates() {
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let stored = UserDefaults.standard.string(forKey: installedVersionKey) ?? "0.0.0"

        // If the installed app is newer than what's stored, update stored value
        if isNewer(bundleVersion, than: stored) {
            UserDefaults.standard.set(bundleVersion, forKey: installedVersionKey)
        }

        print("UpdateChecker: starting check against \(apiURL)")

        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in

            if let error {
                print("UpdateChecker: network error — \(error)")
                return
            }

            if let http = response as? HTTPURLResponse {
                print("UpdateChecker: HTTP \(http.statusCode)")
                if http.statusCode != 200 {
                    if let data, let body = String(data: data, encoding: .utf8) {
                        print("UpdateChecker: response body — \(body)")
                    }
                    return
                }
            }

            guard let data else {
                print("UpdateChecker: no data returned")
                return
            }

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tagName = json["tag_name"] as? String,
                let htmlURL = json["html_url"] as? String
            else {
                print("UpdateChecker: failed to parse JSON")
                return
            }

            let latest    = tagName.trimmingCharacters(in: .init(charactersIn: "v"))
            let installed = UserDefaults.standard.string(forKey: installedVersionKey) ?? "0.0.0"

            print("UpdateChecker: latest=\(latest)  installed=\(installed)")

            guard isNewer(latest, than: installed) else {
                print("UpdateChecker: already up to date")
                return
            }

            print("UpdateChecker: update available — showing alert")
            DispatchQueue.main.async {
                showUpdateAlert(latestVersion: latest, releaseURL: htmlURL)
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

    private static func showUpdateAlert(latestVersion: String, releaseURL: String) {
        let alert = NSAlert()
        alert.messageText     = "Update Available"
        alert.informativeText = "NotchMirror \(latestVersion) is available."
        alert.alertStyle      = .informational
        alert.addButton(withTitle: "Download Update")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            UserDefaults.standard.set(latestVersion, forKey: installedVersionKey)
            if let url = URL(string: releaseURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}