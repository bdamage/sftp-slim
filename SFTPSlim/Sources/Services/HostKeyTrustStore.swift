import Foundation

@MainActor
final class HostKeyTrustStore {
    private let defaults = UserDefaults.standard

    private func key(for host: String, fingerprint: String) -> String {
        "known_host_\(host)_\(fingerprint)"
    }

    func isTrusted(host: String, fingerprint: String) -> Bool {
        defaults.bool(forKey: key(for: host, fingerprint: fingerprint))
    }

    func trust(host: String, fingerprint: String) {
        defaults.set(true, forKey: key(for: host, fingerprint: fingerprint))
    }
}
