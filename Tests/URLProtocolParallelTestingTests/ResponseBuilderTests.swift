import Testing
import Foundation
@testable import URLProtocolParallelTesting


@Suite("ResponseBuilder Tests", .serialized)
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
    @Test("JSONレスポンスにContent-Typeヘッダーが含まれる")
    func testJSONResponseHasContentTypeHeader() throws {
        let url = URL(string: "https://example.com")!
        let jsonString = #"{"data": "value"}"#

        let (_, response) = ResponseBuilder.json(jsonString, statusCode: 200, url: url)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.allHeaderFields["Content-Type"] as? String == "application/json")
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
    @Test("401エラーレスポンスを作成できる")
    func testUnauthorizedErrorResponse() throws {
        let url = URL(string: "https://example.com")!
        let errorData = Data("Unauthorized".utf8)

        let (data, response) = try ResponseBuilder.error(statusCode: 401, message: "Unauthorized", url: url)

        #expect(data == errorData)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 401)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("400エラーレスポンスを作成できる")
    func testBadRequestErrorResponse() throws {
        let url = URL(string: "https://example.com")!
        let errorData = Data("Bad Request".utf8)

        let (data, response) = try ResponseBuilder.error(statusCode: 400, message: "Bad Request", url: url)

        #expect(data == errorData)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 400)
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
    @Test("204レスポンスが空のデータを返す")
    func testNoContentResponseReturnsEmptyData() throws {
        let url = URL(string: "https://example.com")!

        let (data, response) = try ResponseBuilder.noContent(url: url)

        #expect(data.isEmpty)

        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 204)
    }

    // MARK: - Integration Tests
    // Note: Full integration tests with URLSession are covered in Examples/TodoApp/Tests
}
