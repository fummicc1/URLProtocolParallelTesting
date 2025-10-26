import Foundation

/// A URLSession wrapper that automatically injects test IDs for parallel testing.
///
/// `TestableURLSession` wraps a standard URLSession and automatically injects
/// the `X-Test-ID` header from `TestContext` when running in DEBUG mode. This
/// enables test isolation without modifying production code logic.
///
/// ## Usage
///
/// ### In Production Code
///
/// Replace `URLSession` with `TestableURLSession`:
///
/// ```swift
/// class APIClient {
///     let session: TestableURLSession
///
///     init(session: TestableURLSession = TestableURLSession()) {
///         self.session = session
///     }
///
///     func fetchUser(id: Int) async throws -> User {
///         let url = URL(string: "https://api.example.com/users/\(id)")!
///         let (data, _) = try await session.data(from: url)
///         return try JSONDecoder().decode(User.self, from: data)
///     }
/// }
/// ```
///
/// ### In Tests
///
/// Use with `TestContext` and `MockURLProtocolRegistry`:
///
/// ```swift
/// @Test func testFetchUser() async throws {
///     let testId = UUID()
///
///     await TestContext.$current.withValue(testId) {
///         await MockURLProtocolRegistry.shared.register(id: testId) { request in
///             return ResponseBuilder.json(#"{"id": 1, "name": "Alice"}"#, url: request.url!)
///         }
///
///         let client = APIClient() // Uses TestableURLSession
///         let user = try await client.fetchUser(id: 1)
///
///         #expect(user.name == "Alice")
///     }
/// }
/// ```
///
/// ## Production Safety
///
/// The test ID injection only occurs in DEBUG builds. In release builds,
/// `TestableURLSession` behaves identically to a standard `URLSession`.
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public final class TestableURLSession: @unchecked Sendable {
    /// The underlying URLSession instance.
    private let underlyingSession: URLSession

    /// Creates a new testable URL session.
    ///
    /// The session is automatically configured with `MockURLProtocol` registered
    /// in its protocol classes, allowing it to intercept test requests.
    ///
    /// - Parameter configuration: The URL session configuration to use.
    ///   Defaults to `.default`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Use default configuration
    /// let session = TestableURLSession()
    ///
    /// // Use custom configuration
    /// var config = URLSessionConfiguration.default
    /// config.timeoutIntervalForRequest = 30
    /// let customSession = TestableURLSession(configuration: config)
    /// ```
    public init(configuration: URLSessionConfiguration = .default) {
        // Configure protocol classes
        var protocolClasses = configuration.protocolClasses ?? []

        // Add MockURLProtocol at the highest priority (index 0)
        if !protocolClasses.contains(where: { $0 == MockURLProtocol.self }) {
            protocolClasses.insert(MockURLProtocol.self, at: 0)
        }

        configuration.protocolClasses = protocolClasses
        self.underlyingSession = URLSession(configuration: configuration)
    }

    /// Loads data from the given URL request.
    ///
    /// In DEBUG builds, this method automatically injects the `X-Test-ID` header
    /// from `TestContext.current` before forwarding the request to the underlying
    /// URLSession.
    ///
    /// - Parameters:
    ///   - request: The URL request to execute
    ///   - delegate: An optional delegate for handling authentication challenges
    ///     and other session-level events
    /// - Returns: A tuple containing the response data and URL response
    /// - Throws: Any error that occurs during the request
    ///
    /// ## Example
    ///
    /// ```swift
    /// let session = TestableURLSession()
    /// let request = URLRequest(url: URL(string: "https://api.example.com")!)
    /// let (data, response) = try await session.data(for: request)
    /// ```
    public func data(
        for request: URLRequest,
        delegate: (any URLSessionTaskDelegate)? = nil
    ) async throws -> (Data, URLResponse) {
        var modifiedRequest = request

        #if DEBUG
        // Inject test ID from TestContext if available
        if let testId = TestContext.current {
            modifiedRequest.setValue(
                testId.uuidString,
                forHTTPHeaderField: MockURLProtocol.testIDHeaderName
            )
        }
        #endif

        return try await underlyingSession.data(for: modifiedRequest, delegate: delegate)
    }

    /// Loads data from the given URL.
    ///
    /// This is a convenience method that creates a URLRequest from the URL
    /// and calls `data(for:delegate:)`.
    ///
    /// - Parameter url: The URL to load data from
    /// - Returns: A tuple containing the response data and URL response
    /// - Throws: Any error that occurs during the request
    ///
    /// ## Example
    ///
    /// ```swift
    /// let session = TestableURLSession()
    /// let (data, response) = try await session.data(from: URL(string: "https://api.example.com")!)
    /// ```
    public func data(from url: URL) async throws -> (Data, URLResponse) {
        let request = URLRequest(url: url)
        return try await data(for: request)
    }
}
