# Contributing to GateAI iOS SDK

Thank you for your interest in contributing to the GateAI iOS SDK! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Guidelines](#development-guidelines)
- [Pull Request Process](#pull-request-process)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

We are committed to providing a welcoming and inclusive experience for everyone. Please be respectful and constructive in all interactions.

## Getting Started

### Prerequisites

- Xcode 16.0 or newer
- Swift 6.0 or newer
- macOS 13.0+ for development
- iOS 16.0+ device for testing App Attest features

### Setting Up the Development Environment

1. **Clone the repository**
   ```bash
   git clone https://github.com/LAND-MK-1/gate-ios.git
   cd gate-ios
   ```

2. **Build the project**
   ```bash
   swift build
   ```

3. **Run tests**
   ```bash
   swift test
   ```

4. **Open in Xcode**
   ```bash
   open Package.swift
   ```

## How to Contribute

### Types of Contributions

We welcome various types of contributions:

- 🐛 **Bug fixes** - Fix issues in existing code
- ✨ **New features** - Add new functionality
- 📚 **Documentation** - Improve docs, add examples, fix typos
- 🧪 **Tests** - Add or improve test coverage
- 🎨 **Code quality** - Refactoring, performance improvements
- 💡 **Ideas** - Suggest new features or improvements

### Before You Start

1. **Check existing issues** - See if someone is already working on it
2. **Open an issue** - For major changes, discuss your idea first
3. **Small PRs** - Keep pull requests focused on a single change

## Development Guidelines

### Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Keep functions small and focused
- Prefer immutability when possible
- Use Swift 6 strict concurrency features

### Documentation

All public APIs must include DocC documentation:

```swift
/// Brief description of what this does.
///
/// Detailed explanation with usage examples.
///
/// - Parameters:
///   - param1: Description of param1
///   - param2: Description of param2
/// - Returns: Description of return value
/// - Throws: Description of errors that can be thrown
///
/// ## Example
///
/// ```swift
/// let result = try await myFunction(param1: "value", param2: 42)
/// ```
public func myFunction(param1: String, param2: Int) async throws -> Result {
    // Implementation
}
```

### Testing

- Write tests for all new functionality
- Ensure existing tests pass
- Aim for >80% code coverage for new features
- Use the Swift Testing framework

```swift
@Test func myNewFeature() throws {
    // Arrange
    let sut = MyClass()

    // Act
    let result = try sut.doSomething()

    // Assert
    #expect(result == expectedValue)
}
```

### Error Handling

- Use `GateAIError` enum for all SDK errors
- Provide descriptive error messages
- Include recovery suggestions where applicable

### Logging

- Use `GateAILogger` for all logging
- Automatically redact sensitive information
- Use appropriate log levels:
  - `.debug` - Detailed diagnostic info
  - `.info` - Important events
  - `.warning` - Potentially problematic situations
  - `.error` - Error conditions

## Pull Request Process

### 1. Create a Branch

```bash
git checkout -b feature/my-new-feature
# or
git checkout -b fix/issue-123
```

Branch naming conventions:
- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `test/description` - Test additions/improvements
- `refactor/description` - Code refactoring

### 2. Make Your Changes

- Write clean, well-documented code
- Add tests for new functionality
- Update documentation if needed
- Ensure all tests pass: `swift test`

### 3. Commit Your Changes

Write clear, descriptive commit messages:

```bash
git commit -m "Add support for custom retry policies

- Add RetryPolicy configuration struct
- Implement exponential backoff strategy
- Add tests for retry behavior
- Update documentation with retry examples"
```

Good commit messages:
- Start with a verb (Add, Fix, Update, Remove, etc.)
- Keep first line under 50 characters
- Add detailed description if needed
- Reference issues: "Fixes #123" or "Related to #456"

### 4. Push and Create PR

```bash
git push origin feature/my-new-feature
```

Then open a Pull Request on GitHub with:
- **Clear title** - Summarize the change
- **Description** - Explain what and why
- **Testing** - How you tested the changes
- **Screenshots** - If UI-related
- **Breaking changes** - If any

### PR Checklist

Before submitting, ensure:
- [ ] Code follows Swift style guidelines
- [ ] All tests pass locally
- [ ] New tests added for new functionality
- [ ] Documentation updated (README, DocC, etc.)
- [ ] No sensitive information in code or commits
- [ ] Commit messages are clear and descriptive

### Review Process

1. Automated checks run (tests, build)
2. Maintainers review your code
3. Address any feedback or requested changes
4. Once approved, your PR will be merged!

## Reporting Issues

### Bug Reports

When reporting bugs, include:

- **Clear title** - Summarize the issue
- **Description** - What happened vs what you expected
- **Steps to reproduce** - How to trigger the bug
- **Environment** - Xcode version, iOS version, device/simulator
- **Code sample** - Minimal example that reproduces the issue
- **Error messages** - Full error text or logs
- **Screenshots** - If applicable

**Template:**

```markdown
### Bug Description
Clear description of what went wrong.

### Steps to Reproduce
1. Initialize client with...
2. Call method X with...
3. Observe error...

### Expected Behavior
What should happen.

### Actual Behavior
What actually happens.

### Environment
- Xcode: 16.0
- iOS: 16.0
- Device: iPhone 15 Simulator
- SDK Version: 1.0.0

### Code Sample
\```swift
let client = GateAIClient(configuration: ...)
try await client.performProxyRequest(...)
\```

### Error Message
\```
Error: Device attestation failed
\```
```

### Feature Requests

For new features, include:

- **Use case** - Why is this needed?
- **Proposed solution** - How should it work?
- **Alternatives** - Other approaches considered?
- **Examples** - Code examples of proposed API

## Questions?

- ❓ Open an [Issue](https://github.com/LAND-MK-1/gate-ios/issues/new/choose) for questions, bugs, or feature requests
- 📧 Email support@landmk1.com for account or service-related issues

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).

---

Thank you for contributing to GateAI iOS SDK! 🎉
