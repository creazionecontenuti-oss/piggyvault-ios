import Foundation

enum BaseNetwork {
    static let chainId: Int = 8453
    static let rpcURL = URL(string: "https://mainnet.base.org")!
    static let explorerURL = URL(string: "https://basescan.org")!
    static let chainName = "Base"
    static let nativeCurrency = "ETH"
    
    enum Contract {
        static let usdc = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
        static let eurc = "0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42"
        
        static let safeProxyFactory = "0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2"
        static let safeSingleton = "0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552"
        static let safeFallbackHandler = "0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4"
        static let multiSend = "0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761"
        
        // PiggyVault contracts (deployed on Base mainnet)
        static let piggyModuleFactory = "0xC78ad038E7E9E72580E98507cdF5De83B50A63aB"
        static let piggyVaultGuard = "0xd8054e13935D14D2EAc7D1Dc19E9bF316984CBeF"
    }
    
    static let erc20ABI = """
    [
        {"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"},
        {"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"},
        {"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"},
        {"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"type":"function"},
        {"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_value","type":"uint256"}],"name":"approve","outputs":[{"name":"","type":"bool"}],"type":"function"},
        {"constant":true,"inputs":[{"name":"_owner","type":"address"},{"name":"_spender","type":"address"}],"name":"allowance","outputs":[{"name":"","type":"uint256"}],"type":"function"}
    ]
    """
}
