import Foundation

// MARK: - RLP Encoder
// Recursive Length Prefix encoding for Ethereum transactions
// Implements the RLP encoding spec: https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/

enum RLP {
    
    /// Encode a single byte array
    static func encode(_ data: Data) -> Data {
        if data.count == 1 && data[0] < 0x80 {
            return data
        }
        return encodeLength(data.count, offset: 0x80) + data
    }
    
    /// Encode a UInt64 value (big-endian, no leading zeros)
    static func encode(_ value: UInt64) -> Data {
        if value == 0 {
            return encode(Data())
        }
        return encode(bigEndianBytes(value))
    }
    
    /// Encode a string
    static func encode(_ string: String) -> Data {
        encode(Data(string.utf8))
    }
    
    /// Encode a hex string (with or without 0x prefix)
    static func encodeHex(_ hex: String) -> Data {
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        if clean.isEmpty { return encode(Data()) }
        guard let data = Data(hexString: "0x" + clean) else { return encode(Data()) }
        return encode(data)
    }
    
    /// Encode a list of already-encoded items
    static func encodeList(_ items: [Data]) -> Data {
        let payload = items.reduce(Data()) { $0 + $1 }
        return encodeLength(payload.count, offset: 0xc0) + payload
    }
    
    // MARK: - EIP-1559 Transaction Encoding
    
    /// Encode an EIP-1559 (Type 2) transaction for signing
    /// Returns the unsigned transaction hash (keccak256 of 0x02 || RLP([chainId, nonce, ...]))
    static func encodeEIP1559ForSigning(
        chainId: UInt64,
        nonce: UInt64,
        maxPriorityFeePerGas: UInt64,
        maxFeePerGas: UInt64,
        gasLimit: UInt64,
        to: String,
        value: UInt64,
        data: Data,
        accessList: [[Data]] = []
    ) -> (unsignedTxHash: Data, encodedUnsignedTx: Data) {
        let items: [Data] = [
            encode(chainId),
            encode(nonce),
            encode(maxPriorityFeePerGas),
            encode(maxFeePerGas),
            encode(gasLimit),
            encodeHex(to),
            encode(value),
            encode(data),
            encodeList(accessList.map { encodeList($0) }) // empty access list
        ]
        
        let rlpEncoded = encodeList(items)
        // EIP-1559: signing hash = keccak256(0x02 || RLP([...]))
        let toHash = Data([0x02]) + rlpEncoded
        let hash = Keccak256.hash(toHash)
        
        return (unsignedTxHash: hash, encodedUnsignedTx: rlpEncoded)
    }
    
    /// Encode a signed EIP-1559 transaction for broadcast
    /// Returns the raw signed transaction hex (0x02 || RLP([..., v, r, s]))
    static func encodeSignedEIP1559(
        chainId: UInt64,
        nonce: UInt64,
        maxPriorityFeePerGas: UInt64,
        maxFeePerGas: UInt64,
        gasLimit: UInt64,
        to: String,
        value: UInt64,
        data: Data,
        v: UInt8,
        r: Data,
        s: Data
    ) -> Data {
        // For EIP-1559, v is the recovery id (0 or 1), not 27/28
        let yParity: UInt64 = UInt64(v >= 27 ? v - 27 : v)
        
        let items: [Data] = [
            encode(chainId),
            encode(nonce),
            encode(maxPriorityFeePerGas),
            encode(maxFeePerGas),
            encode(gasLimit),
            encodeHex(to),
            encode(value),
            encode(data),
            encodeList([]), // empty access list
            encode(yParity),
            encode(stripLeadingZeros(r)),
            encode(stripLeadingZeros(s))
        ]
        
        let rlpEncoded = encodeList(items)
        // Type 2 prefix
        return Data([0x02]) + rlpEncoded
    }
    
    // MARK: - Legacy Transaction Encoding
    
    /// Encode a legacy transaction for signing (EIP-155)
    static func encodeLegacyForSigning(
        nonce: UInt64,
        gasPrice: UInt64,
        gasLimit: UInt64,
        to: String,
        value: UInt64,
        data: Data,
        chainId: UInt64
    ) -> (unsignedTxHash: Data, encodedUnsignedTx: Data) {
        let items: [Data] = [
            encode(nonce),
            encode(gasPrice),
            encode(gasLimit),
            encodeHex(to),
            encode(value),
            encode(data),
            encode(chainId),   // EIP-155: chainId
            encode(Data()),    // EIP-155: 0
            encode(Data())     // EIP-155: 0
        ]
        
        let rlpEncoded = encodeList(items)
        let hash = Keccak256.hash(rlpEncoded)
        return (unsignedTxHash: hash, encodedUnsignedTx: rlpEncoded)
    }
    
    /// Encode a signed legacy transaction for broadcast
    static func encodeSignedLegacy(
        nonce: UInt64,
        gasPrice: UInt64,
        gasLimit: UInt64,
        to: String,
        value: UInt64,
        data: Data,
        chainId: UInt64,
        v: UInt8,
        r: Data,
        s: Data
    ) -> Data {
        // EIP-155: v = chainId * 2 + 35 + recovery_id
        let recoveryId = v >= 27 ? v - 27 : v
        let eip155V = chainId * 2 + 35 + UInt64(recoveryId)
        
        let items: [Data] = [
            encode(nonce),
            encode(gasPrice),
            encode(gasLimit),
            encodeHex(to),
            encode(value),
            encode(data),
            encode(eip155V),
            encode(stripLeadingZeros(r)),
            encode(stripLeadingZeros(s))
        ]
        
        return encodeList(items)
    }
    
    // MARK: - Private Helpers
    
    private static func encodeLength(_ length: Int, offset: UInt8) -> Data {
        if length < 56 {
            return Data([offset + UInt8(length)])
        }
        let lengthBytes = bigEndianBytes(UInt64(length))
        return Data([offset + 55 + UInt8(lengthBytes.count)]) + lengthBytes
    }
    
    private static func bigEndianBytes(_ value: UInt64) -> Data {
        if value == 0 { return Data() }
        var bytes = withUnsafeBytes(of: value.bigEndian) { Data($0) }
        // Strip leading zeros
        while let first = bytes.first, first == 0 {
            bytes.removeFirst()
        }
        return bytes
    }
    
    private static func stripLeadingZeros(_ data: Data) -> Data {
        var result = data
        while let first = result.first, first == 0, result.count > 0 {
            result.removeFirst()
        }
        return result.isEmpty ? Data([0]) : result
    }
}
