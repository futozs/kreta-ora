import Foundation

public struct HTTPResponse: Sendable {
    public let status: Int
    public let body: Data

    public init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }
}

/// The only seam to the network, so everything above it is testable offline.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

/// Production transport: no cookies, no cache, bounded timeouts, and no
/// redirect following, so a redirect can never forward a bearer token.
public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 40
        configuration.waitsForConnectivity = false
        configuration.httpAdditionalHeaders = ["User-Agent": KretaConfig.userAgent]
        session = URLSession(configuration: configuration)
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request, delegate: RedirectBlocker())
        guard let http = response as? HTTPURLResponse else { throw KretaError.badResponse }
        return HTTPResponse(status: http.statusCode, body: data)
    }
}

private final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
