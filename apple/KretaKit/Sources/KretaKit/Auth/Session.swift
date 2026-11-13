import Foundation

public struct Account: Codable, Hashable, Sendable, Identifiable {
    /// Stable local identifier derived from institution and user.
    public let id: String
    public let institutionCode: String
    public let userName: String
    public let displayName: String

    public init(id: String, institutionCode: String, userName: String, displayName: String) {
        self.id = id
        self.institutionCode = institutionCode
        self.userName = userName
        self.displayName = displayName
    }
}

public struct TokenSet: Codable, Hashable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date

    public init(accessToken: String, refreshToken: String, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    public func isFresh(at now: Date) -> Bool {
        expiresAt.timeIntervalSince(now) > KretaConfig.tokenLeeway
    }
}

public struct Session: Codable, Hashable, Sendable {
    public let account: Account
    public let tokens: TokenSet

    public init(account: Account, tokens: TokenSet) {
        self.account = account
        self.tokens = tokens
    }
}

/// Where the signed-in session lives. Production uses the keychain.
public protocol SessionStore: Sendable {
    func load() throws -> Session?
    func save(_ session: Session) throws
    func clear() throws
}

/// Keeps the session in memory only. Used by tests and previews.
public final class InMemorySessionStore: SessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var session: Session?

    public init(_ session: Session? = nil) {
        self.session = session
    }

    public func load() -> Session? {
        lock.withLock { session }
    }

    public func save(_ session: Session) {
        lock.withLock { self.session = session }
    }

    public func clear() {
        lock.withLock { session = nil }
    }
}
