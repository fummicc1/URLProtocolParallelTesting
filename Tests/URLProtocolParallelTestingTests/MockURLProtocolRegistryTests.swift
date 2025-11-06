import Testing
import Foundation
@testable import URLProtocolParallelTesting

@Suite("MockURLProtocolRegistry Tests", .serialized)
struct MockURLProtocolRegistryTests {

    // Helper for capturing values in @Sendable closures
    final class Box<T>: @unchecked Sendable {
        var value: T?
        init(_ value: T? = nil) {
            self.value = value
        }
    }

    // MARK: - Registration Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("単一のハンドラーを登録できる")
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func testRegisterSingleHandler() async throws {
        let registry = MockURLProtocolRegistry.shared
        let testId = UUID()

        let handler: MockURLProtocolRegistry.RequestHandler = { _ in
            (Data(), URLResponse())
        }

        await registry.register(id: testId, handler: handler)

        let retrievedHandler = await registry.getHandler(for: testId)
        #expect(retrievedHandler != nil)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("複数のハンドラーをFIFO順で登録できる")
    func testRegisterMultipleHandlersInFIFOOrder() async throws {
        let registry = MockURLProtocolRegistry.shared
        let testId = UUID()

        let callOrder = Box<[Int]>()
        callOrder.value = []

        let handler1: MockURLProtocolRegistry.RequestHandler = { _ in
            callOrder.value!.append(1)
            return (Data(), URLResponse())
        }

        let handler2: MockURLProtocolRegistry.RequestHandler = { _ in
            callOrder.value!.append(2)
            return (Data(), URLResponse())
        }

        let handler3: MockURLProtocolRegistry.RequestHandler = { _ in
            callOrder.value!.append(3)
            return (Data(), URLResponse())
        }

        await registry.register(id: testId, handler: handler1)
        await registry.register(id: testId, handler: handler2)
        await registry.register(id: testId, handler: handler3)

        // Retrieve handlers in FIFO order
        let retrieved1 = await registry.getHandler(for: testId)
        _ = try retrieved1?(URLRequest(url: URL(string: "https://example.com")!))

        let retrieved2 = await registry.getHandler(for: testId)
        _ = try retrieved2?(URLRequest(url: URL(string: "https://example.com")!))

        let retrieved3 = await registry.getHandler(for: testId)
        _ = try retrieved3?(URLRequest(url: URL(string: "https://example.com")!))

        #expect(callOrder.value == [1, 2, 3])
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("異なるテストIDで独立したハンドラーを登録できる")
    func testRegisterHandlersForDifferentTestIds() async throws {
        let registry = MockURLProtocolRegistry.shared
        let testId1 = UUID()
        let testId2 = UUID()

        let callCount1 = Box<Int>()
        callCount1.value = 0
        let callCount2 = Box<Int>()
        callCount2.value = 0

        let handler1: MockURLProtocolRegistry.RequestHandler = { _ in
            callCount1.value! += 1
            return (Data(), URLResponse())
        }

        let handler2: MockURLProtocolRegistry.RequestHandler = { _ in
            callCount2.value! += 1
            return (Data(), URLResponse())
        }

        await registry.register(id: testId1, handler: handler1)
        await registry.register(id: testId2, handler: handler2)

        let retrieved1 = await registry.getHandler(for: testId1)
        _ = try retrieved1?(URLRequest(url: URL(string: "https://example.com")!))

        let retrieved2 = await registry.getHandler(for: testId2)
        _ = try retrieved2?(URLRequest(url: URL(string: "https://example.com")!))

        #expect(callCount1.value == 1)
        #expect(callCount2.value == 1)
    }

    // MARK: - Retrieval Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("登録されていないテストIDに対してnilを返す")
    func testGetHandlerForUnregisteredTestId() async throws {
        let registry = MockURLProtocolRegistry.shared
        let testId = UUID()

        let handler = await registry.getHandler(for: testId)
        #expect(handler == nil)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("ハンドラー取得後にキューから削除される")
    func testHandlerRemovedAfterRetrieval() async throws {
        let registry = MockURLProtocolRegistry.shared
        let testId = UUID()

        let handler: MockURLProtocolRegistry.RequestHandler = { _ in
            (Data(), URLResponse())
        }

        await registry.register(id: testId, handler: handler)

        let retrieved1 = await registry.getHandler(for: testId)
        #expect(retrieved1 != nil)

        let retrieved2 = await registry.getHandler(for: testId)
        #expect(retrieved2 == nil)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("キューが空になった後に新しいハンドラーを登録できる")
    func testRegisterAfterQueueEmpty() async throws {
        let registry = MockURLProtocolRegistry.shared
        let testId = UUID()

        let handler1: MockURLProtocolRegistry.RequestHandler = { _ in
            (Data("first".utf8), URLResponse())
        }

        await registry.register(id: testId, handler: handler1)
        _ = await registry.getHandler(for: testId)

        let handler2: MockURLProtocolRegistry.RequestHandler = { _ in
            (Data("second".utf8), URLResponse())
        }

        await registry.register(id: testId, handler: handler2)
        let retrieved = await registry.getHandler(for: testId)
        #expect(retrieved != nil)
    }

    // MARK: - Unregister Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("特定のテストIDのハンドラーキューを削除できる")
    func testUnregisterTestId() async throws {
        let registry = MockURLProtocolRegistry.shared
        let testId = UUID()

        let handler: MockURLProtocolRegistry.RequestHandler = { _ in
            (Data(), URLResponse())
        }

        await registry.register(id: testId, handler: handler)
        await registry.unregister(id: testId)

        let retrieved = await registry.getHandler(for: testId)
        #expect(retrieved == nil)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("存在しないテストIDをunregisterしてもエラーにならない")
    func testUnregisterNonExistentTestId() async throws {
        let registry = MockURLProtocolRegistry.shared
        let testId = UUID()

        // Should not throw
        await registry.unregister(id: testId)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("unregister後に他のテストIDは影響を受けない")
    func testUnregisterDoesNotAffectOtherTestIds() async throws {
        let registry = MockURLProtocolRegistry.shared
        let testId1 = UUID()
        let testId2 = UUID()

        let handler1: MockURLProtocolRegistry.RequestHandler = { _ in
            (Data(), URLResponse())
        }

        let handler2: MockURLProtocolRegistry.RequestHandler = { _ in
            (Data(), URLResponse())
        }

        await registry.register(id: testId1, handler: handler1)
        await registry.register(id: testId2, handler: handler2)

        await registry.unregister(id: testId1)

        let retrieved1 = await registry.getHandler(for: testId1)
        let retrieved2 = await registry.getHandler(for: testId2)

        #expect(retrieved1 == nil)
        #expect(retrieved2 != nil)
    }

    // MARK: - Clear Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("すべてのハンドラーをクリアできる")
    func testClearAllHandlers() async throws {
        let registry = MockURLProtocolRegistry.shared
        let testId1 = UUID()
        let testId2 = UUID()

        let handler: MockURLProtocolRegistry.RequestHandler = { _ in
            (Data(), URLResponse())
        }

        await registry.register(id: testId1, handler: handler)
        await registry.register(id: testId2, handler: handler)

        await registry.clear()

        let retrieved1 = await registry.getHandler(for: testId1)
        let retrieved2 = await registry.getHandler(for: testId2)

        #expect(retrieved1 == nil)
        #expect(retrieved2 == nil)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("clear後に新しいハンドラーを登録できる")
    func testRegisterAfterClear() async throws {
        let registry = MockURLProtocolRegistry.shared
        let testId = UUID()

        let handler1: MockURLProtocolRegistry.RequestHandler = { _ in
            (Data(), URLResponse())
        }

        await registry.register(id: testId, handler: handler1)
        await registry.clear()

        let handler2: MockURLProtocolRegistry.RequestHandler = { _ in
            (Data(), URLResponse())
        }

        await registry.register(id: testId, handler: handler2)
        let retrieved = await registry.getHandler(for: testId)

        #expect(retrieved != nil)
    }

    // MARK: - Concurrency Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("並列アクセス時にスレッドセーフである")
    func testConcurrentAccess() async throws {
        let registry = MockURLProtocolRegistry.shared
        let testIds = (0..<10).map { _ in UUID() }

        await withTaskGroup(of: Void.self) { group in
            for testId in testIds {
                group.addTask {
                    let handler: MockURLProtocolRegistry.RequestHandler = { _ in
                        (Data(), URLResponse())
                    }
                    await registry.register(id: testId, handler: handler)
                }
            }
        }

        var retrievedCount = 0
        for testId in testIds {
            if await registry.getHandler(for: testId) != nil {
                retrievedCount += 1
            }
        }

        #expect(retrievedCount == testIds.count)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("同一テストIDへの並列登録が正しく処理される")
    func testConcurrentRegistrationForSameTestId() async throws {
        let registry = MockURLProtocolRegistry.shared
        let testId = UUID()
        let registrationCount = 10

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<registrationCount {
                group.addTask {
                    let handler: MockURLProtocolRegistry.RequestHandler = { _ in
                        (Data("\(i)".utf8), URLResponse())
                    }
                    await registry.register(id: testId, handler: handler)
                }
            }
        }

        var retrievedCount = 0
        for _ in 0..<registrationCount {
            if await registry.getHandler(for: testId) != nil {
                retrievedCount += 1
            }
        }

        #expect(retrievedCount == registrationCount)
    }

    // MARK: - Shared Instance Tests

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @Test("sharedインスタンスが同一である")
    func testSharedInstanceIsSingleton() async throws {
        let instance1 = MockURLProtocolRegistry.shared
        let instance2 = MockURLProtocolRegistry.shared

        // Swift actor doesn't support identity comparison directly,
        // but we can verify behavior by registering on one and retrieving on the other
        let testId = UUID()
        let handler: MockURLProtocolRegistry.RequestHandler = { _ in
            (Data(), URLResponse())
        }

        await instance1.register(id: testId, handler: handler)
        let retrieved = await instance2.getHandler(for: testId)

        #expect(retrieved != nil)
    }
}
