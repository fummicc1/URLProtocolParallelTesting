import Foundation

/// A thread-safe registry for managing request handlers per test ID.
///
/// `MockURLProtocolRegistry` provides actor-isolated storage for test-specific
/// request handlers, enabling parallel test execution without interference.
/// Each test registers handlers using a unique UUID, and `MockURLProtocol`
/// retrieves the appropriate handler based on the test ID in the request header.
///
/// ## Usage
///
/// ```swift
/// @Test func myTest() async throws {
///     let testId = UUID()
///
///     // Register a handler for this test
///     await MockURLProtocolRegistry.shared.register(id: testId) { request in
///         let data = #"{"status": "ok"}"#.data(using: .utf8)!
///         let response = HTTPURLResponse(
///             url: request.url!,
///             statusCode: 200,
///             httpVersion: nil,
///             headerFields: ["Content-Type": "application/json"]
///         )!
///         return (data, response)
///     }
///
///     defer {
///         Task { await MockURLProtocolRegistry.shared.unregister(id: testId) }
///     }
///
///     // Make request - handler will be called automatically
///     let session = TestableURLSession()
///     let (data, _) = try await session.data(for: request)
/// }
/// ```
///
/// ## FIFO Handler Queue
///
/// Multiple handlers can be registered for sequential requests:
///
/// ```swift
/// await registry.register(id: testId) { _ in (loginData, loginResponse) }
/// await registry.register(id: testId) { _ in (profileData, profileResponse) }
/// // First request gets loginData, second gets profileData
/// ```
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public actor MockURLProtocolRegistry {
    /// The shared singleton instance.
    public static let shared = MockURLProtocolRegistry()

    /// A closure that handles a URL request and returns response data.
    ///
    /// - Parameter request: The URL request to handle
    /// - Returns: A tuple of response data and URL response
    /// - Throws: Any error to simulate network failures
    public typealias RequestHandler = @Sendable (URLRequest) throws -> (Data, URLResponse)

    /// FIFO queue for request handlers.
    private struct HandlerQueue {
        var handlers: [RequestHandler] = []

        mutating func enqueue(_ handler: @escaping RequestHandler) {
            handlers.append(handler)
        }

        mutating func dequeue() -> RequestHandler? {
            guard !handlers.isEmpty else { return nil }
            return handlers.removeFirst()
        }

        var isEmpty: Bool {
            handlers.isEmpty
        }
    }

    /// Test ID to handler queue mapping.
    private var handlerQueues: [UUID: HandlerQueue] = [:]

    private init() {}

    /// Registers a request handler for the specified test ID.
    ///
    /// Handlers are executed in FIFO order. Multiple handlers can be registered
    /// for the same test ID to handle sequential requests.
    ///
    /// - Parameters:
    ///   - id: The test identifier (typically from `TestContext.current`)
    ///   - handler: A closure that handles the request and returns response data
    ///
    /// ## Example
    ///
    /// ```swift
    /// await MockURLProtocolRegistry.shared.register(id: testId) { request in
    ///     #expect(request.httpMethod == "GET")
    ///     return ResponseBuilder.json(#"{"id": 1}"#, url: request.url!)
    /// }
    /// ```
    public func register(id: UUID, handler: @escaping RequestHandler) {
        if handlerQueues[id] == nil {
            handlerQueues[id] = HandlerQueue()
        }
        handlerQueues[id]?.enqueue(handler)
    }

    /// Retrieves and removes the next handler for the specified test ID.
    ///
    /// Handlers are retrieved in FIFO order. Returns `nil` if no handlers
    /// are registered for the given test ID.
    ///
    /// - Parameter id: The test identifier
    /// - Returns: The next handler in the queue, or `nil` if the queue is empty
    public func getHandler(for id: UUID) -> RequestHandler? {
        handlerQueues[id]?.dequeue()
    }

    /// Removes all handlers for the specified test ID.
    ///
    /// This should typically be called in a `defer` block to clean up after tests:
    ///
    /// ```swift
    /// defer {
    ///     Task { await MockURLProtocolRegistry.shared.unregister(id: testId) }
    /// }
    /// ```
    ///
    /// - Parameter id: The test identifier
    public func unregister(id: UUID) {
        handlerQueues.removeValue(forKey: id)
    }

    /// Removes all registered handlers.
    ///
    /// Primarily useful for testing the registry itself or for complete cleanup.
    public func clear() {
        handlerQueues.removeAll()
    }
}
