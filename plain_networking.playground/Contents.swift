import UIKit
import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum NetworkError: Error{
    case invalidURL
    case requestFailed
    case invalidResponse
    case invalidData
}

class NetworkManager<T: Decodable>{
    
    func request(urlString: String, completion: @escaping (Result<T, NetworkError>)-> Void){
        guard let url = URL(string: urlString) else { completion(.failure(.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
            
            if let _ = error {
                completion(.failure(.requestFailed))
                
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.invalidResponse))
                return
            }
            guard let responseData = data else {
                completion(.failure(.invalidData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let decoderData = try decoder.decode(T.self, from: responseData)
                completion(.success(decoderData))
            } catch {
                completion(.failure(.invalidData))
            }
        })
        task.resume()
    }
}

struct Post: Decodable {
    let id: Int
    let title: String
    let body: String
}

let networkManager = NetworkManager<Post>()

networkManager.request(urlString: "https://jsonplaceholder.typicode.com/posts/1") { result in
    switch result {
    case .success(let post):
        print("Post ID: \(post.id)")
        print("Post Title: \(post.title)")
        print("Post Body: \(post.body)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
