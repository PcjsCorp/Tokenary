// ∅ 2026 lil org

import Foundation

struct EthereumAccessListEntry: Equatable, Sendable {
    let address: Data
    let storageKeys: [Data]

    init?(address: Data, storageKeys: [Data]) {
        guard address.count == 20,
              storageKeys.allSatisfy({ $0.count == 32 }) else { return nil }
        self.address = address
        self.storageKeys = storageKeys
    }

    init?(address: String, storageKeys: [String]) {
        guard let address = Self.data(fromStrictHex: address, byteCount: 20) else {
            return nil
        }
        let decodedStorageKeys = storageKeys.compactMap {
            Self.data(fromStrictHex: $0, byteCount: 32)
        }
        guard decodedStorageKeys.count == storageKeys.count else { return nil }
        self.init(address: address, storageKeys: decodedStorageKeys)
    }

    var addressHexString: String {
        String.hexPrefix + WalletCrypto.hexString(address)
    }

    var storageKeyHexStrings: [String] {
        storageKeys.map { String.hexPrefix + WalletCrypto.hexString($0) }
    }

    private static func data(fromStrictHex value: String, byteCount: Int) -> Data? {
        guard value.hasPrefix("0x") else { return nil }
        let cleanValue = String(value.dropFirst(2))
        guard cleanValue.count == byteCount * 2,
              let data = WalletCrypto.hexData(cleanValue),
              data.count == byteCount else { return nil }
        return data
    }
}
