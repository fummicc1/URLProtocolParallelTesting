import Testing
import Foundation
import URLProtocolParallelTesting
@testable import TodoApp

@Suite("TodoAPI Tests - Demonstrating Parallel Test Execution")
struct TodoAPITests {

    // MARK: - Test Configuration

    /// Creates a TodoAPI instance configured with TestURLSession
    /// This allows us to mock HTTP responses using URLProtocolParallelTesting
    private func makeTestAPI(testId: UUID) -> TodoAPI {
        let session = TestURLSession(testId: testId)
        return TodoAPI(baseURL: "https://api.example.com", session: session)
    }

    // MARK: - Single Request Tests

    @Test("fetchTodos returns list of todos")
    func testFetchTodos() async throws {
        let testId = UUID()

        // Register mock response
        let mockTodos = [
            Todo(id: 1, title: "Buy groceries", completed: false, userId: 1),
            Todo(id: 2, title: "Walk the dog", completed: true, userId: 1)
        ]

        await MockURLProtocolRegistry.shared.register(id: testId) { request in
            try ResponseBuilder.json(mockTodos, url: request.url!)
        }

        // Execute test
        let api = makeTestAPI(testId: testId)
        do {
            let todos = try await api.fetchTodos()
            #expect(todos.count == 2)
            #expect(todos[0].title == "Buy groceries")
            #expect(todos[1].title == "Walk the dog")
        } catch {
            Issue.record("Failed to fetch todos: \(error)")
        }

        await MockURLProtocolRegistry.shared.unregister(id: testId)
    }

    @Test("fetchTodo returns single todo by ID")
    func testFetchTodoById() async throws {
        let testId = UUID()

        let mockTodo = Todo(id: 42, title: "Test todo", completed: false, userId: 1)

        await MockURLProtocolRegistry.shared.register(id: testId) { request in
            // Verify the URL contains the correct ID
            #expect(request.url?.absoluteString.contains("/todos/42") ?? false)
            return try ResponseBuilder.json(mockTodo, url: request.url!)
        }

        let api = makeTestAPI(testId: testId)
        do {
            let todo = try await api.fetchTodo(id: 42)
            #expect(todo.id == 42)
            #expect(todo.title == "Test todo")
        } catch {
            Issue.record("Failed to fetch todo: \(error)")
        }

        await MockURLProtocolRegistry.shared.unregister(id: testId)
    }

    @Test("createTodo sends POST request and returns created todo")
    func testCreateTodo() async throws {
        let testId = UUID()

        let request = CreateTodoRequest(title: "New todo", completed: false, userId: 1)
        let createdTodo = Todo(id: 201, title: "New todo", completed: false, userId: 1)

        await MockURLProtocolRegistry.shared.register(id: testId) { urlRequest in
            // Verify POST method
            #expect(urlRequest.httpMethod == "POST")
            #expect(urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")

            // Verify request body
            if let body = urlRequest.httpBody {
                let decoder = JSONDecoder()
                let decodedRequest = try? decoder.decode(CreateTodoRequest.self, from: body)
                #expect(decodedRequest?.title == "New todo")
            }

            return try ResponseBuilder.json(createdTodo, statusCode: 201, url: urlRequest.url!)
        }

        let api = makeTestAPI(testId: testId)
        do {
            let todo = try await api.createTodo(request)
            #expect(todo.id == 201)
            #expect(todo.title == "New todo")
        } catch {
            Issue.record("Failed to create todo: \(error)")
        }

        await MockURLProtocolRegistry.shared.unregister(id: testId)
    }

    @Test("updateTodo sends PUT request and returns updated todo")
    func testUpdateTodo() async throws {
        let testId = UUID()

        let update = UpdateTodoRequest(title: "Updated title", completed: true)
        let updatedTodo = Todo(id: 1, title: "Updated title", completed: true, userId: 1)

        await MockURLProtocolRegistry.shared.register(id: testId) { request in
            #expect(request.httpMethod == "PUT")
            #expect(request.url?.absoluteString.contains("/todos/1") ?? false)
            return try ResponseBuilder.json(updatedTodo, url: request.url!)
        }

        let api = makeTestAPI(testId: testId)
        do {
            let todo = try await api.updateTodo(id: 1, update: update)
            #expect(todo.title == "Updated title")
            #expect(todo.completed == true)
        } catch {
            Issue.record("Failed to update todo: \(error)")
        }

        await MockURLProtocolRegistry.shared.unregister(id: testId)
    }

