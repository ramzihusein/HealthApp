import Foundation

/// Stable per-install user id. Replace with Supabase/Auth user id when you add a backend for web + iOS sync.
enum UserAccountService {
    private static let key = "healthapp.stableUserId"

    static var stableUserId: UUID {
        if let s = UserDefaults.standard.string(forKey: key), let u = UUID(uuidString: s) {
            return u
        }
        let u = UUID()
        UserDefaults.standard.set(u.uuidString, forKey: key)
        return u
    }

    #if DEBUG
    /// Removes the stable id so the next access generates a new UUID (used by debug “reset local data”).
    static func clearStableUserIdForDebug() {
        UserDefaults.standard.removeObject(forKey: key)
    }
    #endif
}
