import Testing
import Foundation
@testable import URLProtocolParallelTesting


@Suite("MockURLProtocol Tests")
struct MockURLProtocolTests {

    // MARK: - canInit Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("X-Test-IDヘッダーがあるリクエストをcanInitで受け入れる")
    func testCanInitWithTestIDHeader() throws {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.setValue(UUID().uuidString, forHTTPHeaderField: MockURLProtocol.testIDHeaderName)

        let canInit = MockURLProtocol.canInit(with: request)
        #expect(canInit == true)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("X-Test-IDヘッダーがないリクエストをcanInitで拒否する")
    func testCanInitWithoutTestIDHeader() throws {
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let canInit = MockURLProtocol.canInit(with: request)
        #expect(canInit == false)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("空のX-Test-IDヘッダーがあるリクエストをcanInitで受け入れる")
    func testCanInitWithEmptyTestIDHeader() throws {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.setValue("", forHTTPHeaderField: MockURLProtocol.testIDHeaderName)

        let canInit = MockURLProtocol.canInit(with: request)
        #expect(canInit == true)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("canonicalRequestがリクエストをそのまま返す")
    func testCanonicalRequest() throws {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.setValue(UUID().uuidString, forHTTPHeaderField: MockURLProtocol.testIDHeaderName)

        let canonical = MockURLProtocol.canonicalRequest(for: request)
        #expect(canonical.url == request.url)
        #expect(canonical.httpMethod == request.httpMethod)
    }

    // MARK: - Error Type Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("MissingOrInvalidTestIDエラーの説明が正しい")
    func testMissingOrInvalidTestIDErrorDescription() throws {
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let error = MockURLProtocolError.missingOrInvalidTestID(request: request)

        let description = error.description
        #expect(description.contains("Missing or invalid X-Test-ID header"))
        #expect(description.contains("https://example.com"))
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("NoHandlerRegisteredエラーの説明が正しい")
    func testNoHandlerRegisteredErrorDescription() throws {
        let testId = UUID()
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let error = MockURLProtocolError.noHandlerRegistered(testId: testId, request: request)

        let description = error.description
        #expect(description.contains("No handler registered"))
        #expect(description.contains(testId.uuidString))
        #expect(description.contains("https://example.com"))
    }

    // MARK: - Integration Tests with URLSession

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("登録されたハンドラーでリクエストをインターセプトできる")
    func testInterceptRequestWithRegisteredHandler() async throws {
        let testId = UUID()
        let expectedData = Data("Hello, World!".utf8)
        let expectedURL = URL(string: "https://example.com/test")!

        let handler: MockURLProtocolRegistry.RequestHandler = { request in
            #expect(request.url == expectedURL)
            let response = HTTPURLResponse(
                url: expectedURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (expectedData, response)
        }

        await MockURLProtocolRegistry.shared.register(id: testId, handler: handler)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        var request = URLRequest(url: expectedURL)
        request.setValue(testId.uuidString, forHTTPHeaderField: MockURLProtocol.testIDHeaderName)

        let (data, response) = try await session.data(for: request)

        #expect(data == expectedData)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)

        await MockURLProtocolRegistry.shared.clear()
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("ハンドラーが登録されていない場合にエラーが発生する")
    func testErrorWhenNoHandlerRegistered() async throws {
        let testId = UUID()
        let requestURL = URL(string: "https://example.com/test")!

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        var request = URLRequest(url: requestURL)
        request.setValue(testId.uuidString, forHTTPHeaderField: MockURLProtocol.testIDHeaderName)

        do {
            _ = try await session.data(for: request)
            Issue.record("Expected error but request succeeded")
        } catch {
            // Expected to fail
            #expect(error is URLError)
        }
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("無効なUUID形式のX-Test-IDヘッダーでエラーが発生する")
    func testErrorWithInvalidUUIDFormat() async throws {
        let requestURL = URL(string: "https://example.com/test")!

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        var request = URLRequest(url: requestURL)
        request.setValue("invalid-uuid", forHTTPHeaderField: MockURLProtocol.testIDHeaderName)

        do {
            _ = try await session.data(for: request)
            Issue.record("Expected error but request succeeded")
        } catch {
            // Expected to fail
            #expect(error is URLError)
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

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        var request = URLRequest(url: requestURL)
        request.setValue(testId.uuidString, forHTTPHeaderField: MockURLProtocol.testIDHeaderName)

        do {
            _ = try await session.data(for: request)
            Issue.record("Expected error but request succeeded")
        } catch {
            // Expected to fail with URLError
            #expect(error is URLError)
        }

        await MockURLProtocolRegistry.shared.clear()
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("複数の連続したリクエストを処理できる")
    func testMultipleSequentialRequests() async throws {
        let testId = UUID()
        let requestURL = URL(string: "https://example.com/test")!

        let handler1: MockURLProtocolRegistry.RequestHandler = { _ in
            let response = HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("first".utf8), response)
        }

        let handler2: MockURLProtocolRegistry.RequestHandler = { _ in
            let response = HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("second".utf8), response)
        }

        await MockURLProtocolRegistry.shared.register(id: testId, handler: handler1)
        await MockURLProtocolRegistry.shared.register(id: testId, handler: handler2)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        var request = URLRequest(url: requestURL)
        request.setValue(testId.uuidString, forHTTPHeaderField: MockURLProtocol.testIDHeaderName)

        let (data1, _) = try await session.data(for: request)
        let (data2, _) = try await session.data(for: request)

        #expect(String(data: data1, encoding: .utf8) == "first")
        #expect(String(data: data2, encoding: .utf8) == "second")

        await MockURLProtocolRegistry.shared.clear()
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("HTTPメソッドとヘッダーが正しくハンドラーに渡される")
    func testRequestMethodAndHeadersPassedToHandler() async throws {
        let testId = UUID()
        let requestURL = URL(string: "https://example.com/test")!

        let receivedRequest = Box<URLRequest>()

        let handler: MockURLProtocolRegistry.RequestHandler = { request in
            receivedRequest.value = request
            let response = HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await MockURLProtocolRegistry.shared.register(id: testId, handler: handler)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer token", forHTTPHeaderField: "Authorization")
        request.setValue(testId.uuidString, forHTTPHeaderField: MockURLProtocol.testIDHeaderName)

        _ = try await session.data(for: request)

        #expect(receivedRequest.value?.httpMethod == "POST")
        #expect(receivedRequest.value?.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(receivedRequest.value?.value(forHTTPHeaderField: "Authorization") == "Bearer token")

        await MockURLProtocolRegistry.shared.clear()
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("リクエストボディが正しくハンドラーに渡される")
    func testRequestBodyPassedToHandler() async throws {
        let testId = UUID()
        let requestURL = URL(string: "https://example.com/test")!
        let expectedBody = Data("request body".utf8)

        let receivedBody = Box<Data>()

        let handler: MockURLProtocolRegistry.RequestHandler = { request in
            receivedBody.value = request.httpBody
            let response = HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await MockURLProtocolRegistry.shared.register(id: testId, handler: handler)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.httpBody = expectedBody
        request.setValue(testId.uuidString, forHTTPHeaderField: MockURLProtocol.testIDHeaderName)

        _ = try await session.data(for: request)

        #expect(receivedBody.value == expectedBody)

        await MockURLProtocolRegistry.shared.clear()
    }
}
