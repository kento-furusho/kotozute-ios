import Foundation

/// サインイン後に保持しておく資格情報。
public struct AuthTokens: Sendable, Equatable, Codable {
    /// API Gateway の Cognito Authorizer に渡す JWT。
    public var idToken: String
    /// IdToken が切れたときの再取得に使う。こちらは長寿命（既定30日）。
    public var refreshToken: String
    /// IdToken の失効時刻。JWT の exp から取り出す。
    public var expiresAt: Date

    public init(idToken: String, refreshToken: String, expiresAt: Date) {
        self.idToken = idToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}

/// トークンの置き場所。テストで差し替えられるように protocol にしている。
public protocol TokenStore: Sendable {
    func load() throws -> AuthTokens?
    func save(_ tokens: AuthTokens) throws
    func clear() throws
}

/// Keychain に保存する実装。
///
/// UserDefaults ではなく Keychain を使うのは、リフレッシュトークンが
/// 「持っていれば本人になりすませる」性質の値だから。バックアップや
/// ファイル閲覧から平文で読めてはいけない。
public struct KeychainTokenStore: TokenStore {
    private let service: String
    private let account: String

    public init(service: String = "dev.kotozute.app", account: String = "auth-tokens") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func load() throws -> AuthTokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw AuthError.keychain(status: status)
        }
        return try JSONDecoder().decode(AuthTokens.self, from: data)
    }

    public func save(_ tokens: AuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)

        // 既存があれば更新、無ければ追加。add は重複時に errSecDuplicateItem を返すため。
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw AuthError.keychain(status: updateStatus)
        }

        var query = baseQuery
        query[kSecValueData as String] = data
        // 端末がロック解除された後だけ読めれば十分。バックアップで他端末に持ち出させない。
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw AuthError.keychain(status: addStatus)
        }
    }

    public func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthError.keychain(status: status)
        }
    }
}

/// テストや動作確認用のメモリ保存。
public final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: AuthTokens?

    public init(tokens: AuthTokens? = nil) {
        self.tokens = tokens
    }

    public func load() throws -> AuthTokens? { lock.withLock { tokens } }
    public func save(_ tokens: AuthTokens) throws { lock.withLock { self.tokens = tokens } }
    public func clear() throws { lock.withLock { tokens = nil } }
}
