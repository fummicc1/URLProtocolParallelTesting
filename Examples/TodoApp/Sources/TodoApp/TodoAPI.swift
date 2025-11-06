import Foundation

/// Protocol abstraction for URLSession to enable test double injection
public protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

/// A simple Todo API client that demonstrates how to use URLSession for network requests.
/// This is production code that will be tested using URLProtocolParallelTesting.
public final class TodoAPI: Sendable {
    private let baseURL: String
    private let session: any URLSessionProtocol
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    /// Initialize the API client with a custom URLSession
    /// - Parameters:
    ///   - baseURL: The base URL for the API (e.g., "https://jsonplaceholder.typicode.com")
    ///   - session: The URLSession to use for requests (default: .shared)
    public init(baseURL: String, session: any URLSessionProtocol = URLSession.shared) {
        self.baseURL = baseURL
        self.session = session
        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = JSONEncoder()
    }

    // MARK: - Public API Methods

    /// Fetch all todos
    /// - Returns: Array of Todo items
    /// - Throws: TodoAPIError if the request fails
    public func fetchTodos() async throws -> [Todo] {
        guard let url = URL(string: "\(baseURL)/todos") else {
            throw TodoAPIError.invalidURL
        }

        let request = URLRequest(url: url)
        return try await performRequest(request, expecting: [Todo].self)
    }

    /// Fetch a specific todo by ID
    /// - Parameter id: The ID of the todo to fetch
    /// - Returns: The Todo item
    /// - Throws: TodoAPIError if the request fails
    public func fetchTodo(id: Int) async throws -> Todo {
        guard let url = URL(string: "\(baseURL)/todos/\(id)") else {
            throw TodoAPIError.invalidURL
        }

        let request = URLRequest(url: url)
        return try await performRequest(request, expecting: Todo.self)
    }

    /// Create a new todo
    /// - Parameter todo: The todo creation request
    /// - Returns: The created Todo item
    /// - Throws: TodoAPIError if the request fails
    public func createTodo(_ todo: CreateTodoRequest) async throws -> Todo {
        guard let url = URL(string: "\(baseURL)/todos") else {
            throw TodoAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try jsonEncoder.encode(todo)
        } catch {
            throw TodoAPIError.decodingError(error)
        }

        return try await performRequest(request, expecting: Todo.self)
    }

    /// Update an existing todo
    /// - Parameters:
    ///   - id: The ID of the todo to update
    ///   - update: The update request with fields to change
    /// - Returns: The updated Todo item
    /// - Throws: TodoAPIError if the request fails
    public func updateTodo(id: Int, update: UpdateTodoRequest) async throws -> Todo {
        guard let url = URL(string: "\(baseURL)/todos/\(id)") else {
            throw TodoAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try jsonEncoder.encode(update)
        } catch {
            throw TodoAPIError.decodingError(error)
        }

        return try await performRequest(request, expecting: Todo.self)
    }

    /// Delete a todo
    /// - Parameter id: The ID of the todo to delete
    /// - Throws: TodoAPIError if the request fails
    public func deleteTodo(id: Int) async throws {
        guard let url = URL(string: "\(baseURL)/todos/\(id)") else {
            throw TodoAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await performNetworkRequest(request)
        try validateResponse(response)
    }

    // MARK: - Private Helper Methods

    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        expecting type: T.Type
    ) async throws -> T {
        let (data, response) = try await performNetworkRequest(request)
        try validateResponse(response)

        do {
            return try jsonDecoder.decode(type, from: data)
        } catch {
            throw TodoAPIError.decodingError(error)
        }
    }

    private func performNetworkRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request, delegate: nil)
        } catch {
            throw TodoAPIError.networkError(error)
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TodoAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TodoAPIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}
