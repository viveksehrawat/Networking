import Foundation
import Combine
import SwiftUI
// https://github.com/jamesrochabrun/SwiftUIMoviesApp
// https://medium.com/if-let-swift-programming/generic-networking-layer-using-combine-in-swift-ui-d23574c20368


protocol CombineAPI {
    var session: URLSession { get }
    func execute<T>(_ request: URLRequest, decodingType: T.Type, queue: DispatchQueue, retries: Int) -> AnyPublisher<T, Error> where T: Decodable

}

extension CombineAPI {
    
    func execute<T>(_ request: URLRequest,
                    decodingType: T.Type,
                    queue: DispatchQueue = .main,
                    retries: Int = 0) -> AnyPublisher<T, Error> where T: Decodable {
        /// 3
        return session.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse, response.statusCode == 200 else {
                    throw APIError.responseUnsuccessful
                }
                return output.data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: queue)
            .retry(retries)
            .eraseToAnyPublisher()
    }
}

final class MovieClient: CombineAPI {
    
    // 1
    let session: URLSession
    
    // 2
    init(configuration: URLSessionConfiguration) {
        self.session = URLSession(configuration: configuration)
    }
    
    convenience init() {
        self.init(configuration: .default)
    }
    
    // 3
    func getFeed(_ feedKind: MovieFeed) -> AnyPublisher<MovieFeedResult, Error> {
        // 4
        execute(feedKind.request, decodingType: MovieFeedResult.self, retries: 2)
    }
}


final class MoviesProvider: ObservableObject {
    
    // MARK:- Subscribers
  // 2
    private var cancellable: AnyCancellable?
    
    // MARK:- Publishers
  // 3
    @Published var movies: [MovieViewModel] = []

    // MARK:- Private properties
  // 4
    private let client = MovieClient()
    
    init() {
      // 5
        cancellable = client.getFeed(.nowPlaying)
            .sink(receiveCompletion: { _ in },
            receiveValue: {
                self.movies = $0.results.map { MovieViewModel(movie: $0) }
            })
    }
}

@main
struct SwiftUIMoviesApp: App {
    // 2
    @StateObject private var model = MoviesProvider()

    // 3
    var body: some Scene {
        WindowGroup {
            // 4
            NavigationView {
                // 5
                List(model.movies, id: \.id) { movie in
                        // 6
                    MovieRow(movie: movie)
                }
            }
        }
    }
}




