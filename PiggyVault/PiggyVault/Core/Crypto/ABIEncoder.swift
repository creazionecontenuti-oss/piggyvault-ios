import Foundation

// MARK: - Ethereum ABI Encoder
// Encodes function calls and parameters for smart contract interactions.

struct ABIEncoder {
    
    // MARK: - Function Selector
    
    /// Computes the 4-byte function selector: keccak256(signature)[0:4]
    static func functionSelector(_ signature: String) -> Data {
        Keccak256.hash(signature).prefix(4)
    }
    
    static func functionSelectorHex(_ signature: String) -> String {
        "0x" + functionSelector(signature).map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Type Encoding
    
    /// Encodes an address (20 bytes) left-padded to 32 bytes
    static func encodeAddress(_ address: String) -> Data {
        let clean = address.hasPrefix("0x") ? String(address.dropFirst(2)) : address
        let bytes = Data(hexString: clean) ?? Data(repeating: 0, count: 20)
        return Data(repeating: 0, count: 32 - bytes.count) + bytes
    }
    
    /// Encodes a uint256 value
    static func encodeUint256(_ value: UInt64) -> Data {
        var data = Data(repeating: 0, count: 24)
        var v = value.bigEndian
        data.append(Data(bytes: &v, count: 8))
        return data
    }
    
    /// Encodes a uint256 from a BigUInt-like hex string
    static func encodeUint256(hex: String) -> Data {
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        let bytes = Data(hexString: clean) ?? Data()
        let padded = Data(repeating: 0, count: max(0, 32 - bytes.count)) + bytes
        return Data(padded.suffix(32))
    }
    
    /// Encodes a bool value
    static func encodeBool(_ value: Bool) -> Data {
        encodeUint256(value ? 1 : 0)
    }
    
    /// Encodes bytes (dynamic type) with offset, length, and padded data
    static func encodeBytes(_ data: Data) -> (offset: Data, encoded: Data) {
        let length = encodeUint256(UInt64(data.count))
        let paddedLength = ((data.count + 31) / 32) * 32
        let paddedData = data + Data(repeating: 0, count: paddedLength - data.count)
        return (offset: Data(), encoded: length + paddedData)
    }
    
    /// Encodes a dynamic array of addresses
    static func encodeAddressArray(_ addresses: [String]) -> (offset: Data, encoded: Data) {
        let length = encodeUint256(UInt64(addresses.count))
        var encoded = length
        for addr in addresses {
            encoded += encodeAddress(addr)
        }
        return (offset: Data(), encoded: encoded)
    }
    
    // MARK: - Safe-Specific Encoding
    
    /// Encodes Safe.setup() call
    /// setup(address[] _owners, uint256 _threshold, address to, bytes calldata data,
    ///        address fallbackHandler, address paymentToken, uint256 payment, address paymentReceiver)
    static func encodeSafeSetup(
        owners: [String],
        threshold: UInt64,
        to: String = EthConstants.zeroAddress,
        data: Data = Data(),
        fallbackHandler: String,
        paymentToken: String = EthConstants.zeroAddress,
        payment: UInt64 = 0,
        paymentReceiver: String = EthConstants.zeroAddress
    ) -> Data {
        let selector = functionSelector("setup(address[],uint256,address,bytes,address,address,uint256,address)")
        
        // Head section: 8 parameters, each 32 bytes offset/value
        // Dynamic types (address[], bytes) store offsets
        
        // Calculate offsets for dynamic types
        let headSize: UInt64 = 8 * 32 // 8 params * 32 bytes each
        let ownersOffset = headSize
        let dataOffset = ownersOffset + UInt64(32 + owners.count * 32) // length + elements
        
        var encoded = selector
        
        // Param 0: owners array offset
        encoded += encodeUint256(ownersOffset)
        // Param 1: threshold
        encoded += encodeUint256(threshold)
        // Param 2: to address
        encoded += encodeAddress(to)
        // Param 3: data offset
        encoded += encodeUint256(dataOffset)
        // Param 4: fallbackHandler
        encoded += encodeAddress(fallbackHandler)
        // Param 5: paymentToken
        encoded += encodeAddress(paymentToken)
        // Param 6: payment
        encoded += encodeUint256(payment)
        // Param 7: paymentReceiver
        encoded += encodeAddress(paymentReceiver)
        
        // Dynamic data: owners array
        encoded += encodeUint256(UInt64(owners.count))
        for owner in owners {
            encoded += encodeAddress(owner)
        }
        
        // Dynamic data: bytes data
        let (_, bytesEncoded) = encodeBytes(data)
        encoded += bytesEncoded
        
        return encoded
    }
    
    /// Encodes ERC20 transfer(address,uint256)
    static func encodeERC20Transfer(to: String, amount: UInt64) -> Data {
        let selector = functionSelector("transfer(address,uint256)")
        return selector + encodeAddress(to) + encodeUint256(amount)
    }
    
    /// Encodes ERC20 approve(address,uint256)
    static func encodeERC20Approve(spender: String, amount: UInt64) -> Data {
        let selector = functionSelector("approve(address,uint256)")
        return selector + encodeAddress(spender) + encodeUint256(amount)
    }
    
    /// Encodes Safe execTransaction
    static func encodeSafeExecTransaction(
        to: String,
        value: UInt64,
        data: Data,
        operation: UInt8 = 0, // 0 = Call, 1 = DelegateCall
        safeTxGas: UInt64 = 0,
        baseGas: UInt64 = 0,
        gasPrice: UInt64 = 0,
        gasToken: String = EthConstants.zeroAddress,
        refundReceiver: String = EthConstants.zeroAddress,
        signatures: Data
    ) -> Data {
        let selector = functionSelector(
            "execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)"
        )
        
        let headSize: UInt64 = 10 * 32
        let dataOffset = headSize
        let sigsOffset = dataOffset + UInt64(32 + ((data.count + 31) / 32) * 32)
        
        var encoded = selector
        encoded += encodeAddress(to)
        encoded += encodeUint256(value)
        encoded += encodeUint256(dataOffset) // data offset
        encoded += encodeUint256(UInt64(operation))
        encoded += encodeUint256(safeTxGas)
        encoded += encodeUint256(baseGas)
        encoded += encodeUint256(gasPrice)
        encoded += encodeAddress(gasToken)
        encoded += encodeAddress(refundReceiver)
        encoded += encodeUint256(sigsOffset) // signatures offset
        
        // Dynamic: data
        let (_, dataEncoded) = encodeBytes(data)
        encoded += dataEncoded
        
        // Dynamic: signatures
        let (_, sigsEncoded) = encodeBytes(signatures)
        encoded += sigsEncoded
        
        return encoded
    }
    
    /// Encodes createProxyWithNonce on SafeProxyFactory
    static func encodeCreateProxyWithNonce(
        singleton: String,
        initializer: Data,
        saltNonce: UInt64
    ) -> Data {
        let selector = functionSelector("createProxyWithNonce(address,bytes,uint256)")
        
        let headSize: UInt64 = 3 * 32
        let initializerOffset = headSize
        
        var encoded = selector
        encoded += encodeAddress(singleton)
        encoded += encodeUint256(initializerOffset)
        encoded += encodeUint256(saltNonce)
        
        let (_, initEncoded) = encodeBytes(initializer)
        encoded += initEncoded
        
        return encoded
    }
}

// MARK: - Ethereum Address Utilities

struct EthAddress {
    
