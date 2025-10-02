# ``GateAI``

Secure authentication and API gateway client for iOS applications.

## Overview

GateAI is a Swift SDK that provides secure, device-authenticated access to AI APIs and other services through the Gate/AI proxy. It implements OAuth 2.0 + DPoP (Demonstrating Proof-of-Possession) + App Attest for robust device-bound authentication.

### Key Features

- **Automatic Authentication**: Handles the complete OAuth 2.0 + DPoP flow automatically
- **App Attest Integration**: Leverages Apple's App Attest framework for device attestation
- **Secure Enclave**: Stores cryptographic keys in the device's Secure Enclave
- **Token Management**: Automatically refreshes access tokens before expiry
- **DPoP Proofing**: Generates per-request DPoP proofs for enhanced security
- **Nonce Handling**: Automatically retries requests with server-provided nonces
- **Development Support**: Simulator-friendly development token flow

### Getting Started

1. Create a configuration with your Gate/AI tenant details
2. Initialize the client
3. Make authenticated requests

```swift
import GateAI

// Configure the client
let configuration = try GateAIConfiguration(
    baseURLString: "https://yourteam.us01.gate-ai.net",
    teamIdentifier: "ABCDE12345",  // Your Apple Team ID
    logLevel: .info
)

let client = GateAIClient(configuration: configuration)

// Make authenticated requests
let requestBody = """
{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hello!"}]
}
""".data(using: .utf8)!

let (data, response) = try await client.performProxyRequest(
    path: "openai/chat/completions",
    method: .post,
    body: requestBody,
    additionalHeaders: ["Content-Type": "application/json"]
)
```

## Topics

### Essentials

- ``GateAIClient``
- ``GateAIConfiguration``
- ``GateAIError``
- ``HTTPMethod``

### Authentication

- <doc:Authentication>

### Making Requests

- <doc:MakingRequests>

### Logging

- ``GateAILogLevel``
- ``GateAILogger``
- ``GateAILoggerProtocol``

### Error Handling

- ``ServerErrorResponse``
- <doc:ErrorHandling>

## Platform Support

- iOS 16.0+
- macOS 13.0+ (for testing)

## Requirements

- Xcode 16.0 or newer
- Swift 6.0 or newer
- Apple Developer account with App Attest entitlement
- Physical iOS device for production (App Attest requires real hardware)
