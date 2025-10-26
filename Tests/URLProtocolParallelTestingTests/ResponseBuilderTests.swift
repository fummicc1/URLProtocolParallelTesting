import Testing
import Foundation
@testable import URLProtocolParallelTesting


@Suite("ResponseBuilder Tests")
struct ResponseBuilderTests {

    // MARK: - JSON Response Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("JSON文字列からレスポンスを作成できる")
    func testJSONStringResponse() throws {
        let url = URL(string: "https://example.com")!
        let jsonString = #"{"name": "John", "age": 30}"#

        let (data, response) = ResponseBuilder.json(jsonString, url: url)

        #expect(data == jsonString.data(using: .utf8))

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)
        #expect(httpResponse.url == url)
        #expect(httpResponse.allHeaderFields["Content-Type"] as? String == "application/json")
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("カスタムステータスコードでJSONレスポンスを作成できる")
    func testJSONResponseWithCustomStatusCode() throws {
        let url = URL(string: "https://example.com")!
        let jsonString = #"{"error": "Not Found"}"#

        let (data, response) = ResponseBuilder.json(jsonString, statusCode: 404, url: url)

        #expect(data == jsonString.data(using: .utf8))

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 404)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("カスタムヘッダーでJSONレスポンスを作成できる")
    func testJSONResponseWithCustomHeaders() throws {
        let url = URL(string: "https://example.com")!
        let jsonString = #"{"data": "value"}"#
        let headers = [
            "Content-Type": "application/json; charset=utf-8",
            "X-Custom-Header": "custom-value"
        ]

        let (_, response) = ResponseBuilder.json(jsonString, statusCode: 200, url: url)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.allHeaderFields["Content-Type"] as? String == "application/json; charset=utf-8")
        #expect(httpResponse.allHeaderFields["X-Custom-Header"] as? String == "custom-value")
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("空のJSONオブジェクトでレスポンスを作成できる")
    func testEmptyJSONObject() throws {
        let url = URL(string: "https://example.com")!
        let jsonString = "{}"

        let (data, response) = ResponseBuilder.json(jsonString, url: url)

        #expect(data == jsonString.data(using: .utf8))

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("JSON配列でレスポンスを作成できる")
    func testJSONArrayResponse() throws {
        let url = URL(string: "https://example.com")!
        let jsonString = #"[{"id": 1}, {"id": 2}, {"id": 3}]"#

        let (data, response) = ResponseBuilder.json(jsonString, url: url)

        #expect(data == jsonString.data(using: .utf8))

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)
    }

