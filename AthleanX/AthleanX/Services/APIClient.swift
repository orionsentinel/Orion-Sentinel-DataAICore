import Foundation
import Combine

final class APIClient {
    static let shared = APIClient()
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.API.timeoutInterval
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let request = try buildRequest(for: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder.athlean.decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 422:
            let errorResponse = try? JSONDecoder.athlean.decode(ValidationError.self, from: data)
            throw APIError.validationError(errorResponse?.message ?? "Validation failed")
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.httpError(httpResponse.statusCode)
        }
    }

    func requestVoid(_ endpoint: Endpoint) async throws {
        let request = try buildRequest(for: endpoint)
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }

    private func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        guard let url = URL(string: Constants.API.baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AthleanX-iOS/1.0", forHTTPHeaderField: "User-Agent")

        if let token = try? KeychainManager.shared.retrieve(for: Constants.Keychain.accessTokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = endpoint.body {
            request.httpBody = try JSONEncoder.athlean.encode(body)
        }
        if let queryItems = endpoint.queryItems {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            request.url = components?.url
        }
        return request
    }
}

struct Endpoint {
    let path: String
    let method: HTTPMethod
    var body: (any Encodable)?
    var queryItems: [URLQueryItem]?

    enum HTTPMethod: String {
        case get = "GET", post = "POST", put = "PUT", delete = "DELETE", patch = "PATCH"
    }

    static func get(_ path: String, queryItems: [URLQueryItem]? = nil) -> Endpoint {
        Endpoint(path: path, method: .get, queryItems: queryItems)
    }
    static func post(_ path: String, body: any Encodable) -> Endpoint {
        Endpoint(path: path, method: .post, body: body)
    }
    static func put(_ path: String, body: any Encodable) -> Endpoint {
        Endpoint(path: path, method: .put, body: body)
    }
    static func delete(_ path: String) -> Endpoint {
        Endpoint(path: path, method: .delete)
    }
}

enum APIError: LocalizedError {
    case invalidURL, invalidResponse, unauthorized, forbidden
    case notFound, serverError(Int), httpError(Int)
    case validationError(String), decodingError(Error)
    case noInternetConnection, timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .unauthorized: return "Session expired. Please log in again."
        case .forbidden: return "You don't have access to this content."
        case .notFound: return "Content not found."
        case .serverError(let code): return "Server error (\(code)). Please try again."
        case .httpError(let code): return "HTTP error (\(code))."
        case .validationError(let msg): return msg
        case .decodingError: return "Failed to parse server data."
        case .noInternetConnection: return "No internet connection."
        case .timeout: return "Request timed out. Please try again."
        }
    }
}

struct ValidationError: Decodable {
    let message: String
}

extension JSONDecoder {
    static let athlean: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    static let athlean: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
