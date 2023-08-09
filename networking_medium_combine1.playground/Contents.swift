import Combine
import Foundation

// https://udaypatial.medium.com/writing-a-generic-reusable-networking-layer-using-combine-swift-ios-fe8e16404a13

public struct NetworkRequest {
    let url: String
    let headers: [String: String]?
    let body: Data?
    let requestTimeOut: Float?
    let httpMethod: HTTPMethod
    
    public init(url: String,
                headers: [String: String]? = nil,
                reqBody: Encodable? = nil,
                reqTimeout: Float? = nil,
                httpMethod: HTTPMethod
    ) {
        self.url = url
        self.headers = headers
        self.body = reqBody?.encode()
        self.requestTimeOut = reqTimeout
        self.httpMethod = httpMethod
    }
    
    public init(url: String,
                headers: [String: String]? = nil,
                reqBody: Data? = nil,
                reqTimeout: Float? = nil,
                httpMethod: HTTPMethod
    ) {
        self.url = url
        self.headers = headers
        self.body = reqBody
        self.requestTimeOut = reqTimeout
        self.httpMethod = httpMethod
    }
    
    func buildURLRequest(with url: URL) -> URLRequest {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = httpMethod.rawValue
        urlRequest.allHTTPHeaderFields = headers ?? [:]
        urlRequest.httpBody = body
        return urlRequest
    }
}

public enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
}

public enum NetworkError: Error, Equatable {
    case badURL(_ error: String)
    case apiError(code: Int, error: String)
    case invalidJSON(_ error: String)
    case unauthorized(code: Int, error: String)
    case badRequest(code: Int, error: String)
    case serverError(code: Int, error: String)
    case noResponse(_ error: String)
    case unableToParseData(_ error: String)
    case unknown(code: Int, error: String)
}

extension Encodable {
    func encode() -> Data? {
        do {
            return try JSONEncoder().encode(self)
        } catch {
            return nil
        }
    }
}
protocol Requestable {
    var requestTimeOut: Float{ get }
    func request<T: Codable>(_ req: NetworkRequest) -> AnyPublisher<T, NetworkError>

}


public class NativeRequestable: Requestable {
    public var requestTimeOut: Float = 30

    public func request<T>(_ req: NetworkRequest) -> AnyPublisher<T, NetworkError>
     where T: Decodable, T: Encodable {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = TimeInterval(req.requestTimeOut ?? requestTimeOut)
        
        guard let url = URL(string: req.url) else {
            // Return a fail publisher if the url is invalid
            return AnyPublisher(
                Fail<T, NetworkError>(error: NetworkError.badURL("Invalid Url"))
            )
        }
        // We use the dataTaskPublisher from the URLSession which gives us a publisher to play around with.
        return URLSession.shared
            .dataTaskPublisher(for: req.buildURLRequest(with: url))
            .tryMap { output in
                     // throw an error if response is nil
                guard output.response is HTTPURLResponse else {
                    throw NetworkError.serverError(code: 0, error: "Server error")
                }
                return output.data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                       // return error if json decoding fails
                NetworkError.invalidJSON(String(describing: error))
            }
            .eraseToAnyPublisher()
    }
}


public typealias Headers = [String: String]

// if you wish you can have multiple services like this in a project
enum PurchaseServiceEndpoints {
    
  // organise all the end points here for clarity
    case purchaseProduct(request: PurchaseRequest)
    case getProduct(productId: String)
    case cancelOrder(orderId: String)
    
  // gave a default timeout but can be different for each.
    var requestTimeOut: Int {
        return 20
    }
    
  //specify the type of HTTP request
    var httpMethod: HTTPMethod {
        switch self {
        case .purchaseProduct,
             .cancelOrder:
            return .POST
        case .getProduct:
            return .GET
        }
    }
    
  // compose the NetworkRequest
    func createRequest(token: String, environment: Environment) -> NetworkRequest {
        var headers: Headers = [:]
        headers["Content-Type"] = "application/json"
        headers["Authorization"] = "Bearer \(token)"
        return NetworkRequest(url: getURL(from: environment), headers: headers, reqBody: requestBody, httpMethod: httpMethod)
    }
    
  // encodable request body for POST
    var requestBody: Encodable? {
        switch self {
        case .purchaseProduct(let request):
            return request
        default:
            return nil
        }
    }
    
  // compose urls for each request
    func getURL(from environment: Environment) -> String {
        let baseUrl = environment.purchaseServiceBaseUrl
        switch self {
        case .purchaseProduct:
            return "\(baseUrl)/purchase"
        case .getProduct(let productId):
            return "\(baseUrl)/products/\(productId)"
        case .cancelOrder(let orderId):
            return "\(baseUrl)/products/\(orderId)/cancel"
        }
    }
}

public enum Environment: String, CaseIterable {
    case development
    case staging
    case production
}

extension Environment {
    var purchaseServiceBaseUrl: String {
        switch self {
        case .development:
            return "https://dev-combine.com/purchaseService"
        case .staging:
            return "https://stg-combine.com/purchaseService"
        case .production:
            return "https://combine.com/purchaseService"
        }
    }
}



protocol PurchaseServiceable {
    func purchaseProduct(request: PurchaseRequest) -> AnyPublisher<PurchaseResponse, NetworkError>
    func getProduct(productId: Int) -> AnyPublisher<Product, NetworkError>
  //Instead of using Void I use NoReply for requests that might give 200 with empty response
    func cancelOrder(_ orderId: Int) -> AnyPublisher<NoReply, NetworkError>
}

class PurchaseService: PurchaseServiceable {
    
    private var networkRequest: Requestable
    private var environment: Environment = .development
    
  // inject this for testability
    init(networkRequest: Requestable, environment: Environment) {
        self.networkRequest = networkRequest
        self.environment = environment
    }

    func purchaseProduct(request: PurchaseRequest) -> AnyPublisher<PurchaseResponse, NetworkError> {
        let endpoint = PurchaseServiceEndpoints.purchaseProduct(request: request)
        let request = endpoint.createRequest(token: token,
                                             environment: self.environment)
        return self.networkRequest.request(request)
    }
  
}

public struct PurchaseRequest: Encodable {
    public let products: [String]
    public let cost: Int
}

public struct PurchaseResponse: Codable {
    public let id: Int
    public let productName: String
}

var subscriptions = Set<AnyCancellable>()
let purchaseRequest = PurchaseRequest(products: ["chicken", "orange juice"], cost: 20)
let service = PurchaseService(networkRequest: NativeRequestable(), environment: .development)
service.purchaseProduct(request: purchaseRequest)
            .sink { (completion) in
                switch completion {
                case .failure(let error):
                    print("oops got an error \(error.localizedDescription)")
                case .finished:
                    print("nothing much to do here")
                }
            } receiveValue: { (response) in
                print("got my response here \(response)")
            }
            .store(in: &subscriptions)