    @Test("deleteTodo sends DELETE request")
    func testDeleteTodo() async throws {
        let testId = UUID()

        await MockURLProtocolRegistry.shared.register(id: testId) { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.url?.absoluteString.contains("/todos/1") ?? false)
            return try ResponseBuilder.noContent(url: request.url!)
        }

        let api = makeTestAPI(testId: testId)
        do {
            try await api.deleteTodo(id: 1)
            // Success - no error thrown
        } catch {
            Issue.record("Failed to delete todo: \(error)")
        }

        await MockURLProtocolRegistry.shared.unregister(id: testId)
    }

    // MARK: - Error Handling Tests

    @Test("fetchTodos handles 404 error")
    func testFetchTodosNotFound() async throws {
        let testId = UUID()

        await MockURLProtocolRegistry.shared.register(id: testId) { request in
            try ResponseBuilder.error(statusCode: 404, message: "Not found", url: request.url!)
        }

        let api = makeTestAPI(testId: testId)
        do {
            _ = try await api.fetchTodos()
            Issue.record("Expected error but request succeeded")
        } catch let error as TodoAPIError {
            if case .httpError(let statusCode) = error {
                #expect(statusCode == 404)
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        await MockURLProtocolRegistry.shared.unregister(id: testId)
    }

    @Test("fetchTodos handles 500 server error")
    func testFetchTodosServerError() async throws {
        let testId = UUID()

        await MockURLProtocolRegistry.shared.register(id: testId) { request in
            try ResponseBuilder.error(statusCode: 500, message: "Internal server error", url: request.url!)
        }

        let api = makeTestAPI(testId: testId)
        do {
            _ = try await api.fetchTodos()
            Issue.record("Expected error but request succeeded")
        } catch let error as TodoAPIError {
            if case .httpError(let statusCode) = error {
                #expect(statusCode == 500)
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        await MockURLProtocolRegistry.shared.unregister(id: testId)
    }

    // MARK: - Parallel Execution Tests
    // These tests demonstrate that multiple tests can run simultaneously
    // without interfering with each other

    @Test("Parallel Test 1: Fetch todo #1")
    func testParallel1() async throws {
        let testId = UUID()
        let mockTodo = Todo(id: 1, title: "Parallel Task 1", completed: false, userId: 1)

        await MockURLProtocolRegistry.shared.register(id: testId) { request in
            try ResponseBuilder.json(mockTodo, url: request.url!)
        }

        let api = makeTestAPI(testId: testId)
        do {
            let todo = try await api.fetchTodo(id: 1)
            #expect(todo.title == "Parallel Task 1")
        } catch {
            Issue.record("Test failed: \(error)")
        }

        await MockURLProtocolRegistry.shared.unregister(id: testId)
    }

    @Test("Parallel Test 2: Fetch todo #2")
    func testParallel2() async throws {
        let testId = UUID()
        let mockTodo = Todo(id: 2, title: "Parallel Task 2", completed: false, userId: 1)

        await MockURLProtocolRegistry.shared.register(id: testId) { request in
            try ResponseBuilder.json(mockTodo, url: request.url!)
        }

        let api = makeTestAPI(testId: testId)
        do {
            let todo = try await api.fetchTodo(id: 2)
            #expect(todo.title == "Parallel Task 2")
        } catch {
            Issue.record("Test failed: \(error)")
        }

        await MockURLProtocolRegistry.shared.unregister(id: testId)
    }

    @Test("Parallel Test 3: Fetch todo #3")
    func testParallel3() async throws {
        let testId = UUID()
        let mockTodo = Todo(id: 3, title: "Parallel Task 3", completed: false, userId: 1)

        await MockURLProtocolRegistry.shared.register(id: testId) { request in
            try ResponseBuilder.json(mockTodo, url: request.url!)
        }

        let api = makeTestAPI(testId: testId)
        do {
            let todo = try await api.fetchTodo(id: 3)
            #expect(todo.title == "Parallel Task 3")
        } catch {
            Issue.record("Test failed: \(error)")
        }

        await MockURLProtocolRegistry.shared.unregister(id: testId)
    }

    @Test("Parallel Test 4: Create todo")
    func testParallel4() async throws {
        let testId = UUID()
        let request = CreateTodoRequest(title: "Parallel Creation", userId: 1)
        let createdTodo = Todo(id: 100, title: "Parallel Creation", completed: false, userId: 1)

        await MockURLProtocolRegistry.shared.register(id: testId) { urlRequest in
            try ResponseBuilder.json(createdTodo, statusCode: 201, url: urlRequest.url!)
        }

        let api = makeTestAPI(testId: testId)
        do {
            let todo = try await api.createTodo(request)
            #expect(todo.title == "Parallel Creation")
        } catch {
            Issue.record("Test failed: \(error)")
        }

        await MockURLProtocolRegistry.shared.unregister(id: testId)
    }

    @Test("Parallel Test 5: Update todo")
    func testParallel5() async throws {
        let testId = UUID()
        let update = UpdateTodoRequest(completed: true)
        let updatedTodo = Todo(id: 5, title: "Original", completed: true, userId: 1)

        await MockURLProtocolRegistry.shared.register(id: testId) { urlRequest in
            try ResponseBuilder.json(updatedTodo, url: urlRequest.url!)
        }

        let api = makeTestAPI(testId: testId)
        do {
            let todo = try await api.updateTodo(id: 5, update: update)
            #expect(todo.completed == true)
        } catch {
            Issue.record("Test failed: \(error)")
        }

        await MockURLProtocolRegistry.shared.unregister(id: testId)
    }

    // MARK: - Sequential Request Tests
    // These tests demonstrate handling multiple requests within a single test

    @Test("Sequential requests: Create, Fetch, Update, Delete", .serialized)
    func testSequentialRequests() async throws {
        let testId = UUID()

        // Register handlers in FIFO order
        let createRequest = CreateTodoRequest(title: "Sequential Test", userId: 1)
        let createdTodo = Todo(id: 999, title: "Sequential Test", completed: false, userId: 1)
        let updatedTodo = Todo(id: 999, title: "Sequential Test", completed: true, userId: 1)

        // Handler 1: Create
        await MockURLProtocolRegistry.shared.register(id: testId) { urlRequest in
            try ResponseBuilder.json(createdTodo, statusCode: 201, url: urlRequest.url!)
        }

        // Handler 2: Fetch
        await MockURLProtocolRegistry.shared.register(id: testId) { urlRequest in
            try ResponseBuilder.json(createdTodo, url: urlRequest.url!)
        }

        // Handler 3: Update
        await MockURLProtocolRegistry.shared.register(id: testId) { urlRequest in
            try ResponseBuilder.json(updatedTodo, url: urlRequest.url!)
        }

        // Handler 4: Delete
        await MockURLProtocolRegistry.shared.register(id: testId) { urlRequest in
            try ResponseBuilder.noContent(url: urlRequest.url!)
        }

        let api = makeTestAPI(testId: testId)
        do {
            // Step 1: Create
            let created = try await api.createTodo(createRequest)
            #expect(created.id == 999)
            #expect(created.completed == false)

            // Step 2: Fetch
            let fetched = try await api.fetchTodo(id: 999)
            #expect(fetched.id == 999)

            // Step 3: Update
            let update = UpdateTodoRequest(completed: true)
            let updated = try await api.updateTodo(id: 999, update: update)
            #expect(updated.completed == true)

            // Step 4: Delete
            try await api.deleteTodo(id: 999)
        } catch {
            Issue.record("Sequential request test failed: \(error)")
        }

        await MockURLProtocolRegistry.shared.unregister(id: testId)
    }
}
