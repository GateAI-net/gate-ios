# Making Requests

Learn how to make authenticated API requests through the Gate/AI proxy.

## Overview

The Gate/AI SDK provides multiple ways to make authenticated requests to APIs proxied through your Gate/AI tenant. All methods automatically handle authentication, DPoP proof generation, and nonce challenges.

## Using performProxyRequest (Recommended)

The simplest way to make requests is using ``GateAIClient/performProxyRequest(path:method:body:additionalHeaders:)``:

```swift
let requestBody = """
{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hello, world!"}]
}
""".data(using: .utf8)!

let (data, response) = try await client.performProxyRequest(
    path: "openai/chat/completions",
    method: .post,
    body: requestBody,
    additionalHeaders: ["Content-Type": "application/json"]
)

// Process the response
if response.statusCode == 200 {
    let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
    print(chatResponse.choices.first?.message.content ?? "")
}
```

This method:
- Automatically obtains a valid access token
- Generates the DPoP proof for the request
- Handles 401 responses with nonce challenges
- Returns the raw data and HTTP response for maximum flexibility

## Using Authorization Headers

For more control over the request, get authorization headers and construct your own `URLRequest`:

```swift
// Get headers for a specific path
let headers = try await client.authorizationHeaders(
    for: "openai/chat/completions",
    method: .post
)

// Construct your request
var request = URLRequest(url: URL(string: "https://yourteam.us01.gate-ai.net/openai/chat/completions")!)
request.httpMethod = "POST"
request.httpBody = requestBody

// Add Gate/AI headers
headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

// Add your own headers
request.setValue("application/json", forHTTPHeaderField: "Content-Type")

// Make the request
let (data, response) = try await URLSession.shared.data(for: request)
```

The authorization headers include:
- `Authorization`: Bearer token with the access token
- `DPoP`: The DPoP proof JWT for this specific request

## Making GET Requests

For GET requests, omit the body:

```swift
let (data, response) = try await client.performProxyRequest(
    path: "openai/models",
    method: .get
)

let models = try JSONDecoder().decode(ModelsResponse.self, from: data)
```

## Working with Different Content Types

### JSON Requests

```swift
// Using Codable
struct ChatRequest: Codable {
    let model: String
    let messages: [Message]
}

let request = ChatRequest(
    model: "gpt-4",
    messages: [Message(role: "user", content: "Hello!")]
)

let body = try JSONEncoder().encode(request)

let (data, response) = try await client.performProxyRequest(
    path: "openai/chat/completions",
    method: .post,
    body: body,
    additionalHeaders: ["Content-Type": "application/json"]
)
```

### Streaming Responses

For server-sent events or streaming responses:

```swift
// Get authorization headers
let headers = try await client.authorizationHeaders(
    for: "openai/chat/completions",
    method: .post
)

// Create URLRequest
var request = URLRequest(url: configuration.baseURL.appendingPathComponent("openai/chat/completions"))
request.httpMethod = "POST"
request.httpBody = requestBody
headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
request.setValue("application/json", forHTTPHeaderField: "Content-Type")

// Use URLSession with bytes stream
let (bytes, response) = try await URLSession.shared.bytes(for: request)

for try await line in bytes.lines {
    if line.hasPrefix("data: ") {
        let jsonData = line.dropFirst(6)
        // Process each chunk
    }
}
```

## Handling Nonce Challenges

The ``GateAIClient/performProxyRequest(path:method:body:additionalHeaders:)`` method automatically handles nonce challenges. If you're making requests manually, handle them like this:

```swift
do {
    // First attempt
    var headers = try await client.authorizationHeaders(for: "openai/chat/completions", method: .post)
    let (data, response) = try await makeRequest(with: headers)

} catch let error {
    // Check for nonce challenge
    if let nonce = client.extractDPoPNonce(from: error) {
        // Retry with nonce
        let headers = try await client.authorizationHeaders(
            for: "openai/chat/completions",
            method: .post,
            nonce: nonce
        )
        let (data, response) = try await makeRequest(with: headers)
    } else {
        throw error
    }
}
```

## Error Handling

Handle errors appropriately for different scenarios:

```swift
do {
    let (data, response) = try await client.performProxyRequest(
        path: "openai/chat/completions",
        method: .post,
        body: requestBody,
        additionalHeaders: ["Content-Type": "application/json"]
    )

    // Check status code
    guard response.statusCode == 200 else {
        print("Unexpected status code: \(response.statusCode)")
        return
    }

    // Process successful response
    let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

} catch let error as GateAIError {
    switch error {
    case .server(let statusCode, let serverError, _):
        if serverError?.error == "rate_limited" {
            print("Rate limited. Please try again later.")
        } else if serverError?.error == "device_blocked" {
            print("This device has been blocked.")
        } else {
            print("Server error \(statusCode): \(serverError?.errorDescription ?? "")")
        }

    case .network(let underlying):
        print("Network error: \(underlying.localizedDescription)")

    case .attestationFailed(let message):
        print("Attestation failed: \(message)")

    default:
        print("Error: \(error.localizedDescription)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## Performance Tips

### Token Reuse

The SDK caches access tokens in memory and reuses them across requests. Tokens are refreshed automatically 60 seconds before expiry.

### Concurrent Requests

The SDK is thread-safe and handles concurrent requests efficiently:

```swift
// Multiple requests in parallel
async let response1 = client.performProxyRequest(path: "openai/models", method: .get)
async let response2 = client.performProxyRequest(path: "openai/chat/completions", method: .post, body: body1)
async let response3 = client.performProxyRequest(path: "openai/chat/completions", method: .post, body: body2)

let results = try await (response1, response2, response3)
```

If multiple requests need a token simultaneously, they share the same token acquisition operation.

### Logging for Debugging

Enable debug logging to see full request/response details:

```swift
let configuration = try GateAIConfiguration(
    baseURLString: "https://yourteam.us01.gate-ai.net",
    teamIdentifier: "ABCDE12345",
    logLevel: .debug  // Enable detailed logging
)
```

Debug logs include:
- Full request URLs and headers (sensitive values redacted)
- Request bodies
- Response status codes and headers
- Response bodies (formatted JSON when possible)

## See Also

- ``GateAIClient/performProxyRequest(path:method:body:additionalHeaders:)``
- ``GateAIClient/authorizationHeaders(for:method:nonce:)-8tkvs``
- ``HTTPMethod``
- <doc:ErrorHandling>
