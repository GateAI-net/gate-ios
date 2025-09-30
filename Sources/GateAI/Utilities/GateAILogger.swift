import Foundation
import os.log

public enum GateAILogLevel: String, CaseIterable, Comparable, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case off = "OFF"

    public static func < (lhs: GateAILogLevel, rhs: GateAILogLevel) -> Bool {
        let order: [GateAILogLevel] = [.debug, .info, .warning, .error, .off]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

public protocol GateAILoggerProtocol {
    func log(_ level: GateAILogLevel, _ message: String, file: String, function: String, line: Int)
    func logRequest(_ request: URLRequest, body: Data?)
    func logResponse(_ response: URLResponse?, data: Data?, error: Error?)

    // Convenience methods with default parameters
    func debug(_ message: String, file: String, function: String, line: Int)
    func info(_ message: String, file: String, function: String, line: Int)
    func warning(_ message: String, file: String, function: String, line: Int)
    func error(_ message: String, file: String, function: String, line: Int)
}

// MARK: - Protocol Extension with Default Implementations

extension GateAILoggerProtocol {
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }

    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }

    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }

    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }
}

public final class GateAILogger: GateAILoggerProtocol, @unchecked Sendable {
    public static let shared = GateAILogger()

    private let osLog = OSLog(subsystem: "com.gate-ai.sdk", category: "GateAI")
    private let queue = DispatchQueue(label: "com.gate-ai.logger", qos: .utility)
    private let _logLevel = OSAllocatedUnfairLock(initialState: GateAILogLevel.off)

    private init() {}

    public func setLogLevel(_ level: GateAILogLevel) {
        _logLevel.withLock { $0 = level }
    }

    public func log(_ level: GateAILogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let currentLogLevel = _logLevel.withLock { $0 }
        guard level >= currentLogLevel && currentLogLevel != .off else { return }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "[\(level.rawValue)] \(fileName):\(line) \(function) - \(message)"

        queue.async {
            // Use os_log for system integration
            switch level {
            case .debug:
                os_log("%{public}@", log: self.osLog, type: .debug, formattedMessage)
            case .info:
                os_log("%{public}@", log: self.osLog, type: .info, formattedMessage)
            case .warning:
                os_log("%{public}@", log: self.osLog, type: .default, formattedMessage)
            case .error:
                os_log("%{public}@", log: self.osLog, type: .error, formattedMessage)
            case .off:
                break
            }

            // Note: os_log output appears in Xcode console and Console.app
            // No need for additional print() as it would create duplicates
        }
    }

    public func logRequest(_ request: URLRequest, body: Data? = nil) {
        let currentLogLevel = _logLevel.withLock { $0 }
        guard currentLogLevel <= .debug else { return }

        var logMessage = "🔵 HTTP REQUEST\n"
        logMessage += "URL: \(request.url?.absoluteString ?? "nil")\n"
        logMessage += "Method: \(request.httpMethod ?? "nil")\n"

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            logMessage += "Headers:\n"
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                // Redact sensitive headers
                let redactedValue = shouldRedactHeader(key) ? "[REDACTED]" : value
                logMessage += "  \(key): \(redactedValue)\n"
            }
        }

        if let body = body {
            if let bodyString = String(data: body, encoding: .utf8) {
                logMessage += "Body: \(bodyString)"
            } else {
                logMessage += "Body: <\(body.count) bytes of binary data>"
            }
        }

        log(.debug, logMessage)
    }

    public func logResponse(_ response: URLResponse?, data: Data?, error: Error?) {
        let currentLogLevel = _logLevel.withLock { $0 }
        guard currentLogLevel <= .debug else { return }

        var logMessage = ""

        if let error = error {
            logMessage += "🔴 HTTP ERROR\n"
            logMessage += "Error: \(error.localizedDescription)\n"
            if let urlError = error as? URLError {
                logMessage += "Code: \(urlError.code.rawValue)\n"
            }
        } else {
            logMessage += "🟢 HTTP RESPONSE\n"
        }

        if let httpResponse = response as? HTTPURLResponse {
            logMessage += "Status: \(httpResponse.statusCode)\n"
            logMessage += "URL: \(httpResponse.url?.absoluteString ?? "nil")\n"

            if !httpResponse.allHeaderFields.isEmpty {
                logMessage += "Headers:\n"
                for (key, value) in httpResponse.allHeaderFields.sorted(by: { "\($0.key)" < "\($1.key)" }) {
                    let keyString = "\(key)"
                    let valueString = "\(value)"
                    let redactedValue = shouldRedactHeader(keyString) ? "[REDACTED]" : valueString
                    logMessage += "  \(keyString): \(redactedValue)\n"
                }
            }
        }

        if let data = data {
            if let responseString = String(data: data, encoding: .utf8) {
                // Try to pretty-print JSON
                if let jsonData = responseString.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
                   let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    logMessage += "Body:\n\(prettyString)"
                } else {
                    logMessage += "Body: \(responseString)"
                }
            } else {
                logMessage += "Body: <\(data.count) bytes of binary data>"
            }
        }

        let level: GateAILogLevel = error != nil ? .error : .debug
        log(level, logMessage)
    }

    private func shouldRedactHeader(_ headerName: String) -> Bool {
        let sensitiveHeaders = [
            "authorization",
            "dpop",
            "x-api-key",
            "cookie",
            "set-cookie"
        ]
        return sensitiveHeaders.contains(headerName.lowercased())
    }
}

