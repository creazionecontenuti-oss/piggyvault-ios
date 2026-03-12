import Foundation
import Network
import Combine
import SwiftUI

enum NetworkStatus: Equatable {
    case connected
    case disconnected
    case checking
    case blockchainError(String)
    
    var isOnline: Bool {
        if case .connected = self { return true }
        return false
    }
    
    static func == (lhs: NetworkStatus, rhs: NetworkStatus) -> Bool {
        switch (lhs, rhs) {
        case (.connected, .connected): return true
        case (.disconnected, .disconnected): return true
        case (.checking, .checking): return true
        case (.blockchainError(let a), .blockchainError(let b)): return a == b
        default: return false
        }
    }
}

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var status: NetworkStatus = .checking
    @Published var lastBlockNumber: UInt64 = 0
    @Published var latency: TimeInterval = 0
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var healthCheckTimer: Timer?
    private let blockchainService = BlockchainService()
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                if path.status == .satisfied {
                    await self?.checkBlockchainHealth()
                } else {
                    self?.status = .disconnected
                }
            }
        }
        monitor.start(queue: queue)
        
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkBlockchainHealth()
            }
        }
        
        Task {
            await checkBlockchainHealth()
        }
    }
    
    func checkBlockchainHealth() async {
        let startTime = Date()
        
        do {
            let blockNumber = try await fetchBlockNumber()
            let elapsed = Date().timeIntervalSince(startTime)
            
            latency = elapsed
            lastBlockNumber = blockNumber
            
            withAnimation(.easeInOut(duration: 0.3)) {
                status = .connected
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.3)) {
                status = .blockchainError(error.localizedDescription)
            }
        }
    }
    
    private func fetchBlockNumber() async throws -> UInt64 {
        let url = URL(string: "https://mainnet.base.org")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_blockNumber",
            "params": [],
            "id": 1
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: params)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BlockchainError.networkUnavailable
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hexString = json["result"] as? String else {
            throw BlockchainError.rpcError("Invalid block number response")
        }
        
        let cleanHex = hexString.replacingOccurrences(of: "0x", with: "")
        return UInt64(cleanHex, radix: 16) ?? 0
    }
    
    func stopMonitoring() {
        monitor.cancel()
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    deinit {
        monitor.cancel()
        healthCheckTimer?.invalidate()
    }
}
