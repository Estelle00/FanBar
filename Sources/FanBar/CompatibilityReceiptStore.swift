import Foundation
import Security

@MainActor
protocol CompatibilityReceiptStoring {
    func save(_ receipt: CompatibilitySavedReceipt) throws
    func receipts() throws -> [CompatibilitySavedReceipt]
    func remove(reportID: String) throws
}

/// Credentials are local, non-synchronizing Keychain items, never report exports or UserDefaults.
@MainActor
struct CompatibilityReceiptStore: CompatibilityReceiptStoring {
    private let service: String

    init(service: String = "local.fanbar.compatibility.receipts") {
        self.service = service
    }

    func save(_ receipt: CompatibilitySavedReceipt) throws {
        let data = try JSONEncoder().encode(receipt)
        let query = identity(receipt.reportID)
        let result = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if result == errSecItemNotFound {
            var item = query
            item[kSecValueData] = data
            item[kSecAttrSynchronizable] = false
            item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw CompatibilityServiceError.credentialStorage }
        } else if result != errSecSuccess { throw CompatibilityServiceError.credentialStorage }
    }

    func receipts() throws -> [CompatibilitySavedReceipt] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword, kSecAttrService: service,
            kSecReturnData: true, kSecMatchLimit: kSecMatchLimitAll,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let items = result as? [Data] else { throw CompatibilityServiceError.credentialStorage }
        return try items.map { try JSONDecoder().decode(CompatibilitySavedReceipt.self, from: $0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func remove(reportID: String) throws {
        let status = SecItemDelete(identity(reportID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CompatibilityServiceError.credentialStorage }
    }

    private func identity(_ reportID: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: reportID.lowercased()]
    }
}
