import CryptoKit
import Foundation

enum Encoding {
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func base64URLDecode(_ text: String) -> Data? {
        var padded = text
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded.append("=") }
        return Data(base64Encoded: padded)
    }

    /// 256 bits from the system CSPRNG, URL-safe.
    static func randomToken() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return base64URL(Data(bytes))
    }

    static func sha256(_ text: String) -> Data {
        Data(SHA256.hash(data: Data(text.utf8)))
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    /// Percent-encodes everything except RFC 3986 unreserved characters, so the
    /// result is safe both as a query value and as a form body value.
    static func percentEncode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    static func formEncode(_ pairs: [(String, String)]) -> String {
        pairs
            .map { "\(percentEncode($0.0))=\(percentEncode($0.1))" }
            .joined(separator: "&")
    }
}
