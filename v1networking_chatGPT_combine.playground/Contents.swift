import Foundation
import Combine

// version 1
class NetworkManager{
     var cancellables = Set<AnyCancellable>()

    
    func fetchData(from url: URL) -> AnyPublisher<Data, Error>{
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap {
                data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

let networkManager = NetworkManager()
let url = URL(string: "https://reqres.in/api/users?page=2")!

let subscriber = networkManager.fetchData(from: url)

subscriber.sink(receiveCompletion: {
    completion in
    switch completion {
    case .finished:
        print("Data fetching completed.")
    case .failure(let error):
        print("Data fetching failed with error: \(error)")
    }
}, receiveValue: {
    data in
    print("Recieved data \(data.debugDescription)")
})
.store(in: &networkManager.cancellables)




