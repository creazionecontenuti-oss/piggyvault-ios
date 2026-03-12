import Foundation

// MARK: - Pure Swift Keccak-256 Implementation
// No external dependencies. Used for Ethereum address derivation and CREATE2.

struct Keccak256 {
    
    static func hash(_ data: Data) -> Data {
        var state = KeccakState()
        state.absorb(data)
        return state.squeeze(outputLength: 32)
    }
    
    static func hash(_ string: String) -> Data {
        hash(Data(string.utf8))
    }
    
    static func hashHex(_ data: Data) -> String {
        hash(data).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Keccak State Machine (SHA-3 / Keccak-256)

private struct KeccakState {
    private var state: [UInt64] = Array(repeating: 0, count: 25)
    private let rate = 136 // (1600 - 256*2) / 8 = 136 bytes for Keccak-256
    
    mutating func absorb(_ data: Data) {
        var input = Array(data)
        // Keccak padding (not SHA-3 padding!)
        // Keccak uses 0x01, SHA-3 uses 0x06
        input.append(0x01)
        while input.count % rate != (rate - 1) {
            input.append(0x00)
        }
        input.append(0x80)
        
        // Process blocks
        var offset = 0
        while offset < input.count {
            let block = Array(input[offset..<min(offset + rate, input.count)])
            absorbBlock(block)
            keccakF1600()
            offset += rate
        }
    }
    
    private mutating func absorbBlock(_ block: [UInt8]) {
        for i in 0..<(block.count / 8) {
            let word = block[i*8..<min((i+1)*8, block.count)].enumerated().reduce(UInt64(0)) { acc, pair in
                acc | (UInt64(pair.element) << (pair.offset * 8))
            }
            state[i] ^= word
        }
    }
    
    mutating func squeeze(outputLength: Int) -> Data {
        var output = Data()
        while output.count < outputLength {
            for i in 0..<(rate / 8) {
                if output.count >= outputLength { break }
                var word = state[i]
                for _ in 0..<8 {
                    if output.count >= outputLength { break }
                    output.append(UInt8(word & 0xFF))
                    word >>= 8
                }
            }
            if output.count < outputLength {
                keccakF1600()
            }
        }
        return Data(output.prefix(outputLength))
    }
    
    // MARK: - Keccak-f[1600] Permutation
    
    private static let roundConstants: [UInt64] = [
        0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
        0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
        0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
        0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
        0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
        0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008
    ]
    
    private static let rotationOffsets: [Int] = [
         0,  1, 62, 28, 27,
        36, 44,  6, 55, 20,
         3, 10, 43, 25, 39,
        41, 45, 15, 21,  8,
        18,  2, 61, 56, 14
    ]
    
    private static let piLane: [Int] = [
        0, 10, 20, 5, 15,
        16, 1, 11, 21, 6,
        7, 17, 2, 12, 22,
        23, 8, 18, 3, 13,
        14, 24, 9, 19, 4
    ]
    
    private mutating func keccakF1600() {
        for round in 0..<24 {
            // θ (theta)
            var c = [UInt64](repeating: 0, count: 5)
            for x in 0..<5 {
                c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20]
            }
            var d = [UInt64](repeating: 0, count: 5)
            for x in 0..<5 {
                d[x] = c[(x + 4) % 5] ^ rotateLeft(c[(x + 1) % 5], by: 1)
            }
            for x in 0..<5 {
                for y in 0..<5 {
                    state[x + 5 * y] ^= d[x]
                }
            }
            
            // ρ (rho) and π (pi)
            var temp = [UInt64](repeating: 0, count: 25)
            for i in 0..<25 {
                temp[KeccakState.piLane[i]] = rotateLeft(state[i], by: KeccakState.rotationOffsets[i])
            }
            
            // χ (chi)
            for y in 0..<5 {
                for x in 0..<5 {
                    state[x + 5 * y] = temp[x + 5 * y] ^ (~temp[(x + 1) % 5 + 5 * y] & temp[(x + 2) % 5 + 5 * y])
                }
            }
            
            // ι (iota)
            state[0] ^= KeccakState.roundConstants[round]
        }
    }
    
    private func rotateLeft(_ value: UInt64, by count: Int) -> UInt64 {
        let count = count % 64
        if count == 0 { return value }
        return (value << count) | (value >> (64 - count))
    }
}
