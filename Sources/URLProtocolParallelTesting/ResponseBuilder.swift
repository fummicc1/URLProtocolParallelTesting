import Foundation

/// A builder for constructing HTTP responses in tests.
///
/// `ResponseBuilder` provides a fluent API for creating HTTPURLResponse instances
/// with common configurations, reducing boilerplate in test code.
///
/// ## Basic Usage
/// ```swift
/// let response = try ResponseBuilder(url: URL(string: "https://api.example.com")!)
///     .statusCode(200)
///     .header("Content-Type", "application/json")
///     .build()
/// ```
///
/// ## Shortcuts for Common Scenarios
/// ```swift
/// // Successful JSON response
/// let (data, response) = ResponseBuilder.json(
///     #"{"id": 1, "name": "Alice"}"#,
///     url: URL(string: "https://api.example.com")!
/// )
///
/// // Error response
/// let (data, response) = try ResponseBuilder.error(
///     statusCode: 404,
///     message: "Not Found",
///     url: URL(string: "https://api.example.com")!
/// )
/// ```
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public struct ResponseBuilder {
    private let url: URL
    private var statusCode: Int = 200
    private var headerFields: [String: String] = [:]
    private var httpVersion: String?

    /// Creates a new response builder for the specified URL.
    ///
    /// - Parameter url: The URL for the response
    public init(url: URL) {
        self.url = url
    }

    /// Sets the HTTP status code.
    ///
    /// - Parameter code: The status code (e.g., 200, 404, 500)
    /// - Returns: The builder instance for chaining
    public func statusCode(_ code: Int) -> ResponseBuilder {
        var builder = self
        builder.statusCode = code
        return builder
    }

    /// Adds a header field to the response.
    ///
    /// - Parameters:
    ///   - name: The header field name (e.g., "Content-Type")
    ///   - value: The header field value
    /// - Returns: The builder instance for chaining
    public func header(_ name: String, _ value: String) -> ResponseBuilder {
        var builder = self
        builder.headerFields[name] = value
        return builder
    }

    /// Sets multiple header fields at once.
    ///
    /// - Parameter fields: A dictionary of header field names and values
    /// - Returns: The builder instance for chaining
    public func headers(_ fields: [String: String]) -> ResponseBuilder {
        var builder = self
        builder.headerFields.merge(fields) { _, new in new }
        return builder
    }

    /// Sets the HTTP version string.
    ///
    /// - Parameter version: The HTTP version (e.g., "HTTP/1.1")
    /// - Returns: The builder instance for chaining
    public func httpVersion(_ version: String) -> ResponseBuilder {
        var builder = self
        builder.httpVersion = version
        return builder
    }

    /// Builds the HTTPURLResponse instance.
    ///
    /// - Returns: A configured HTTPURLResponse
    /// - Throws: `ResponseBuilderError.invalidConfiguration` if the response cannot be created
    public func build() throws -> HTTPURLResponse {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: httpVersion,
            headerFields: headerFields
        ) else {
            throw ResponseBuilderError.invalidConfiguration(
                url: url,
                statusCode: statusCode
            )
        }
        return response
    }
}

// MARK: - Convenience Factories

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension ResponseBuilder {
    /// Creates a successful JSON response with the provided JSON string.
    ///
    /// - Parameters:
    ///   - json: A JSON string to use as the response body
    ///   - statusCode: The HTTP status code (defaults to 200)
    ///   - url: The URL for the response
    /// - Returns: A tuple of Data and HTTPURLResponse
    ///
    /// ## Example
    /// ```swift
    /// let (data, response) = ResponseBuilder.json(
    ///     #"{"status": "success"}"#,
    ///     url: URL(string: "https://api.example.com")!
    /// )
    /// ```
    public static func json(
        _ json: String,
        statusCode: Int = 200,
        url: URL
    ) -> (Data, HTTPURLResponse) {
        let data = json.data(using: .utf8) ?? Data()
        let response = (try? ResponseBuilder(url: url)
            .statusCode(statusCode)
            .header("Content-Type", "application/json")
            .build()) ?? HTTPURLResponse()
        return (data, response)
    }

    /// Creates a successful JSON response from an encodable value.
    ///
    /// - Parameters:
    ///   - value: An encodable value to serialize as JSON
    ///   - statusCode: The HTTP status code (defaults to 200)
    ///   - url: The URL for the response
    ///   - encoder: The JSON encoder to use (defaults to JSONEncoder())
    /// - Returns: A tuple of Data and HTTPURLResponse
    /// - Throws: An error if encoding fails
    ///
    /// ## Example
    /// ```swift
    /// struct User: Encodable {
    ///     let id: Int
    ///     let name: String
    /// }
    ///
    /// let user = User(id: 1, name: "Alice")
    /// let (data, response) = try ResponseBuilder.json(
    ///     user,
    ///     url: URL(string: "https://api.example.com")!
    /// )
    /// ```
    public static func json<T: Encodable>(
        _ value: T,
        statusCode: Int = 200,
        url: URL,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> (Data, HTTPURLResponse) {
        let data = try encoder.encode(value)
        let response = try ResponseBuilder(url: url)
            .statusCode(statusCode)
            .header("Content-Type", "application/json")
            .build()
        return (data, response)
    }

    /// Creates an error response with the specified status code and message.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP error status code (e.g., 404, 500)
    ///   - message: An optional error message to include in the response body
    ///   - url: The URL for the response
    /// - Returns: A tuple of Data and HTTPURLResponse
    /// - Throws: `ResponseBuilderError.invalidConfiguration` if the response cannot be created
    ///
    /// ## Example
    /// ```swift
    /// let (data, response) = try ResponseBuilder.error(
    ///     statusCode: 404,
    ///     message: "Resource not found",
    ///     url: URL(string: "https://api.example.com")!
    /// )
    /// ```
    public static func error(
        statusCode: Int,
        message: String? = nil,
        url: URL
    ) throws -> (Data, HTTPURLResponse) {
        let data: Data
        let builder = ResponseBuilder(url: url).statusCode(statusCode)

        if let message = message {
            let errorJSON = #"{"error": "\#(message)"}"#
            data = errorJSON.data(using: .utf8) ?? Data()
            let response = try builder
                .header("Content-Type", "application/json")
                .build()
            return (data, response)
        } else {
            data = Data()
            let response = try builder.build()
            return (data, response)
        }
    }

    /// Creates an empty successful response (204 No Content).
    ///
    /// - Parameter url: The URL for the response
    /// - Returns: A tuple of empty Data and HTTPURLResponse with status 204
    /// - Throws: `ResponseBuilderError.invalidConfiguration` if the response cannot be created
    ///
    /// ## Example
    /// ```swift
    /// let (data, response) = try ResponseBuilder.noContent(
    ///     url: URL(string: "https://api.example.com")!
    /// )
    /// ```
    public static func noContent(url: URL) throws -> (Data, HTTPURLResponse) {
        let response = try ResponseBuilder(url: url)
            .statusCode(204)
            .build()
        return (Data(), response)
    }
}

// MARK: - Error Types

/// Errors that can be thrown by `ResponseBuilder`.
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public enum ResponseBuilderError: Error, CustomStringConvertible {
    /// Thrown when HTTPURLResponse initialization fails.
    case invalidConfiguration(url: URL, statusCode: Int)

    public var description: String {
        switch self {
        case .invalidConfiguration(let url, let statusCode):
            return """
            Failed to create HTTPURLResponse with:
            - URL: \(url.absoluteString)
            - Status Code: \(statusCode)
            """
        }
    }
}
