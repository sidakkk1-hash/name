import Foundation
import WebKit

// MARK: - GoogleAccountManager
/// Manages Google / YouTube Music authentication state and cookie storage.
@Observable
public final class GoogleAccountManager: @unchecked Sendable {
    public static let shared = GoogleAccountManager()
    
    public var isLoggedIn: Bool = false
    public var userEmail: String?
    public var userName: String? { userEmail }
    public var cookiesHeader: String = ""
    
    private let cookiesKey = "demus_google_cookies"
    private let emailKey = "demus_google_email"
    
    public init() {
        loadPersistedSession()
    }
    
    private func loadPersistedSession() {
        if let savedCookies = UserDefaults.standard.string(forKey: cookiesKey), !savedCookies.isEmpty {
            self.cookiesHeader = savedCookies
            self.userEmail = UserDefaults.standard.string(forKey: emailKey)
            self.isLoggedIn = true
        }
    }
    
    // MARK: - Save Session from WebKit HTTPCookieStore
    public func saveCookies(from cookies: [HTTPCookie]) {
        var cookieDict: [String: String] = [:]
        for c in cookies {
            if c.domain.contains("youtube.com") || c.domain.contains("google.com") {
                cookieDict[c.name] = c.value
            }
        }
        
        // We look for SAPISID, SSID, HSID, LOGIN_INFO or SID
        guard cookieDict["SAPISID"] != nil || cookieDict["LOGIN_INFO"] != nil || cookieDict["SID"] != nil else {
            return
        }
        
        let headerStr = cookieDict.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        self.cookiesHeader = headerStr
        self.isLoggedIn = true
        UserDefaults.standard.set(headerStr, forKey: cookiesKey)
        
        // Try extracting user ID or account hints
        if let sapisid = cookieDict["SAPISID"] {
            self.userEmail = "Google User (\(sapisid.prefix(6))...)"
            UserDefaults.standard.set(self.userEmail, forKey: emailKey)
        }
        
        print("[GoogleAccountManager] YouTube cookies saved successfully! Logged in = true")
    }
    
    // MARK: - Sign Out
    public func signOut() {
        self.isLoggedIn = false
        self.userEmail = nil
        self.cookiesHeader = ""
        UserDefaults.standard.removeObject(forKey: cookiesKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
        
        // Clear WebKit cookies
        Task { @MainActor in
            let store = WKWebsiteDataStore.default().httpCookieStore
            store.getAllCookies { cookies in
                for c in cookies {
                    store.delete(c)
                }
            }
        }
    }
}
