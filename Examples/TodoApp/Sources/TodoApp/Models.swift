import Foundation

/// Represents a single Todo item
public struct Todo: Codable, Sendable, Equatable {
    public let id: Int
    public let title: String
    public let completed: Bool
    public let userId: Int

    public init(id: Int, title: String, completed: Bool, userId: Int) {
        self.id = id
        self.title = title
        self.completed = completed
        self.userId = userId
    }
}

/// Request body for creating a new Todo
public struct CreateTodoRequest: Codable, Sendable {
    public let title: String
    public let completed: Bool
    public let userId: Int

    public init(title: String, completed: Bool = false, userId: Int) {
        self.title = title
        self.completed = completed
        self.userId = userId
    }
}

/// Request body for updating a Todo
public struct UpdateTodoRequest: Codable, Sendable {
    public let title: String?
    public let completed: Bool?

    public init(title: String? = nil, completed: Bool? = nil) {
        self.title = title
        self.completed = completed
    }
}

/// API error types
public enum TodoAPIError: Error, Sendable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)
}
