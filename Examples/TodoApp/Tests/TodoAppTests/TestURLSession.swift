import Foundation
import URLProtocolParallelTesting
@testable import TodoApp

/// A URLSession wrapper that automatically injects test IDs for parallel testing.
///
/// This helper class demonstrates how to implement test isolation by wrapping URLSession
/// and automatically adding the X-Test-ID header to all requests.
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
final class TestURLSession: URLSessionProtocol, @unchecked Sendable {
    private let underlying: URLSession
    private let testId: UUID

    init(testId: UUID, configuration: URLSessionConfiguration = .ephemeral) {
        self.testId = testId

        // Configure with MockURLProtocol
        var config = configuration
        var protocolClasses = config.protocolClasses ?? []
        if !protocolClasses.contains(where: { $0 == MockURLProtocol.self }) {
            protocolClasses.insert(MockURLProtocol.self, at: 0)
        }
        config.protocolClasses = protocolClasses

        self.underlying = URLSession(configuration: config)
    }

    func data(
        for request: URLRequest,
        delegate: (any URLSessionTaskDelegate)?
    ) async throws -> (Data, URLResponse) {
        // Inject test ID header
        var modifiedRequest = request
        modifiedRequest.setValue(
            testId.uuidString,
            forHTTPHeaderField: MockURLProtocol.testIDHeaderName
        )

        return try await underlying.data(for: modifiedRequest, delegate: delegate)
    }
}
