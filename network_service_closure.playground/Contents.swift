import UIKit

//https://www.youtube.com/watch?v=BP2wv7OjZnA
struct Post: Codable {
    let userId: Int
    let id: Int
    let title: String
    let body: String
}

enum HTTP {
    enum Method: String {
        case get = "GET"
        case post = "POST"
    }
    
    enum Headers {
        enum Key: String {
            case contentType = "Content-Type"
        }
        
        enum Value: String {
            case applicationJson = "application/json"
        }
    }
}


enum Endpoint {
    
    case fetchPosts(url: String = "/posts")
    case fetchOnePost(url: String = "/posts", postId: Int = 1)
    case sendPost(url: String = "/posts", post: Post)
    
    var request: URLRequest? {
        guard let url = self.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = self.httpMethod
        request.httpBody = self.httpBody
        request.addValues(for: self)
        return request
    }
    
    private var url: URL? {
        var components = URLComponents()
        components.scheme = ""
        components.host = ""
        components.port = 0
        components.path = self.path
        components.queryItems = self.queryItems
        return components.url
    }
    
    private var path: String {
        switch self {
        case .fetchPosts(let url): return url
        case .fetchOnePost(let url, let postId): return "\(url)/\(postId.description)"
        case .sendPost(let url, _): return url
        }
    }
    
    
    private var queryItems: [URLQueryItem] {
        switch self {
            default: return []
        }
    }
    
    
    private var httpMethod: String {
        switch self {
        case .fetchPosts,
             .fetchOnePost:
            return HTTP.Method.get.rawValue
        case .sendPost:
            return HTTP.Method.post.rawValue
        }
    }
    
    private var httpBody: Data? {
        switch self {
        case .fetchPosts,
             .fetchOnePost:
            return nil
        case .sendPost(_, let post):
            let jsonPost = try? JSONEncoder().encode(post)
            return jsonPost
        }
    }
}

extension URLRequest {
    
    mutating func addValues(for endpoint: Endpoint) {
        switch endpoint {
        case .fetchPosts,
             .fetchOnePost:
            break
        case .sendPost:
            self.setValue(
                HTTP.Headers.Value.applicationJson.rawValue,
                forHTTPHeaderField: HTTP.Headers.Key.contentType.rawValue
            )
        }
    }
}
enum APIError: Error, CustomStringConvertible {
    case requestTimedOut
    case requestFailed
    case invalidResponse
    case requestCanceled
    case decodingFailed
    case invalidBodyExpectedResponse
    case invalidBodyExpectedData
    case invalidBodyExpectedJSON
    
    var description: String {
        switch self {
        case .requestTimedOut:
            return "Request Timed Out"
        case .requestFailed:
            return "Request Failed"
        case .invalidResponse:
            return "Invalid Response"
        case .requestCanceled:
            return "Request Canceled"
        case .decodingFailed:
            return "Decoding Failed"
        case .invalidBodyExpectedResponse:
            return "Expected response, but didn't get one!"
        case .invalidBodyExpectedData:
            return "Expected DATA in message body"
        case .invalidBodyExpectedJSON:
            return "Expected JSON as message body"
        }
    }
}


protocol Service {
    
    func performJsonRequest<T: Codable>(with request: URLRequest, completion: @escaping (Result<T, APIError>)-> Void)
}

class NetworkService: Service {
    func performJsonRequest<T>(with request: URLRequest, completion: @escaping (Result<T, APIError>) -> Void) where T : Decodable, T : Encodable {
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, let httpResponse = response as? HTTPURLResponse, error == nil else {
                completion(.failure(.requestFailed))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                completion(.failure(.invalidResponse))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let decodedResponse = try decoder.decode(T.self, from: data)
                completion(.success(decodedResponse))
            } catch {
                completion(.failure(.decodingFailed))
            }
        }.resume()
    }
}
