import Testing
import Foundation
@testable import URLProtocolParallelTesting

// Helper for capturing values in @Sendable closures
final class Box<T>: @unchecked Sendable {
    var value: T?
    init(_ value: T? = nil) {
        self.value = value
    }
}

@Suite("TestableURLSession Tests")
struct TestableURLSessionTests {

    // MARK: - Initialization Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("デフォルト設定で初期化できる")
    func testInitWithDefaultConfiguration() throws {
        let session = TestableURLSession()
        // Session is non-optional, always exists
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("カスタム設定で初期化できる")
    func testInitWithCustomConfiguration() throws {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        let session = TestableURLSession(configuration: config)
        // Session is non-optional, always exists
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("MockURLProtocolがprotocolClassesに自動登録される")
    func testMockURLProtocolAutoRegistration() throws {
        let config = URLSessionConfiguration.default
        _ = TestableURLSession(configuration: config)

        // Verify that MockURLProtocol is at the beginning of protocolClasses
        #expect(config.protocolClasses?.first is MockURLProtocol.Type)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("既存のprotocolClassesが保持される")
    func testExistingProtocolClassesPreserved() throws {
        class CustomProtocol: URLProtocol {}

        let config = URLSessionConfiguration.default
        config.protocolClasses = [CustomProtocol.self]

        _ = TestableURLSession(configuration: config)

        #expect(config.protocolClasses?.count == 2)
        #expect(config.protocolClasses?.first is MockURLProtocol.Type)
        #expect(config.protocolClasses?[1] is CustomProtocol.Type)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("MockURLProtocolが重複登録されない")
    func testMockURLProtocolNotDuplicated() throws {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]

        _ = TestableURLSession(configuration: config)

        let mockProtocolCount = config.protocolClasses?.filter { $0 == MockURLProtocol.self }.count
        #expect(mockProtocolCount == 1)
    }

    // MARK: - TestContext Integration Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("TestContextのテストIDがリクエストヘッダーに自動注入される")
    func testTestContextIDAutoInjection() async throws {
        let testId = UUID()
        let requestURL = URL(string: "https://example.com/test")!

        let receivedTestId = Box<UUID>()

        let handler: MockURLProtocolRegistry.RequestHandler = { request in
            if let testIdString = request.value(forHTTPHeaderField: MockURLProtocol.testIDHeaderName),
               let uuid = UUID(uuidString: testIdString) {
                receivedTestId.value = uuid
            }
            let response = HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await MockURLProtocolRegistry.shared.register(id: testId, handler: handler)

        await TestContext.$current.withValue(testId) {
            let session = TestableURLSession()
            let request = URLRequest(url: requestURL)

            _ = try? await session.data(for: request)
        }

        #expect(receivedTestId.value == testId)

        await MockURLProtocolRegistry.shared.clear()
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("TestContextがnilの場合はヘッダーが注入されない")
    func testNoHeaderInjectionWhenTestContextIsNil() async throws {
        let requestURL = URL(string: "https://example.com/test")!

        let session = TestableURLSession()
        let request = URLRequest(url: requestURL)

        // TestContext.current is nil by default, so the request should not have X-Test-ID header
        // This means MockURLProtocol.canInit should return false
        let canInit = MockURLProtocol.canInit(with: request)
        #expect(canInit == false)
    }

    // MARK: - Request Execution Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("通常のリクエストを実行できる")
    func testExecuteNormalRequest() async throws {
        let testId = UUID()
        let requestURL = URL(string: "https://example.com/test")!
        let expectedData = Data("response".utf8)

        let handler: MockURLProtocolRegistry.RequestHandler = { _ in
            let response = HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (expectedData, response)
        }

        await MockURLProtocolRegistry.shared.register(id: testId, handler: handler)

        await TestContext.$current.withValue(testId) {
            let session = TestableURLSession()
            let request = URLRequest(url: requestURL)

            do {
                let (data, response) = try await session.data(for: request)
                #expect(data == expectedData)
                #expect((response as? HTTPURLResponse)?.statusCode == 200)
            } catch {
                Issue.record("Request failed: \(error)")
            }
        }

        await MockURLProtocolRegistry.shared.clear()
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("POSTリクエストを実行できる")
    func testExecutePOSTRequest() async throws {
        let testId = UUID()
        let requestURL = URL(string: "https://example.com/test")!
        let requestBody = Data("request body".utf8)

        let receivedMethod = Box<String>()
        let receivedBody = Box<Data>()

        let handler: MockURLProtocolRegistry.RequestHandler = { request in
            receivedMethod.value = request.httpMethod
            receivedBody.value = request.httpBody
            let response = HTTPURLResponse(url: requestURL, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await MockURLProtocolRegistry.shared.register(id: testId, handler: handler)

        await TestContext.$current.withValue(testId) {
            let session = TestableURLSession()
            var request = URLRequest(url: requestURL)
            request.httpMethod = "POST"
            request.httpBody = requestBody

            _ = try? await session.data(for: request)
        }

        #expect(receivedMethod.value == "POST")
        #expect(receivedBody.value == requestBody)

        await MockURLProtocolRegistry.shared.clear()
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("カスタムヘッダーが保持される")
    func testCustomHeadersPreserved() async throws {
        let testId = UUID()
        let requestURL = URL(string: "https://example.com/test")!

        let receivedHeaders = Box<[String: String]>()

        let handler: MockURLProtocolRegistry.RequestHandler = { request in
            var headers: [String: String] = [:]
            headers["Content-Type"] = request.value(forHTTPHeaderField: "Content-Type")
            headers["Authorization"] = request.value(forHTTPHeaderField: "Authorization")
            receivedHeaders.value = headers
            let response = HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await MockURLProtocolRegistry.shared.register(id: testId, handler: handler)

        await TestContext.$current.withValue(testId) {
            let session = TestableURLSession()
            var request = URLRequest(url: requestURL)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer token", forHTTPHeaderField: "Authorization")

            _ = try? await session.data(for: request)
        }

        #expect(receivedHeaders.value?["Content-Type"] == "application/json")
        #expect(receivedHeaders.value?["Authorization"] == "Bearer token")

        await MockURLProtocolRegistry.shared.clear()
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("既存のX-Test-IDヘッダーは上書きされる")
    func testExistingTestIDHeaderOverwritten() async throws {
        let testId = UUID()
        let differentTestId = UUID()
        let requestURL = URL(string: "https://example.com/test")!

        let receivedTestId = Box<UUID>()

        let handler: MockURLProtocolRegistry.RequestHandler = { request in
            if let testIdString = request.value(forHTTPHeaderField: MockURLProtocol.testIDHeaderName),
               let uuid = UUID(uuidString: testIdString) {
                receivedTestId.value = uuid
            }
            let response = HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await MockURLProtocolRegistry.shared.register(id: testId, handler: handler)

        await TestContext.$current.withValue(testId) {
            let session = TestableURLSession()
            var request = URLRequest(url: requestURL)
            // Set different test ID in header
            request.setValue(differentTestId.uuidString, forHTTPHeaderField: MockURLProtocol.testIDHeaderName)

            _ = try? await session.data(for: request)
        }

        // Should receive the TestContext ID, not the manually set one
        #expect(receivedTestId.value == testId)

        await MockURLProtocolRegistry.shared.clear()
    }

    // MARK: - Error Handling Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("ハンドラーが登録されていない場合にエラーが発生する")
    func testErrorWhenHandlerNotRegistered() async throws {
        let testId = UUID()
        let requestURL = URL(string: "https://example.com/test")!

        await TestContext.$current.withValue(testId) {
            let session = TestableURLSession()
            let request = URLRequest(url: requestURL)

            do {
                _ = try await session.data(for: request)
                Issue.record("Expected error but request succeeded")
            } catch {
                #expect(error is URLError)
            }
        }
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("ハンドラーがエラーをスローした場合に正しく伝播される")
    func testHandlerErrorPropagation() async throws {
        let testId = UUID()
        let requestURL = URL(string: "https://example.com/test")!

        struct CustomError: Error {}

        let handler: MockURLProtocolRegistry.RequestHandler = { _ in
            throw CustomError()
        }

        await MockURLProtocolRegistry.shared.register(id: testId, handler: handler)

        await TestContext.$current.withValue(testId) {
            let session = TestableURLSession()
            let request = URLRequest(url: requestURL)

            do {
                _ = try await session.data(for: request)
                Issue.record("Expected error but request succeeded")
            } catch {
                #expect(error is URLError)
            }
        }

        await MockURLProtocolRegistry.shared.clear()
    }

    // MARK: - Parallel Execution Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("並列リクエストが正しく分離される")
    func testParallelRequestsIsolation() async throws {
        let testId1 = UUID()
        let testId2 = UUID()
        let requestURL = URL(string: "https://example.com/test")!

        let handler1: MockURLProtocolRegistry.RequestHandler = { _ in
            let response = HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("response1".utf8), response)
        }

        let handler2: MockURLProtocolRegistry.RequestHandler = { _ in
            let response = HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("response2".utf8), response)
        }

        await MockURLProtocolRegistry.shared.register(id: testId1, handler: handler1)
        await MockURLProtocolRegistry.shared.register(id: testId2, handler: handler2)

        async let result1: (Data, URLResponse) = TestContext.$current.withValue(testId1) {
            let session = TestableURLSession()
            let request = URLRequest(url: requestURL)
            return try await session.data(for: request)
        }

        async let result2: (Data, URLResponse) = TestContext.$current.withValue(testId2) {
            let session = TestableURLSession()
            let request = URLRequest(url: requestURL)
            return try await session.data(for: request)
        }

        let (data1, _) = try await result1
        let (data2, _) = try await result2

        #expect(String(data: data1, encoding: .utf8) == "response1")
        #expect(String(data: data2, encoding: .utf8) == "response2")

        await MockURLProtocolRegistry.shared.clear()
    }
}
