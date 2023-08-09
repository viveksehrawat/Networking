import UIKit
import Foundation
import UIKit

enum HTTPMethod: String {
case get = "GET"
case post = "POST"
}

enum NetworkError: Error {
case requestFailed
case invalidResponse
case decodingFailed
case encodingFailed
    
}

class NetworkManager {
    
    static let shared = NetworkManager()
    private init() {}
    
    func fetchData<T: Decodable>(url: URL, completion: @escaping (Result<T, NetworkError>) -> Void )  {
        
        let task = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
            
            if let _ = error {
                completion(.failure(.requestFailed))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.requestFailed))
                return
            }
            
            guard let responseData = data else {
                completion(.failure(.requestFailed))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(T.self, from: responseData)
                completion(.success(decodedData))
            } catch {
                completion(.failure(.invalidResponse))
            }
        })
        task.resume()
    }
    
    func postData<T: Decodable, U: Encodable>(url: URL, body: U, completion: @escaping (Result<T, NetworkError>) -> Void) {
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            let requestBody = try encoder.encode(body)
            request.httpBody = requestBody
        } catch {
            completion(.failure(.encodingFailed))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(T.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(.decodingFailed))
            }
        }.resume()
    }
}



struct Post: Codable {
    let id: Int
    let title: String
    let body: String
}

NetworkManager.shared.fetchData(url: URL(string: "https://jsonplaceholder.typicode.com/posts/1")!) {
    (result: Result<Post, NetworkError>) in
    
    switch result {
    case .success(let post):
        print("success")
    case .failure(let error):
        print("error")
        
    }
}


struct PostRequest: Encodable {
    let userId: Int
    let title: String
    let body: String
}
let postRequest = PostRequest(userId: 1, title: "New Post", body: "This is the content of the new post.")



NetworkManager.shared.postData(url: URL(string: "https://jsonplaceholder.typicode.com/posts")!, body: postRequest) { (result: Result<Post, NetworkError>) in
    switch result {
    case .success(let post):
        print("Created Post Title:", post.title)
    case .failure(let error):
        print("Error:", error)
    }
}
