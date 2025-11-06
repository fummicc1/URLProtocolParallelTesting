import Foundation

/// A custom URLProtocol implementation for intercepting and mocking HTTP requests in tests.
///
/// `MockURLProtocol` intercepts requests that contain an `X-Test-ID` header,
/// retrieves the appropriate handler from `MockURLProtocolRegistry`, and returns
/// the mocked response. This enables parallel test execution while using the actual
/// URLSession pipeline.
///
/// ## How It Works
///
/// 1. `TestableURLSession` automatically injects the `X-Test-ID` header
/// 2. URLSession processes the request normally
/// 3. `MockURLProtocol.canInit` checks for the header
/// 4. `MockURLProtocol.startLoading` retrieves and executes the handler
/// 5. The mocked response is returned to the test
///
/// ## Usage
///
/// You typically don't use `MockURLProtocol` directly. Instead, use `TestableURLSession`:
///
/// ```swift
/// @Test func testAPI() async throws {
///     let testId = UUID()
///
///     await TestContext.$current.withValue(testId) {
///         await MockURLProtocolRegistry.shared.register(id: testId) { request in
///             return ResponseBuilder.json(#"{"status": "ok"}"#, url: request.url!)
///         }
///
///         let session = TestableURLSession()
///         let (data, _) = try await session.data(for: request)
///     }
/// }
/// ```
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    /// The header name used for test identification.
    public static let testIDHeaderName = "X-Test-ID"

    /// Cancellation flag for stopping ongoing requests.
    private var isCancelled = false

    /// Determines whether this protocol can handle the given request.
    ///
    /// Returns `true` only if the request contains an `X-Test-ID` header,
    /// ensuring that only test requests are intercepted.
    ///
    /// - Parameter request: The URL request to evaluate
    /// - Returns: `true` if the request has an `X-Test-ID` header, `false` otherwise
    override public class func canInit(with request: URLRequest) -> Bool {
        return request.value(forHTTPHeaderField: testIDHeaderName) != nil
    }

    /// Returns the canonical version of the request.
    ///
    /// The request is returned unchanged.
    ///
    /// - Parameter request: The URL request
    /// - Returns: The same request
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    /// Starts loading the request by executing the registered handler.
    ///
    /// This method:
    /// 1. Extracts the test ID from the `X-Test-ID` header
    /// 2. Retrieves the handler from `MockURLProtocolRegistry`
    /// 3. Executes the handler to get the mocked response
    /// 4. Returns the response to URLSession
    ///
    /// ## Error Handling
    ///
    /// - Throws `MockURLProtocolError.missingOrInvalidTestID` if the header is missing or invalid
    /// - Throws `MockURLProtocolError.noHandlerRegistered` if no handler is found for the test ID
    /// - Propagates any errors thrown by the handler
    override public func startLoading() {
        // URLProtocol's startLoading() is synchronous, so we use Task for async operations
        Task {
            guard !isCancelled else { return }

            // Extract test ID from header
            guard let testIdString = request.value(forHTTPHeaderField: Self.testIDHeaderName),
                  let testId = UUID(uuidString: testIdString) else {
                let error = MockURLProtocolError.missingOrInvalidTestID(request: request)
                client?.urlProtocol(self, didFailWithError: error)
                return
            }

            // Retrieve handler from registry
            guard let handler = await MockURLProtocolRegistry.shared.getHandler(for: testId) else {
                let error = MockURLProtocolError.noHandlerRegistered(testId: testId, request: request)
                client?.urlProtocol(self, didFailWithError: error)
                return
            }

            do {
                // Execute handler
                let (data, response) = try handler(request)

                guard !isCancelled else { return }

                // Notify client of response
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                guard !isCancelled else { return }
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    /// Stops loading the request.
    ///
    /// Sets the cancellation flag to prevent further processing.
    override public func stopLoading() {
        isCancelled = true
    }
}

// MARK: - Error Types

/// Errors that can be thrown by `MockURLProtocol`.
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public enum MockURLProtocolError: Error, CustomStringConvertible {
    /// Thrown when the `X-Test-ID` header is missing or contains an invalid UUID.
    case missingOrInvalidTestID(request: URLRequest)

    /// Thrown when no handler is registered for the test ID.
    case noHandlerRegistered(testId: UUID, request: URLRequest)

    public var description: String {
        switch self {
        case .missingOrInvalidTestID(let request):
            return """
            Missing or invalid X-Test-ID header in request: \(request.url?.absoluteString ?? "nil")
            Make sure to use TestableURLSession or manually add the X-Test-ID header.
            """
        case .noHandlerRegistered(let testId, let request):
            return """
            No handler registered for test ID: \(testId)
            Request: \(request.url?.absoluteString ?? "nil")
            Did you forget to call MockURLProtocolRegistry.shared.register(id:handler:)?
            """
        }
    }
}
