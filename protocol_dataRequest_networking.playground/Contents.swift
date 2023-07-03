import UIKit

enum HTTPMethod: String{
    case get = "GET"
    case post = "Post"
}

protocol DataRequest {
    associatedtype Response
    var url: URL {get}
    var headers: [String: String]{get}
    var queryItems: [String: String] { get}
    
    func decode(_ data: Data) throws -> Response
}

extension DataRequest where Response: Decodable{
    func decode(_ data: Data) throws -> Response {
        let decoder = JSONDecoder()
        return try decoder.decode(Response.self, from: data)
    }

}

extension DataRequest {
    var headers: [String: String]{
        [:]
    }
    var queryItems: [String: String] {
        [:]
    }
}

protocol NetworkService {
    func request<Request: DataRequest>(_request: Request, completion: (Result<Request.Response, Error>) -> Void)
}

final class DefaultNetworkService: NetworkService{
    func request<Request>(_request: Request, completion: (Result<Request.Response, Error>) -> Void) where Request : DataRequest {
        <#code#>
    }
}