    // MARK: - Encodable Response Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("Encodable型からJSONレスポンスを作成できる")
    func testEncodableResponse() throws {
        struct User: Codable, Equatable {
            let name: String
            let age: Int
        }

        let url = URL(string: "https://example.com")!
        let user = User(name: "Alice", age: 25)

        let (data, response) = try ResponseBuilder.json(user, url: url)

        let decodedUser = try JSONDecoder().decode(User.self, from: data)
        #expect(decodedUser == user)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)
        #expect(httpResponse.allHeaderFields["Content-Type"] as? String == "application/json")
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("カスタムEncoderでEncodableレスポンスを作成できる")
    func testEncodableResponseWithCustomEncoder() throws {
        struct Item: Codable {
            let date: Date
        }

        let url = URL(string: "https://example.com")!
        let item = Item(date: Date(timeIntervalSince1970: 1000))

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970

        let (data, response) = try ResponseBuilder.json(item, url: url, encoder: encoder)

        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(jsonObject?["date"] as? Double == 1000)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("配列のEncodableレスポンスを作成できる")
    func testEncodableArrayResponse() throws {
        struct Item: Codable, Equatable {
            let id: Int
        }

        let url = URL(string: "https://example.com")!
        let items = [Item(id: 1), Item(id: 2), Item(id: 3)]

        let (data, response) = try ResponseBuilder.json(items, url: url)

        let decodedItems = try JSONDecoder().decode([Item].self, from: data)
        #expect(decodedItems == items)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("ネストした構造体のEncodableレスポンスを作成できる")
    func testNestedEncodableResponse() throws {
        struct Address: Codable, Equatable {
            let street: String
            let city: String
        }

        struct Person: Codable, Equatable {
            let name: String
            let address: Address
        }

        let url = URL(string: "https://example.com")!
        let person = Person(
            name: "Bob",
            address: Address(street: "123 Main St", city: "Tokyo")
        )

        let (data, response) = try ResponseBuilder.json(person, url: url)

        let decodedPerson = try JSONDecoder().decode(Person.self, from: data)
        #expect(decodedPerson == person)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)
    }

    // MARK: - Error Response Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("エラーレスポンスを作成できる")
    func testErrorResponse() throws {
        let url = URL(string: "https://example.com")!
        let errorData = Data("Internal Server Error".utf8)

        let (data, response) = try ResponseBuilder.error(statusCode: 500, message: "Internal Server Error", url: url)

        #expect(data == errorData)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 500)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("カスタムヘッダーでエラーレスポンスを作成できる")
    func testErrorResponseWithCustomHeaders() throws {
        let url = URL(string: "https://example.com")!
        let errorData = Data("Unauthorized".utf8)
        let headers = ["WWW-Authenticate": "Bearer"]

        let (_, response) = try ResponseBuilder.error(statusCode: 401, message: "Unauthorized", url: url)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 401)
        #expect(httpResponse.allHeaderFields["WWW-Authenticate"] as? String == "Bearer")
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("JSONエラーレスポンスを作成できる")
    func testJSONErrorResponse() throws {
        let url = URL(string: "https://example.com")!
        let errorJSON = #"{"error": "validation_failed", "message": "Invalid input"}"#
        let errorData = errorJSON.data(using: .utf8)!
        let headers = ["Content-Type": "application/json"]

        let (data, response) = try ResponseBuilder.error(statusCode: 400, message: "Bad Request", url: url)

        #expect(data == errorData)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 400)
        #expect(httpResponse.allHeaderFields["Content-Type"] as? String == "application/json")
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("404エラーレスポンスを作成できる")
    func testNotFoundErrorResponse() throws {
        let url = URL(string: "https://example.com/not-found")!
        let errorData = Data("Not Found".utf8)

        let (data, response) = try ResponseBuilder.error(statusCode: 404, message: "Not Found", url: url)

        #expect(data == errorData)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 404)
    }

    // MARK: - No Content Response Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("204 No Contentレスポンスを作成できる")
    func testNoContentResponse() throws {
        let url = URL(string: "https://example.com")!

        let (data, response) = try ResponseBuilder.noContent(url: url)

        #expect(data.isEmpty)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 204)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("カスタムヘッダーで204レスポンスを作成できる")
    func testNoContentResponseWithCustomHeaders() throws {
        let url = URL(string: "https://example.com")!
        let headers = ["X-Request-ID": "12345"]

        let (_, response) = try try ResponseBuilder.noContent(url: url)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 204)
        #expect(httpResponse.allHeaderFields["X-Request-ID"] as? String == "12345")
    }

    // MARK: - Integration Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("ResponseBuilderをMockURLProtocolRegistryと統合できる")
    func testIntegrationWithRegistry() async throws {
        let testId = UUID()
        let url = URL(string: "https://example.com/api/user")!

        struct User: Codable {
            let id: Int
            let name: String
        }

        let user = User(id: 1, name: "Test User")

        let handler: MockURLProtocolRegistry.RequestHandler = { request in
            try ResponseBuilder.json(user, url: request.url!)
        }

        await MockURLProtocolRegistry.shared.register(id: testId, handler: handler)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        var request = URLRequest(url: url)
        request.setValue(testId.uuidString, forHTTPHeaderField: MockURLProtocol.testIDHeaderName)

        let (data, response) = try await session.data(for: request)

        let decodedUser = try JSONDecoder().decode(User.self, from: data)
        #expect(decodedUser.id == user.id)
        #expect(decodedUser.name == user.name)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)

        await MockURLProtocolRegistry.shared.clear()
    }
}
