# GateAI

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2016.0%2B-lightgrey.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/license-Proprietary-blue.svg)]()

Secure authentication and API gateway client for iOS applications.

## Features

- ✅ **Automatic Authentication**: OAuth 2.0 + DPoP + App Attest flow handled automatically
- 🔐 **Secure Enclave**: Device keys stored in hardware-backed security
- 📱 **App Attest**: Leverages Apple's device attestation framework
- 🔄 **Token Management**: Automatic token refresh and caching
- 🛡️ **DPoP Proofing**: Per-request proof-of-possession for enhanced security
- 🔁 **Nonce Handling**: Automatic retry for nonce challenges
- 🛠️ **Development Support**: Simulator-friendly development token flow

## Requirements

- iOS 16.0+ / macOS 13.0+
- Xcode 16.0+
- Swift 6.0+
- Apple Developer account with App Attest entitlement

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/LAND-MK-1/gate-ios.git", from: "1.0.0")
]
```

Or in Xcode:

1. File → Add Package Dependencies...
2. Enter the repository URL
3. Select the version or branch
4. Add to your target

### Local Development

For local development, you can add the package directly:

1. File → Add Package Dependencies...
2. Click "Add Local..."
3. Select the `gate-ios` directory

## Quick Start

```swift
import GateAI

// 1. Configure the client
let configuration = try GateAIConfiguration(
    baseURLString: "https://yourteam.us01.gate-ai.net",
    teamIdentifier: "ABCDE12345",  // Your Apple Team ID
    logLevel: .info
)

let client = GateAIClient(configuration: configuration)

// 2. Make authenticated requests
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

// 3. Process the response
if response.statusCode == 200 {
    let result = try JSONDecoder().decode(ChatResponse.self, from: data)
    print(result)
}
```

## Configuration

### Basic Configuration

```swift
let configuration = try GateAIConfiguration(
    baseURLString: "https://yourteam.us01.gate-ai.net",
    teamIdentifier: "ABCDE12345"
)
```

### With Development Token (Simulator)

```swift
#if targetEnvironment(simulator)
let devToken = ProcessInfo.processInfo.environment["GATE_AI_DEV_TOKEN"]
#else
let devToken: String? = nil
#endif

let configuration = try GateAIConfiguration(
    baseURLString: "https://yourteam.us01.gate-ai.net",
    teamIdentifier: "ABCDE12345",
    developmentToken: devToken,
    logLevel: .debug  // Enable detailed logging
)
```

### Custom Bundle Identifier

```swift
let configuration = try GateAIConfiguration(
    baseURLString: "https://yourteam.us01.gate-ai.net",
    bundleIdentifier: "com.example.MyApp",  // Override Bundle.main
    teamIdentifier: "ABCDE12345"
)
```

## Documentation

📚 **[Full Documentation](https://land-mk-1.github.io/gate-ios/documentation/gateai/)**

- [Authentication Guide](https://land-mk-1.github.io/gate-ios/documentation/gateai/authentication)
- [Making Requests](https://land-mk-1.github.io/gate-ios/documentation/gateai/makingrequests)
- [Error Handling](https://land-mk-1.github.io/gate-ios/documentation/gateai/errorhandling)
- [API Reference](https://land-mk-1.github.io/gate-ios/documentation/gateai/)

## Usage Examples

### GET Request

```swift
let (data, response) = try await client.performProxyRequest(
    path: "openai/models",
    method: .get
)
```

### POST Request with JSON

```swift
struct ChatRequest: Codable {
    let model: String
    let messages: [Message]
}

let request = ChatRequest(model: "gpt-4", messages: [...])
let body = try JSONEncoder().encode(request)

let (data, response) = try await client.performProxyRequest(
    path: "openai/chat/completions",
    method: .post,
    body: body,
    additionalHeaders: ["Content-Type": "application/json"]
)
```

### Error Handling

```swift
do {
    let (data, response) = try await client.performProxyRequest(...)
} catch let error as GateAIError {
    switch error {
    case .server(let statusCode, let serverError, _):
        if serverError?.error == "rate_limited" {
            print("Rate limited. Please try again later.")
        }
    case .network(let underlying):
        print("Network error: \(underlying)")
    default:
        print("Error: \(error.localizedDescription)")
    }
}
```

## Setup Requirements

### 1. Enable App Attest

In Xcode:

1. Select your app target
2. Go to **Signing & Capabilities**
3. Add **App Attest** capability

In Apple Developer Portal:

1. Go to your app identifier
2. Enable **App Attest** capability
3. Save and regenerate provisioning profiles

### 2. Register Team ID

Ensure your Apple Team ID is registered with your Gate/AI tenant. Contact your Gate/AI administrator with your:

- Team ID (10 alphanumeric characters, e.g., "ABCDE12345")
- Bundle Identifier
- Environment (production/staging)

### 3. Obtain Development Token (for Simulator)

1. Log into the Gate/AI Console
2. Navigate to **Developer Settings**
3. Generate a development token
4. Store it securely (environment variable or encrypted config)
5. **Never commit tokens to source control**

## Testing

### On Simulator

The SDK automatically uses development token flow on simulator:

```swift
#if targetEnvironment(simulator)
let devToken = "your-dev-token"
#else
let devToken: String? = nil
#endif

let configuration = try GateAIConfiguration(
    baseURLString: "https://staging.us01.gate-ai.net",  // Use staging
    teamIdentifier: "ABCDE12345",
    developmentToken: devToken
)
```

### On Device

Physical devices use the full App Attest flow. No development token needed.

### Running Tests

```bash
swift test
```

## Logging

Enable logging to debug issues:

```swift
let configuration = try GateAIConfiguration(
    baseURLString: "https://yourteam.us01.gate-ai.net",
    teamIdentifier: "ABCDE12345",
    logLevel: .debug  // .off, .error, .warning, .info, .debug
)
```

Logs appear in:
- Xcode console
- Console.app (filter by subsystem: "com.gate-ai.sdk")
- System logs

Sensitive headers (Authorization, DPoP, API keys) are automatically redacted.

## Troubleshooting

### "teamIdentifier must be exactly 10 characters"

Your team ID must be the 10-character Apple Team ID, not your team name. Find it in:
- Xcode → Project Settings → Signing & Capabilities
- Apple Developer Portal → Membership

### "App Attest is not supported on this device"

- Use a physical iOS device (App Attest requires real hardware)
- Or configure a development token for simulator testing

### "Device attestation failed"

- Verify your team ID is registered with your Gate/AI tenant
- Check bundle ID matches configuration
- Try resetting: `try client.clearAppAttestKey()`

### "Invalid base URL"

Ensure the URL string is valid and includes the protocol:
- ✅ `https://yourteam.us01.gate-ai.net`
- ❌ `yourteam.us01.gate-ai.net` (missing protocol)

## Contributing

This is a proprietary SDK. For issues or feature requests, contact Gate/AI support.

## License

Proprietary. See LICENSE file for details.

## Support

- 📧 Email: support@gate-ai.net
- 📚 Documentation: https://docs.gate-ai.net
- 🐛 Issues: Contact your Gate/AI administrator

## See Also

- [Integration Guide](INTEGRATION.md)
- [Sample App](https://github.com/LAND-MK-1/gate-ios-sample-app/)
- [API Documentation](https://land-mk-1.github.io/gate-ios/documentation/gateai/)
