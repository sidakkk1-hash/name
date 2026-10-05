import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - ImageCache
/// High-performance thread-safe in-memory and disk cache for image thumbnails.
public final class ImageCache: @unchecked Sendable {
    public static let shared = ImageCache()
    
    #if canImport(UIKit)
    private let cache = NSCache<NSURL, UIImage>()
    #endif
    
    private init() {
        #if canImport(UIKit)
        // Store up to 250 images or 80 MB in fast memory
        cache.countLimit = 250
        cache.totalCostLimit = 80 * 1024 * 1024
        #endif
        
        // Ensure standard URLCache has sufficient capacity
        let memoryCapacity = 50 * 1024 * 1024
        let diskCapacity = 200 * 1024 * 1024
        URLCache.shared = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
    }
    
    #if canImport(UIKit)
    public func get(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }
    
    public func set(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
    #endif
}

// MARK: - CachedAsyncImage
/// Drop-in replacement for SwiftUI's AsyncImage with persistent in-memory caching,
/// fast decoding, smooth crossfades, and zero reload flicker.
public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    #if canImport(UIKit)
    @State private var uiImage: UIImage?
    #endif
    @State private var isLoading: Bool = false
    
    public init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        
        #if canImport(UIKit)
        if let u = url, let cached = ImageCache.shared.get(for: u) {
            _uiImage = State(initialValue: cached)
        }
        #endif
    }
    
    public var body: some View {
        ZStack {
            #if canImport(UIKit)
            if let img = uiImage {
                content(Image(uiImage: img))
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            } else {
                placeholder()
            }
            #else
            placeholder()
            #endif
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    @MainActor
    private func loadImage() async {
        guard let url = url else { return }
        #if canImport(UIKit)
        if let cached = ImageCache.shared.get(for: url) {
            self.uiImage = cached
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 10
            
            let (data, _) = try await URLSession.shared.data(for: request)
            if let decoded = UIImage(data: data) {
                ImageCache.shared.set(decoded, for: url)
                withAnimation(.easeInOut(duration: 0.22)) {
                    self.uiImage = decoded
                }
            }
        } catch {
            // Silently retain placeholder
        }
        #endif
    }
}
