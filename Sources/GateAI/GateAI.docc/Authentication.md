# Authentication

Learn how the Gate/AI SDK authenticates your app.

## Overview

The Gate/AI SDK implements a multi-layered authentication system combining OAuth 2.0, DPoP (Demonstrating Proof-of-Possession), and Apple's App Attest framework. This provides strong device-bound authentication that prevents token theft and replay attacks.

## Authentication Flow

The SDK handles the complete authentication flow automatically:

1. **Device Key Generation**: A P-256 ECDSA key pair is generated in the Secure Enclave on first use
2. **App Attest Enrollment**: The app creates an App Attest key and sends an attestation to the server
3. **Token Exchange**: The app sends an App Attest assertion along with device key information to obtain an access token
4. **DPoP Proof**: For each API request, a DPoP proof is generated using the device key
5. **Request Authorization**: The access token and DPoP proof are included in request headers

### On Physical Devices

On real iOS devices, the SDK uses the full App Attest flow:

- Device keys are stored in the Secure Enclave
- App Attest keys are generated and attested
- Each request includes an App Attest assertion (or server-side cached attestation)
- Strong cryptographic binding between device, app, and tokens

### In the Simulator

Since App Attest is unavailable in the simulator, the SDK supports a development token flow. Set the `GATE_AI_DEV_TOKEN` environment variable (Xcode scheme ▸ Run ▸ Arguments ▸ Environment) with the token from the Gate/AI Console and initialize the configuration normally. The SDK only reads this value when the binary is built for the simulator, so the token never ships in device builds:

```swift
let configuration = try GateAIConfiguration(
    baseURLString: "https://yourteam.us01.gate-ai.net",
    teamIdentifier: "ABCDE12345"
)
```

Development tokens:
- Provide unchecked access to your gated service
- Are only intended to be used in simulators or CI
- Must be obtained from the Gate/AI Portal
- Should be stored securely (not in source control)
- Are automatically ignored on physical devices
- Revoke them in the Gate/AI Portal if you suspect a leak

## Token Lifecycle

The SDK manages access tokens automatically:

1. **Token Minting**: When a token is needed, the SDK:
   - Generates or loads the device key
   - Performs App Attest attestation (or uses dev token on simulator)
   - Exchanges credentials for an access token
   - Caches the token in memory

2. **Token Refresh**: Tokens are automatically refreshed:
   - Tokens are cached until they expire
   - Refresh occurs 60 seconds before expiry
   - Multiple concurrent requests share the same refresh operation

3. **Token Caching**: Access tokens are:
   - Stored in memory only (not persisted)
   - Associated with the current app session
   - Cleared when calling ``GateAIClient/clearCachedState()``

## DPoP (Demonstrating Proof-of-Possession)

Every request includes a DPoP proof JWT that:

- Is signed with the device's private key from the Secure Enclave
- Includes the HTTP method and full URL
- Contains a unique JWT ID (jti) to prevent replay
- May include a server-provided nonce for additional security

The DPoP mechanism binds the access token to the specific device, preventing token theft.

## Nonce Challenges

When the server responds with a 401 status and a `DPoP-Nonce` header:

1. The SDK extracts the nonce from the response
2. Generates a new DPoP proof including the nonce
3. Automatically retries the request once

The ``GateAIClient/performProxyRequest(path:method:body:additionalHeaders:)`` method handles this automatically.

## Security Best Practices

### Protecting Development Tokens

Development tokens should be:

- Obtained from your staging/development Gate/AI tenant only
- Stored in environment variables or encrypted configuration files
- Never committed to source control
- Rotated regularly
- Scoped to non-production environments

### Entitlements

Ensure your app includes the App Attest entitlement:

1. Select your app target in Xcode
2. Go to **Signing & Capabilities**
3. Add the **App Attest** capability
4. Verify the entitlement in your Apple Developer account

### Team ID Registration

Your Apple Team ID must be registered with your Gate/AI tenant. Contact your Gate/AI administrator to ensure your team ID is authorized.

## Troubleshooting

### Common Authentication Issues

**"App Attest is not supported on this device"**
- Ensure you're running on a physical iOS device (not simulator)
- Verify the App Attest capability is enabled
- Check that your device supports App Attest (iOS 14+)

**"teamIdentifier must be exactly 10 characters"**
- Your team ID must be the 10-character Apple Team ID
- Find it in your Apple Developer account or Xcode project settings
- Example format: "ABCDE12345"

**"Device attestation failed"**
- Verify your team ID is registered with your Gate/AI tenant
- Check that the bundle ID matches your configuration
- Ensure the device has a valid App Attest key
- Try calling ``GateAIClient/clearAppAttestKey()`` to reset

## See Also

- ``GateAIClient``
- ``GateAIConfiguration``
- ``GateAIError``
