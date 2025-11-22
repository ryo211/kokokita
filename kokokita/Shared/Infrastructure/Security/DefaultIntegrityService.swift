import Foundation
import CryptoKit
import Security

struct DefaultIntegrityService {
    // Keychain に保存するタグ
    private let keyTag = "jp.kokokita.signingkey.soft"

    func signImmutablePayload(
        id: UUID,
        timestampUTC: Date,
        lat: Double,
        lon: Double,
        acc: Double?,
        flags: LocationSourceFlags,
        createdAtUTC: Date = Date()  // 署名作成時刻（デバッグモードでカスタマイズ可能）
    ) throws -> Visit.Integrity {


        // 署名対象（不変部のみ）
        let payload = ImmutablePayload(
            id: id,
            timestampUTC: timestampUTC,
            lat: lat,
            lon: lon,
            acc: acc,
            sim: flags.isSimulatedBySoftware,
            accy: flags.isProducedByAccessory
        )
        let data = try JSONEncoder().encode(payload)
        let digest = Data(SHA256.hash(data: data))

        // キーをロード or 生成
        let (priv, pub) = try loadOrCreateSoftKey()

        // 署名（DERで保持）
        let sig = try priv.signature(for: digest)

        return .init(
            algo: "P256.Signing",
            signatureDERBase64: Data(sig.derRepresentation).base64EncodedString(),
            publicKeyRawBase64: pub.rawRepresentation.base64EncodedString(),
            payloadHashHex: digest.map { String(format: "%02x", $0) }.joined(),
            createdAtUTC: createdAtUTC
        )
    }

    func verify(visit: Visit) -> Bool {
        do {
            let payload = ImmutablePayload(
                id: visit.id,
                timestampUTC: visit.timestampUTC,
                lat: visit.latitude,
                lon: visit.longitude,
                acc: visit.horizontalAccuracy,
                sim: visit.isSimulatedBySoftware,
                accy: visit.isProducedByAccessory
            )
            let data = try JSONEncoder().encode(payload)
            let digest = Data(SHA256.hash(data: data))

            guard
                let sigDER = Data(base64Encoded: visit.integrity.signatureDERBase64),
                let pubRaw = Data(base64Encoded: visit.integrity.publicKeyRawBase64)
            else { return false }

            let pub = try P256.Signing.PublicKey(rawRepresentation: pubRaw)
            let sig = try P256.Signing.ECDSASignature(derRepresentation: sigDER)
            return pub.isValidSignature(sig, for: digest)
        } catch {
            return false
        }
    }

    // MARK: - Soft Key 管理（Keychain保存）

    private func loadOrCreateSoftKey() throws -> (P256.Signing.PrivateKey, P256.Signing.PublicKey) {
        if let k = try loadSoftKey() {
            return (k, k.publicKey)
        }
        let new = P256.Signing.PrivateKey()
        try storeSoftKey(new)
        return (new, new.publicKey)
    }

    private func storeSoftKey(_ key: P256.Signing.PrivateKey) throws {
        let tag = keyTag.data(using: .utf8)!
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: key.rawRepresentation
        ]
        SecItemDelete(attrs as CFDictionary)
        let st = SecItemAdd(attrs as CFDictionary, nil)
        guard st == errSecSuccess else {
            throw NSError(domain: "Keychain", code: Int(st), userInfo: [NSLocalizedDescriptionKey: "Failed to store key: \(st)"])
        }
    }

    private func loadSoftKey() throws -> P256.Signing.PrivateKey? {
        let tag = keyTag.data(using: .utf8)!
        let q: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        let st = SecItemCopyMatching(q as CFDictionary, &item)
        if st == errSecSuccess, let data = item as? Data {
            return try? P256.Signing.PrivateKey(rawRepresentation: data)
        }
        return nil
    }

    // 署名対象構造体（不変部のみ）
    private struct ImmutablePayload: Codable {
        let id: UUID
        let timestampUTC: Date
        let lat: Double
        let lon: Double
        let acc: Double?
        let sim: Bool?
        let accy: Bool?
    }
}
