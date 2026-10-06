import Foundation
import Network

// MARK: - LocalHLSServer
/// Embedded loopback HTTP server (127.0.0.1) using Apple's Network framework (NWListener).
/// Serves dynamically generated HLS playlists to AVPlayer over HTTP, bypassing Apple's
/// AVFoundation security sandbox restriction where local `file://` manifests cannot stream remote HTTPS segments.
public final class LocalHLSServer: @unchecked Sendable {
    public static let shared = LocalHLSServer()
    
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.demusapp.localhlsserver", qos: .userInitiated)
    private let lock = NSLock()
    
    private var currentPlaylistData: Data?
    public private(set) var currentPort: UInt16 = 0
    public private(set) var isRunning: Bool = false
    public private(set) var lastRequestReceived: String?
    public private(set) var requestsServedCount: Int = 0
    
    private init() {}
    
    /// Ensures the loopback server is running and returns the active port.
    public func ensureStarted() async throws -> UInt16 {
        lock.lock()
        if isRunning && currentPort > 0 {
            let port = currentPort
            lock.unlock()
            return port
        }
        lock.unlock()
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: NSError(domain: "LocalHLSServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server deallocated"]))
                    return
                }
                
                self.lock.lock()
                if self.isRunning && self.currentPort > 0 {
                    let port = self.currentPort
                    self.lock.unlock()
                    continuation.resume(returning: port)
                    return
                }
                self.lock.unlock()
                
                do {
                    let params = NWParameters.tcp
                    params.allowLocalEndpointReuse = true
                    
                    // Listen on any available loopback port
                    let listener = try NWListener(using: params, on: .any)
                    var hasResumed = false
                    
                    listener.stateUpdateHandler = { [weak self] state in
                        guard let self = self else { return }
                        switch state {
                        case .ready:
                            if let port = listener.port?.rawValue {
                                self.lock.lock()
                                self.currentPort = port
                                self.isRunning = true
                                self.lock.unlock()
                                print("[LocalHLSServer] Ready on http://127.0.0.1:\(port)")
                                if !hasResumed {
                                    hasResumed = true
                                    continuation.resume(returning: port)
                                }
                            }
                        case .failed(let err):
                            print("[LocalHLSServer] Listener failed: \(err)")
                            self.lock.lock()
                            self.isRunning = false
                            self.lock.unlock()
                            if !hasResumed {
                                hasResumed = true
                                continuation.resume(throwing: err)
                            }
                        case .cancelled:
                            self.lock.lock()
                            self.isRunning = false
                            self.lock.unlock()
                        default:
                            break
                        }
                    }
                    
                    listener.newConnectionHandler = { [weak self] connection in
                        self?.handleConnection(connection)
                    }
                    
                    self.listener = listener
                    listener.start(queue: self.queue)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Updates the active playlist manifest served by the server.
    public func setPlaylist(content: String) {
        lock.lock()
        defer { lock.unlock() }
        self.currentPlaylistData = content.data(using: .utf8)
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let self = self else {
                connection.cancel()
                return
            }
            
            if let data = data, let reqStr = String(data: data, encoding: .utf8) {
                let firstLine = reqStr.components(separatedBy: "\r\n").first ?? "GET"
                print("[LocalHLSServer] Received: \(firstLine)")
                
                self.lock.lock()
                self.lastRequestReceived = firstLine
                self.requestsServedCount += 1
                let playlist = self.currentPlaylistData
                self.lock.unlock()
                
                if let playlist = playlist {
                    let isHead = firstLine.uppercased().starts(with: "HEAD")
                    var responseText = "HTTP/1.1 200 OK\r\n"
                    responseText += "Content-Type: application/x-mpegURL\r\n"
                    responseText += "Content-Length: \(playlist.count)\r\n"
                    responseText += "Access-Control-Allow-Origin: *\r\n"
                    responseText += "Accept-Ranges: bytes\r\n"
                    responseText += "Connection: close\r\n\r\n"
                    
                    var responseData = responseText.data(using: .utf8) ?? Data()
                    if !isHead {
                        responseData.append(playlist)
                    }
                    
                    connection.send(content: responseData, completion: .contentProcessed({ _ in
                        connection.cancel()
                    }))
                    return
                }
            }
            
            let notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            connection.send(content: notFound.data(using: .utf8), completion: .contentProcessed({ _ in
                connection.cancel()
            }))
        }
    }
    
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        listener?.cancel()
        listener = nil
        isRunning = false
        currentPort = 0
    }
}
