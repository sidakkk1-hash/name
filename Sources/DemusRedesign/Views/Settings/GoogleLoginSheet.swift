import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - GoogleLoginSheet
/// Secure in-app sign in sheet for Google / YouTube Music accounts.
/// Captures session cookies to sync user's Liked Music, personal playlists, and recommendations.
public struct GoogleLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                #if canImport(UIKit)
                GoogleLoginWebView(isLoading: $isLoading) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                }
                #endif
                
                if isLoading {
                    ProgressView("Connecting to Google...")
                        .tint(AppleMusicTheme.accent)
                }
            }
            .navigationTitle("Sign in to Google")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppleMusicTheme.accent)
                }
            }
        }
    }
}

// MARK: - GoogleLoginWebView
#if canImport(UIKit)
public struct GoogleLoginWebView: UIViewRepresentable {
    @Binding public var isLoading: Bool
    public let onLoginSuccess: () -> Void
    
    public init(isLoading: Binding<Bool>, onLoginSuccess: @escaping () -> Void) {
        self._isLoading = isLoading
        self.onLoginSuccess = onLoginSuccess
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        
        let store = config.websiteDataStore.httpCookieStore
        store.add(context.coordinator)
        
        let loginURL = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&passive=true&continue=https%3A%2F%2Fmusic.youtube.com%2F")!
        wv.load(URLRequest(url: loginURL))
        return wv
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKHTTPCookieStoreObserver {
        let parent: GoogleLoginWebView
        private var hasHandledSuccess = false
        
        init(_ parent: GoogleLoginWebView) {
            self.parent = parent
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            checkCookies(in: webView.configuration.websiteDataStore.httpCookieStore)
        }
        
        public func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            checkCookies(in: cookieStore)
        }
        
        private func checkCookies(in cookieStore: WKHTTPCookieStore) {
            guard !hasHandledSuccess else { return }
            cookieStore.getAllCookies { [weak self] cookies in
                guard let self = self, !self.hasHandledSuccess else { return }
                let names = cookies.map { $0.name }
                if names.contains("SAPISID") || names.contains("LOGIN_INFO") || names.contains("__Secure-1PSID") {
                    self.hasHandledSuccess = true
                    GoogleAccountManager.shared.saveCookies(from: cookies)
                    DispatchQueue.main.async {
                        self.parent.onLoginSuccess()
                    }
                }
            }
        }
    }
}
#endif
