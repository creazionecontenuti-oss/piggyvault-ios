import Foundation
import WebKit
import SwiftUI

// MARK: - Lit Protocol Signing Bridge
// Bridges native iOS to Lit Protocol's JS SDK via a hidden WKWebView.
// The Lit JS SDK runs inside the WebView and communicates results back to Swift
// via WKScriptMessageHandler.

enum LitSigningError: LocalizedError {
    case bridgeNotReady
    case signingFailed(String)
    case timeout
    case invalidResponse
    case sessionExpired
    
    var errorDescription: String? {
        switch self {
        case .bridgeNotReady: return "error.lit.bridge_not_ready".localized
        case .signingFailed(let msg): return String(format: "error.lit.signing_failed".localized, msg)
        case .timeout: return "error.lit.timeout".localized
        case .invalidResponse: return "error.lit.invalid_response".localized
        case .sessionExpired: return "error.lit.session_expired".localized
        }
    }
}

/// Result of a Lit Protocol PKP signing operation
struct LitSignatureResult {
    let r: String
    let s: String
    let v: UInt8
    let signature: String // Full hex signature
    let dataSigned: String
}

@MainActor
final class LitSigningBridge: NSObject, ObservableObject {
    
    @Published private(set) var isReady = false
    @Published private(set) var isLoading = false
    
    private var webView: WKWebView?
    private var pendingSignatures: [String: CheckedContinuation<LitSignatureResult, Error>] = [:]
    private var readyContinuation: CheckedContinuation<Void, Never>?
    
    private let litNetwork = "datil" // Lit network name — must match LitProtocolService
    
    // MARK: - Initialization
    