    /// Derives an Ethereum address from a 64-byte uncompressed public key (without 0x04 prefix)
    static func fromPublicKey(_ publicKeyHex: String) -> String {
        let clean = publicKeyHex.hasPrefix("0x04") ? String(publicKeyHex.dropFirst(4)) :
                    publicKeyHex.hasPrefix("04") ? String(publicKeyHex.dropFirst(2)) :
                    (publicKeyHex.hasPrefix("0x") ? String(publicKeyHex.dropFirst(2)) : publicKeyHex)
        
        guard let pubKeyData = Data(hexString: clean) else { return EthConstants.zeroAddress }
        
        let hash = Keccak256.hash(pubKeyData)
        let addressBytes = hash.suffix(20)
        return "0x" + addressBytes.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Computes CREATE2 address: keccak256(0xff ++ factory ++ salt ++ keccak256(initCode))[12:]
    static func computeCREATE2(
        factory: String,
        salt: Data,
        initCodeHash: Data
    ) -> String {
        var payload = Data([0xff])
        
        let factoryClean = factory.hasPrefix("0x") ? String(factory.dropFirst(2)) : factory
        payload += Data(hexString: factoryClean) ?? Data(repeating: 0, count: 20)
        payload += salt
        payload += initCodeHash
        
        let hash = Keccak256.hash(payload)
        let addressBytes = hash.suffix(20)
        return "0x" + addressBytes.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Checksums an Ethereum address (EIP-55)
    static func checksum(_ address: String) -> String {
        let clean = address.hasPrefix("0x") ? String(address.dropFirst(2)).lowercased() : address.lowercased()
        let hashHex = Keccak256.hashHex(Data(clean.utf8))
        
        var result = "0x"
        for (i, char) in clean.enumerated() {
            let hashChar = hashHex[hashHex.index(hashHex.startIndex, offsetBy: i)]
            if let hashVal = UInt8(String(hashChar), radix: 16), hashVal >= 8 {
                result += String(char).uppercased()
            } else {
                result += String(char)
            }
        }
        return result
    }
}

// MARK: - Constants

enum EthConstants {
    static let zeroAddress = "0x0000000000000000000000000000000000000000"
    static let maxUint256 = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
}

// MARK: - Data Hex Extensions

extension Data {
    init?(hexString: String) {
        let hex = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
        guard hex.count % 2 == 0 else { return nil }
        
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
    
    var hexString: String {
        "0x" + map { String(format: "%02x", $0) }.joined()
    }
}
