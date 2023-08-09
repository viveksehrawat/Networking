import Foundation
import Combine

enum NetworkError: Error {
    case invalidURL
    case requestFailed
    case decodingFailed
}

protocol Networking {
    func fetchData<T: Decodable>(from url: URL) -> AnyPublisher<T, Error>
}

class NetworkManager: Networking {
    private var cancellables = Set<AnyCancellable>()
    
    func fetchData<T: Decodable>(from url: URL) -> AnyPublisher<T, Error> {
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

class NetworkManagerTwo: Networking {
     var cancellables = Set<AnyCancellable>()

    func fetchData<T: Decodable>(from url: URL) -> AnyPublisher<T, Error> {
        guard let requestURL = URL(string: url.absoluteString) else {
            return Fail<T, Error>(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: requestURL)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw NetworkError.requestFailed
                }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                NetworkError.decodingFailed
            }
            .eraseToAnyPublisher()
    }
}


struct User: Codable {
    let name: String
    let email: String
}

let networking: Networking = NetworkManagerTwo()
let url = URL(string: "https://api.example.com/user")!

networking.fetchData(from: url)
    .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
            print("Data fetching completed.")
        case .failure(let error):
            switch error {
            case NetworkError.invalidURL:
                print("Invalid URL error")
            case NetworkError.requestFailed:
                print("Request failed error")
            case NetworkError.decodingFailed:
                print("Decoding failed error")
            default:
                print("Unknown error: \(error)")
            }
        }
    }, receiveValue: { (user: User) in
        // Handle the received user data
        print("Received user data: \(user)")
    })
    .store(in: &networking.cancellables) // Store in networking.cancellables
