import Foundation

struct HTTPHeaders: Sendable {
    private(set) var storage: [String: String]

    init(_ headers: [String: String] = [:]) {
        self.storage = headers
    }

    subscript(name: String) -> String? {
        get { storage[name] }
        set { storage[name] = newValue }
    }

    var asDictionary: [String: String] { storage }
}

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

struct HTTPRequest<Body: Encodable & Sendable>: Sendable {
    let method: HTTPMethod
    let path: String
    let body: Body?
    let headers: HTTPHeaders

    init(method: HTTPMethod, path: String, body: Body? = nil, headers: HTTPHeaders = HTTPHeaders()) {
        self.method = method
        self.path = path
        self.body = body
        self.headers = headers
    }
}

final class GateAIHTTPClient: @unchecked Sendable {
    private let session: URLSession
    private let configuration: GateAIConfiguration
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(configuration: GateAIConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func send<RequestBody: Encodable, ResponseBody: Decodable>(
        _ request: HTTPRequest<RequestBody>,
        expecting type: ResponseBody.Type
    ) async throws -> ResponseBody {
        let url = configuration.baseURL.appendingPathComponent(request.path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in request.headers.asDictionary {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let body = request.body {
            do {
                urlRequest.httpBody = try encoder.encode(body)
            } catch {
                throw GateAIError.configuration("Failed to encode request body for \(request.path): \(error.localizedDescription)")
            }
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GateAIError.invalidResponse
            }

            let headerFields = httpResponse.allHeaderFields.reduce(into: [String: String]()) { partialResult, header in
                if let key = header.key as? String, let value = header.value as? String {
                    partialResult[key] = value
                }
            }

            switch httpResponse.statusCode {
            case 200..<300:
                do {
                    return try decoder.decode(ResponseBody.self, from: data)
                } catch {
                    throw GateAIError.decoding(underlying: error)
                }
            default:
                let serverError = try? decoder.decode(ServerErrorResponse.self, from: data)
                throw GateAIError.server(statusCode: httpResponse.statusCode, error: serverError, headers: headerFields)
            }
        } catch let error as GateAIError {
            throw error
        } catch {
            throw GateAIError.network(underlying: error)
        }
    }
}
