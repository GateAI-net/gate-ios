# Error Handling

Learn how to handle errors when using the Gate/AI SDK.

## Overview

All errors thrown by the Gate/AI SDK are instances of ``GateAIError``. This enum provides detailed information about what went wrong and, where applicable, includes underlying errors and server responses.

## Error Categories

### Configuration Errors

Configuration errors occur during initialization when invalid values are provided:

```swift
do {
    let configuration = try GateAIConfiguration(
        baseURLString: "not-a-valid-url",
        teamIdentifier: "INVALID",
        logLevel: .info
    )
} catch GateAIError.configuration(let message) {
    print("Configuration error: \(message)")
    // Example messages:
    // - "Invalid base URL: 'not-a-valid-url'"
    // - "teamIdentifier must be exactly 10 characters"
    // - "bundleIdentifier cannot be empty"
}
```

### Attestation Errors

Attestation errors occur when device attestation fails:

```swift
do {
    try await client.performProxyRequest(...)
} catch GateAIError.attestationUnavailable {
    print("App Attest is not supported on this device")
    // Solution: Use a physical device or configure a development token

} catch GateAIError.attestationFailed(let message) {
    print("Attestation failed: \(message)")
    // Possible causes:
    // - Invalid App Attest key
    // - Device not registered with tenant
    // - Team ID mismatch

    // Try resetting the App Attest key
    try? client.clearAppAttestKey()

} catch GateAIError.secureEnclaveUnavailable {
    print("Secure Enclave is not available")
    // This device doesn't support Secure Enclave operations
}
```

### Network Errors

Network errors wrap underlying URLSession errors:

```swift
do {
    try await client.performProxyRequest(...)
} catch GateAIError.network(let underlying) {
    print("Network error: \(underlying.localizedDescription)")

    // Check for specific network conditions
    if let urlError = underlying as? URLError {
        switch urlError.code {
        case .notConnectedToInternet:
            print("No internet connection")
        case .timedOut:
            print("Request timed out")
        case .cannotFindHost:
            print("Cannot reach server")
        default:
            print("Network error: \(urlError.localizedDescription)")
        }
    }
}
```

### Server Errors

Server errors include the HTTP status code and optional structured error information:

```swift
do {
    try await client.performProxyRequest(...)
} catch GateAIError.server(let statusCode, let serverError, let headers) {
    print("Server returned status \(statusCode)")

    // Check structured error information
    if let serverError = serverError {
        print("Error code: \(serverError.error)")
        print("Description: \(serverError.errorDescription ?? "")")

        // Handle specific server errors
        switch serverError.error {
        case "device_blocked":
            print("This device has been blocked by your tenant administrator")
            // Show user message about blocked device

        case "rate_limited":
            print("Too many requests. Please try again later.")
            // Implement backoff strategy

        case "invalid_token":
            print("Token is invalid or expired")
            // Clear cached state and retry
            await client.clearCachedState()

        case "nonce_expired":
            print("DPoP nonce expired")
            // The SDK should retry automatically, but you can extract the nonce
            if let nonce = headers?["DPoP-Nonce"] {
                print("New nonce: \(nonce)")
            }

        default:
            print("Unhandled server error: \(serverError.error)")
        }
    }

    // 401 with DPoP-Nonce header
    if statusCode == 401, let nonce = headers?["DPoP-Nonce"] {
        print("Server requested DPoP nonce: \(nonce)")
        // The performProxyRequest method handles this automatically
    }
}
```

### Response Decoding Errors

Decoding errors occur when the server response cannot be parsed:

```swift
do {
    let (data, response) = try await client.performProxyRequest(...)
    let result = try JSONDecoder().decode(MyResponse.self, from: data)

} catch GateAIError.decoding(let underlying) {
    print("Failed to decode response: \(underlying.localizedDescription)")
    // The server returned valid data, but it doesn't match the expected type
}
```

## Comprehensive Error Handling

Here's a complete example showing how to handle all error types:

