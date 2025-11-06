# TodoApp Example

This example demonstrates how to use [URLProtocolParallelTesting](../..) library to write parallel-safe network tests for a simple Todo API client.

## Overview

This example includes:

- **Production Code** (`Sources/TodoApp/`)
  - `TodoAPI.swift` - A simple HTTP client for Todo operations (GET, POST, PUT, DELETE)
  - `Models.swift` - Data models for Todo items and requests

- **Test Code** (`Tests/TodoAppTests/`)
  - `TodoAPITests.swift` - Comprehensive test suite demonstrating:
    - Single request mocking
    - Error handling
    - **Parallel test execution** (5+ tests running simultaneously)
    - Sequential multi-request scenarios

## Key Features Demonstrated

### 1. Simple Test Setup

```swift
private func makeTestAPI(testId: UUID) -> TodoAPI {
    let config = URLSessionConfiguration.ephemeral
    let session = TestableURLSession(configuration: config)
    return TodoAPI(baseURL: "https://api.example.com", session: session.urlSession)
}
```

### 2. Mocking HTTP Responses

```swift
@Test("fetchTodos returns list of todos")
func testFetchTodos() async throws {
    let testId = UUID()

    // Register mock response
    let mockTodos = [
        Todo(id: 1, title: "Buy groceries", completed: false, userId: 1)
    ]

    await MockURLProtocolRegistry.shared.register(id: testId) { request in
        try ResponseBuilder.json(mockTodos)
    }

    // Execute test within TestContext
    await TestContext.$current.withValue(testId) {
        let api = makeTestAPI(testId: testId)
        let todos = try await api.fetchTodos()
        #expect(todos.count == 1)
    }

    await MockURLProtocolRegistry.shared.clear()
}
```

### 3. Parallel Test Isolation

The library allows multiple tests to run in parallel without interference:

```swift
// These tests can run simultaneously
@Test("Parallel Test 1: Fetch todo #1")
func testParallel1() async throws { ... }

@Test("Parallel Test 2: Fetch todo #2")
func testParallel2() async throws { ... }

@Test("Parallel Test 3: Fetch todo #3")
func testParallel3() async throws { ... }
```

Each test has its own UUID and isolated mock handlers, ensuring no cross-test pollution.

### 4. Sequential Multi-Request Scenarios

You can test workflows with multiple requests:

```swift
@Test("Sequential requests: Create, Fetch, Update, Delete")
func testSequentialRequests() async throws {
    let testId = UUID()

    // Register handlers in FIFO order
    await MockURLProtocolRegistry.shared.register(id: testId) { _ in
        try ResponseBuilder.json(createdTodo, statusCode: 201) // Handler 1
    }
    await MockURLProtocolRegistry.shared.register(id: testId) { _ in
        try ResponseBuilder.json(createdTodo) // Handler 2
    }
    await MockURLProtocolRegistry.shared.register(id: testId) { _ in
        try ResponseBuilder.json(updatedTodo) // Handler 3
    }
    await MockURLProtocolRegistry.shared.register(id: testId) { _ in
        try ResponseBuilder.noContent() // Handler 4
    }

    await TestContext.$current.withValue(testId) {
        let api = makeTestAPI(testId: testId)

        let created = try await api.createTodo(request)  // Uses Handler 1
        let fetched = try await api.fetchTodo(id: 999)   // Uses Handler 2
        let updated = try await api.updateTodo(...)      // Uses Handler 3
        try await api.deleteTodo(id: 999)                // Uses Handler 4
    }
}
```

Handlers are consumed in FIFO order per test ID.

## Running the Tests

### From Command Line

```bash
cd Examples/TodoApp
swift test
```

### From Xcode

1. Open the package in Xcode:
   ```bash
   cd Examples/TodoApp
   open Package.swift
   ```

2. Press `⌘U` to run all tests

### Enable Parallel Test Execution

Swift Testing runs tests in parallel by default. You can verify this by observing that multiple tests complete simultaneously.

To see the parallelization in action, you can add timing logs:

```swift
@Test("Parallel Test 1")
func testParallel1() async throws {
    print("Test 1 started at \(Date())")
    // ... test code ...
    print("Test 1 finished at \(Date())")
}
```

## Test Results

The test suite includes:

- **8 Single Request Tests** - Basic CRUD operations
- **2 Error Handling Tests** - 404 and 500 responses
- **5 Parallel Execution Tests** - Demonstrating isolation
- **1 Sequential Request Test** - Multi-step workflow

**Total: 16 tests**

## Integration with Production Code

The only change required in production code is replacing `URLSession` with `TestableURLSession`:

```swift
// Before (production)
let api = TodoAPI(baseURL: "https://api.example.com")

// After (testable)
let session = TestableURLSession()
let api = TodoAPI(baseURL: "https://api.example.com", session: session.urlSession)
```

This minimal change enables full parallel test support.

## Benefits Demonstrated

1. **Thread Safety** - Multiple tests run simultaneously without race conditions
2. **Clean Isolation** - Each test has its own mock handlers
3. **Simple API** - Easy to understand and use
4. **FIFO Queuing** - Natural support for multi-request scenarios
5. **Minimal Integration** - Small changes to production code

## Next Steps

- Run `swift test` to see all tests pass
- Try adding your own test cases
- Experiment with different response scenarios
- Measure test execution time with and without parallelization

## License

This example is part of the URLProtocolParallelTesting project and is licensed under the MIT License.
