import Foundation

/// The KRÉTA endpoints the timetable app needs: the token endpoint and the
/// student's own timetable.
public struct KretaAPI: Sendable {
    private let transport: any HTTPTransport
    private let identityProvider: URL
    private let schoolBase: @Sendable (String) -> String

    public init(
        transport: any HTTPTransport = URLSessionTransport(),
        identityProvider: URL = KretaConfig.identityProvider,
        schoolBase: @escaping @Sendable (String) -> String = { "https://\($0).e-kreta.hu" }
    ) {
        self.transport = transport
        self.identityProvider = identityProvider
        self.schoolBase = schoolBase
    }

    func exchangeCode(_ code: String, verifier: String) async throws -> TokenResponse {
        try await token([
            ("code", code),
            ("code_verifier", verifier),
            ("redirect_uri", KretaConfig.redirectURI),
            ("client_id", KretaConfig.clientID),
            ("grant_type", "authorization_code"),
        ])
    }

    func refreshToken(_ refreshToken: String, institution: String) async throws -> TokenResponse {
        try await token([
            ("institute_code", institution),
            ("refresh_token", refreshToken),
            ("grant_type", "refresh_token"),
            ("client_id", KretaConfig.clientID),
        ])
    }

    /// Lessons between two days, both inclusive. KRÉTA accepts at most 42 days.
    public func timetable(
        institution: String,
        accessToken: String,
        from: Date,
        to: Date
    ) async throws -> [Lesson] {
        let school = try InstitutionCode.validate(institution)
        let query = Encoding.formEncode([
            ("datumTol", KretaDate.dayString(from)),
            ("datumIg", KretaDate.dayString(to)),
        ])
        guard let url = URL(string: "\(schoolBase(school))/ellenorzo/v3/sajat/OrarendElemek?\(query)") else {
            throw KretaError.badResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(KretaConfig.apiKey, forHTTPHeaderField: "apiKey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(KretaConfig.userAgent, forHTTPHeaderField: "User-Agent")

        let response = try await transport.send(request)
        switch response.status {
        case 200..<300: break
        case 401: throw KretaError.authentication
        default: throw KretaError.http(response.status)
        }
        return try Lesson.decodeList(try bounded(response.body))
    }

    private func token(_ form: [(String, String)]) async throws -> TokenResponse {
        var request = URLRequest(url: identityProvider.appendingPathComponent("connect/token"))
        request.httpMethod = "POST"
        request.httpBody = Data(Encoding.formEncode(form).utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue(KretaConfig.userAgent, forHTTPHeaderField: "User-Agent")

        let response = try await transport.send(request)
        switch response.status {
        case 200..<300: break
        case 400, 401: throw KretaError.authentication
        default: throw KretaError.http(response.status)
        }
        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: try bounded(response.body)) else {
            throw KretaError.badResponse
        }
        return decoded
    }

    private func bounded(_ body: Data) throws -> Data {
        guard body.count <= KretaConfig.maxResponseBytes else { throw KretaError.badResponse }
        return body
    }
}
