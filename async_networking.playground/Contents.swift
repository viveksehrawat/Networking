import Foundation

// https://www.youtube.com/watch?v=URtjMI3Y1Dw&t=16s

enum NetworkError: Error {
    case invalidResponse
    case badUrl
    case decodingError
}

struct Product: Codable {
    var id: Int?
    let title: String
    let price: Double
    let description: String
    let image: String
    let category: String
}

extension URL {
    
    static func forProductId(_ id: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "fakestoreapi.com"
        components.path = "/products/\(id)"
        return components.url
    }
    
    static var forAllProducts: URL {
        URL(string: "https://fakestoreapi.com/products")!
    }
}

extension Product {
    
    static func byId(_ id: Int) -> Resource<Product> {
        guard let url = URL.forProductId(id) else {
            fatalError("id = \(id) was not found.")
        }
        return Resource(url: url)
    }
    
    static var all: Resource<[Product]> {
        return Resource(url: URL.forAllProducts)
    }
}

enum HttpMethod {
    case get([URLQueryItem])
    case post(Data?)
    
    var name: String {
        switch self {
            case .get:
                return "GET"
            case .post:
                return "POST"
        }
    }
}

struct Resource<T: Codable> {
    
    let url: URL
    var method: HttpMethod = .get([])
}

class Webservice {
    
    func load<T: Codable>(_ resource: Resource<T>) async throws -> T {
        
        var request = URLRequest(url: resource.url)
        
        switch resource.method {
            case .post(let data):
                request.httpMethod = resource.method.name
                request.httpBody = data
            case .get(let queryItems): // https://someurl.com/products?sort=asc&pageSize=10
                var components = URLComponents(url: resource.url, resolvingAgainstBaseURL: false)
                components?.queryItems = queryItems
                guard let url = components?.url else {
                    throw NetworkError.badUrl
                }
                request = URLRequest(url: url)
        }
        
        // create the URLSession configuration
        let configuration = URLSessionConfiguration.default
        // add default headers
        configuration.httpAdditionalHeaders = ["Content-Type": "application/json"]
        let session = URLSession(configuration: configuration)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw NetworkError.invalidResponse
        }
        
        guard let result = try? JSONDecoder().decode(T.self, from: data) else {
            throw NetworkError.decodingError
        }
        
        return result
        
    }
    
}

Task {
    // get all products
    let products = try await Webservice().load(Product.all)
    //print(products)
}

Task {
    let product = try await Webservice().load(Product.byId(1))
    print(product)
}
