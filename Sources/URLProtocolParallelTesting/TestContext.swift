import Foundation

/// A context for managing test identifiers using TaskLocal storage.
///
/// `TestContext` provides a thread-safe way to pass test identifiers through
/// structured concurrency contexts. This enables parallel test execution without
/// global state conflicts.
///
/// ## Usage
///
/// ```swift
/// @Test func myTest() async throws {
///     let testId = UUID()
///
///     await TestContext.$current.withValue(testId) {
///         // Within this scope, TestContext.current returns testId
///         // Child tasks automatically inherit this value
///
///         await MockURLProtocolRegistry.shared.register(id: testId) { request in
///             return ResponseBuilder.json(#"{"status": "ok"}"#, url: request.url!)
///         }
///
///         let session = TestableURLSession()
///         let (data, _) = try await session.data(for: request)
///     }
///     // Outside the scope, TestContext.current is nil
/// }
/// ```
///
/// ## Important Notes
///
/// - Requires structured concurrency (async/await)
/// - Does not work with detached tasks (`Task.detached`)
/// - Each test should use a unique UUID to ensure isolation
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public enum TestContext {
    /// The current test identifier for the active task.
    ///
    /// This value is automatically inherited by child tasks within the same
    /// structured concurrency context.
    @TaskLocal public static var current: UUID?
}