```swift
func makeAuthenticatedRequest() async {
    do {
        let (data, response) = try await client.performProxyRequest(
            path: "openai/chat/completions",
            method: .post,
            body: requestBody,
            additionalHeaders: ["Content-Type": "application/json"]
        )

        guard response.statusCode == 200 else {
            print("Unexpected status: \(response.statusCode)")
            return
        }

        let result = try JSONDecoder().decode(ChatResponse.self, from: data)
        print("Success: \(result)")

    } catch let error as GateAIError {
        switch error {
        case .configuration(let message):
            fatalError("Invalid configuration: \(message)")

        case .attestationUnavailable:
            showError("App Attest is not available. Please use a physical device.")

        case .attestationFailed(let message):
            showError("Device attestation failed: \(message)")
            try? client.clearAppAttestKey()

        case .secureEnclaveUnavailable:
            showError("This device doesn't support required security features.")

        case .network(let underlying):
            handleNetworkError(underlying)

        case .server(let statusCode, let serverError, _):
            handleServerError(statusCode: statusCode, error: serverError)

        case .decoding(let underlying):
            logError("Failed to decode response: \(underlying)")

        case .invalidResponse:
            logError("Received invalid response from server")

        case .tokenMissing:
            // Shouldn't happen in normal use
            await client.clearCachedState()
        }
    } catch {
        // Unexpected error
        logError("Unexpected error: \(error)")
    }
}

func handleNetworkError(_ error: Error) {
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet:
            showError("No internet connection")
        case .timedOut:
            showError("Request timed out. Please try again.")
        default:
            showError("Network error: \(urlError.localizedDescription)")
        }
    } else {
        showError("Network error occurred")
    }
}

func handleServerError(statusCode: Int, error: ServerErrorResponse?) {
    if let serverError = error {
        switch serverError.error {
        case "device_blocked":
            showError("Your device has been blocked. Please contact support.")
        case "rate_limited":
            showError("Too many requests. Please wait and try again.")
        case "invalid_token":
            Task {
                await client.clearCachedState()
                // Retry the request
            }
        default:
            showError("Server error: \(serverError.errorDescription ?? serverError.error)")
        }
    } else {
        showError("Server returned error \(statusCode)")
    }
}
```

## Retry Strategies

### Simple Retry with Exponential Backoff

```swift
func performRequestWithRetry(maxAttempts: Int = 3) async throws -> Data {
    var lastError: Error?

    for attempt in 1...maxAttempts {
        do {
            let (data, response) = try await client.performProxyRequest(
                path: "openai/chat/completions",
                method: .post,
                body: requestBody
            )

            guard response.statusCode == 200 else {
                throw GateAIError.server(statusCode: response.statusCode, error: nil, headers: nil)
            }

            return data

        } catch GateAIError.server(let statusCode, let serverError, _) where serverError?.error == "rate_limited" {
            lastError = error

            if attempt < maxAttempts {
                let delay = TimeInterval(pow(2.0, Double(attempt)))  // Exponential backoff
                print("Rate limited. Retrying in \(delay) seconds...")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

        } catch GateAIError.network {
            lastError = error

            if attempt < maxAttempts {
                print("Network error. Retrying...")
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
            }
        }
    }

    throw lastError ?? GateAIError.invalidResponse
}
```

## Best Practices

### 1. Always Handle Errors

Never ignore errors from the SDK. At minimum, log them for debugging:

```swift
do {
    try await client.performProxyRequest(...)
} catch {
    print("Gate/AI error: \(error)")
}
```

### 2. Provide User-Friendly Messages

Convert technical errors into user-friendly messages:

```swift
func userFriendlyMessage(for error: GateAIError) -> String {
    switch error {
    case .attestationUnavailable:
        return "Please use a physical device to access this feature."
    case .server(_, let serverError, _) where serverError?.error == "device_blocked":
        return "Your access has been restricted. Please contact support."
    case .network:
        return "Unable to connect. Please check your internet connection."
    default:
        return "An error occurred. Please try again."
    }
}
```

### 3. Log Errors Appropriately

Use appropriate log levels for different errors:

```swift
catch let error as GateAIError {
    switch error {
    case .configuration:
        fatalError("Configuration error: \(error)")  // Should never happen in production
    case .server(let status, _, _) where status >= 500:
        logger.error("Server error: \(error)")  // Server-side issue
    case .network:
        logger.warning("Network error: \(error)")  // Transient issue
    default:
        logger.info("Request failed: \(error)")
    }
}
```

### 4. Clear State When Appropriate

Reset authentication state for recoverable errors:

```swift
catch GateAIError.server(_, let serverError, _) where serverError?.error == "invalid_token" {
    await client.clearCachedState()
    // Retry the request
}

catch GateAIError.attestationFailed {
    try? client.clearAppAttestKey()
    await client.clearCachedState()
    // Retry the request
}
```

## See Also

- ``GateAIError``
- ``ServerErrorResponse``
- ``GateAIClient/clearCachedState()``
- ``GateAIClient/clearAppAttestKey()``
- ``GateAIClient/extractDPoPNonce(from:)``