    /// Initialize the bridge by loading the Lit JS SDK in a hidden WebView
    func initialize() async {
        guard webView == nil else { return }
        
        isLoading = true
        
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        
        // Register message handlers for JS -> Swift communication
        contentController.add(self, name: "litBridgeReady")
        contentController.add(self, name: "litBridgeError")
        contentController.add(self, name: "litSignResult")
        contentController.add(self, name: "litSignError")
        contentController.add(self, name: "litSessionResult")
        contentController.add(self, name: "litLog")
        
        config.userContentController = contentController
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        self.webView = wv
        
        // Load the bridge HTML with Lit JS SDK
        let html = generateBridgeHTML()
        wv.loadHTMLString(html, baseURL: URL(string: "https://piggyvault.local"))
        
        // Wait for the bridge to signal readiness (with 30s timeout)
        let didReady = await withTaskGroup(of: Bool.self) { group in
            group.addTask { @MainActor in
                await withCheckedContinuation { continuation in
                    self.readyContinuation = continuation
                }
                return true
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
        
        if didReady {
            isReady = true
            print("[LitBridge] ✅ Bridge initialized successfully")
        } else {
            print("[LitBridge] ❌ Bridge initialization timed out after 30s")
            readyContinuation?.resume()
            readyContinuation = nil
        }
        
        isLoading = false
    }
    
    // MARK: - Session Management
    
    /// Connect to Lit network and establish a session
    func connectAndCreateSession(authSig: String, pkpPublicKey: String) async throws {
        guard isReady, let webView else { throw LitSigningError.bridgeNotReady }
        
        let js = """
        (async () => {
            try {
                await window.litBridge.connect();
                const sessionSigs = await window.litBridge.getSessionSigs(
                    '\(authSig.escapedForJS)',
                    '\(pkpPublicKey.escapedForJS)'
                );
                window.webkit.messageHandlers.litSessionResult.postMessage({
                    success: true,
                    sessionSigs: JSON.stringify(sessionSigs)
                });
            } catch(e) {
                window.webkit.messageHandlers.litSessionResult.postMessage({
                    success: false,
                    error: e.message || String(e)
                });
            }
        })();
        """
        
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    /// Sign a transaction hash using the PKP via Lit network
    func signTransaction(
        toSign: Data,
        pkpPublicKey: String,
        authSig: String
    ) async throws -> LitSignatureResult {
        guard isReady, let webView else { throw LitSigningError.bridgeNotReady }
        
        let requestId = UUID().uuidString
        let hexToSign = toSign.map { String(format: "%02x", $0) }.joined()
        
        let js = """
        (async () => {
            try {
                const result = await window.litBridge.signTransaction(
                    '\(hexToSign)',
                    '\(pkpPublicKey.escapedForJS)',
                    '\(authSig.escapedForJS)'
                );
                window.webkit.messageHandlers.litSignResult.postMessage({
                    requestId: '\(requestId)',
                    success: true,
                    r: result.r,
                    s: result.s,
                    v: result.recid,
                    signature: result.signature,
                    dataSigned: result.dataSigned
                });
            } catch(e) {
                window.webkit.messageHandlers.litSignError.postMessage({
                    requestId: '\(requestId)',
                    error: e.message || String(e)
                });
            }
        })();
        """
        
        return try await withCheckedThrowingContinuation { continuation in
            self.pendingSignatures[requestId] = continuation
            webView.evaluateJavaScript(js)
            
            // Timeout after 30 seconds
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if let cont = self.pendingSignatures.removeValue(forKey: requestId) {
                    cont.resume(throwing: LitSigningError.timeout)
                }
            }
        }
    }
    
    /// Sign an EIP-191 personal message
    func signMessage(
        message: String,
        pkpPublicKey: String,
        authSig: String
    ) async throws -> LitSignatureResult {
        let messageData = Data(message.utf8)
        return try await signTransaction(
            toSign: messageData,
            pkpPublicKey: pkpPublicKey,
            authSig: authSig
        )
    }
    
    /// Disconnect from Lit network
    func disconnect() {
        webView?.evaluateJavaScript("window.litBridge.disconnect();")
        pendingSignatures.removeAll()
    }
    
    /// Tear down the bridge
    func tearDown() {
        disconnect()
        webView?.configuration.userContentController.removeAllScriptMessageHandlers()
        webView = nil
        isReady = false
    }
    
    // MARK: - HTML Bridge Generation
    
    private func generateBridgeHTML() -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script src="https://cdn.jsdelivr.net/npm/@lit-protocol/lit-node-client-vanilla/lit-node-client.js"
                    onerror="window.webkit.messageHandlers.litBridgeError.postMessage('Failed to load lit-node-client')"></script>
            <script src="https://cdn.jsdelivr.net/npm/@lit-protocol/auth-helpers-vanilla/auth-helpers.js"
                    onerror="window.webkit.messageHandlers.litBridgeError.postMessage('Failed to load auth-helpers')"></script>
        </head>
        <body>
        <script>
        (function() {
            'use strict';
            
            if (typeof LitJsSdk_litNodeClient === 'undefined') {
                window.webkit.messageHandlers.litBridgeError.postMessage('LitJsSdk_litNodeClient not defined');
                return;
            }
            if (typeof LitJsSdk_authHelpers === 'undefined') {
                window.webkit.messageHandlers.litBridgeError.postMessage('LitJsSdk_authHelpers not defined');
                return;
            }
            
            const LitClient = LitJsSdk_litNodeClient;
            const LitAuth = LitJsSdk_authHelpers;
            
            const log = (msg) => {
                window.webkit.messageHandlers.litLog.postMessage(String(msg));
            };
            
            class LitBridge {
                constructor() {
                    this.client = null;
                    this.sessionSigs = null;
                    this.network = '\(litNetwork)';
                }
                
                async connect() {
                    if (this.client) return;
                    
                    log('Connecting to Lit network: ' + this.network);
                    this.client = new LitClient.LitNodeClient({
                        litNetwork: this.network,
                        debug: false
                    });
                    
                    await this.client.connect();
                    log('Connected to Lit network');
                }
                
                async getSessionSigs(authSig, pkpPublicKey) {
                    if (!this.client) throw new Error('Not connected');
                    
                    log('Getting session signatures...');
                    
                    const authMethod = JSON.parse(authSig);
                    
                    this.sessionSigs = await this.client.getSessionSigs({
                        pkpPublicKey: pkpPublicKey,
                        authMethods: [authMethod],
                        resourceAbilityRequests: [
                            {
                                resource: new LitAuth.LitPKPResource('*'),
                                ability: LitClient.LitAbility.PKPSigning
                            }
                        ],
                        chain: 'base'
                    });
                    
                    log('Session signatures obtained');
                    return this.sessionSigs;
                }
                
                async signTransaction(hexData, pkpPublicKey, authSig) {
                    // Auto-connect if not connected yet
                    if (!this.client) {
                        await this.connect();
                    }
                    
                    // Ensure we have session sigs
                    if (!this.sessionSigs) {
                        await this.getSessionSigs(authSig, pkpPublicKey);
                    }
                    
                    log('Signing with PKP...');
                    
                    // Convert hex string to Uint8Array
                    const bytes = new Uint8Array(
                        hexData.match(/.{1,2}/g).map(b => parseInt(b, 16))
                    );
                    
                    const sigResult = await this.client.pkpSign({
                        pubKey: pkpPublicKey,
                        toSign: bytes,
                        sessionSigs: this.sessionSigs
                    });
                    
                    log('Signature obtained: ' + sigResult.signature.substring(0, 20) + '...');
                    return sigResult;
                }
                
                disconnect() {
                    if (this.client) {
                        this.client.disconnect();
                        this.client = null;
                        this.sessionSigs = null;
                    }
                    log('Disconnected from Lit network');
                }
            }
            
            // Initialize and signal readiness
            window.litBridge = new LitBridge();
            
            // Signal to native that the bridge is ready
            log('Lit bridge initialized, signaling ready');
            window.webkit.messageHandlers.litBridgeReady.postMessage({ready: true});
        })();
        </script>
        </body>
        </html>
        """
    }
}

// MARK: - WKScriptMessageHandler

extension LitSigningBridge: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        Task { @MainActor in
            switch message.name {
            case "litBridgeReady":
                readyContinuation?.resume()
                readyContinuation = nil
                
            case "litBridgeError":
                let errorMsg = (message.body as? String) ?? "Unknown bridge error"
                print("[LitBridge] ❌ Bridge error: \(errorMsg)")
                // Resume the continuation so initialize() doesn't hang
                readyContinuation?.resume()
                readyContinuation = nil
                
            case "litSignResult":
                guard let body = message.body as? [String: Any],
                      let requestId = body["requestId"] as? String,
                      let success = body["success"] as? Bool, success,
                      let r = body["r"] as? String,
                      let s = body["s"] as? String,
                      let v = body["v"] as? Int,
                      let signature = body["signature"] as? String,
                      let dataSigned = body["dataSigned"] as? String
                else { return }
                
                let result = LitSignatureResult(
                    r: r, s: s, v: UInt8(v),
                    signature: signature, dataSigned: dataSigned
                )
                pendingSignatures.removeValue(forKey: requestId)?.resume(returning: result)
                
            case "litSignError":
                guard let body = message.body as? [String: Any],
                      let requestId = body["requestId"] as? String,
                      let errorMsg = body["error"] as? String
                else { return }
                
                pendingSignatures.removeValue(forKey: requestId)?
                    .resume(throwing: LitSigningError.signingFailed(errorMsg))
                
            case "litSessionResult":
                guard let body = message.body as? [String: Any] else { return }
                if let success = body["success"] as? Bool, !success {
                    let error = body["error"] as? String ?? "Unknown session error"
                    print("[LitBridge] Session error: \(error)")
                }
                
            case "litLog":
                if let msg = message.body as? String {
                    print("[LitBridge] \(msg)")
                }
                
            default:
                break
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension LitSigningBridge: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[LitBridge] Navigation failed: \(error.localizedDescription)")
    }
    
    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[LitBridge] Provisional navigation failed: \(error.localizedDescription)")
    }
}

// MARK: - String JS Escape Helper

private extension String {
    var escapedForJS: String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
