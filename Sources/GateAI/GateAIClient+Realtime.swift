import Foundation

/// The result of starting an OpenAI Realtime call through the gate.
public struct GateAIRealtimeCallAnswer: Sendable {
    /// The SDP answer to apply with `RTCPeerConnection.setRemoteDescription`.
    public let sdp: String

    /// OpenAI's identifier for the call (from the `Location` header), when present.
    ///
    /// Gate/AI records the call's usage under this ID, so it can be used to correlate
    /// a session with the rows in your analytics.
    public let callId: String?
}

/// Builds the `multipart/form-data` body OpenAI's `POST /v1/realtime/calls` expects:
/// the SDP offer plus the session configuration as JSON.
enum RealtimeCallRequest {
    static let path = "v1/realtime/calls"

    static func multipartBody(offerSDP: String, session: Data, boundary: String) -> Data {
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"sdp\"\r\n")
        append("Content-Type: application/sdp\r\n\r\n")
        append(offerSDP)
        append("\r\n--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"session\"\r\n")
        append("Content-Type: application/json\r\n\r\n")
        body.append(session)
        append("\r\n--\(boundary)--\r\n")
        return body
    }

    static func callId(fromLocation location: String?) -> String? {
        guard let location else { return nil }
        let path = location.split(separator: "?", maxSplits: 1).first.map(String.init) ?? location
        guard let last = path.split(separator: "/").last, last.hasPrefix("rtc_") else { return nil }
        return String(last)
    }
}

public extension GateAIClient {
    /// Starts an OpenAI Realtime WebRTC call through the gate.
    ///
    /// Create an `RTCPeerConnection`, generate an SDP offer, and pass it here together with
    /// the session configuration (for example `{"type": "realtime", "model": "gpt-realtime"}`).
    /// The gate forwards the offer to OpenAI with your provider key and returns the SDP answer
    /// to apply to the peer connection. Audio then flows directly between the device and OpenAI,
    /// while the gate meters the call and applies your usage limits for its whole duration.
    ///
    /// ```swift
    /// let offer = try await peerConnection.offer(for: constraints)
    /// try await peerConnection.setLocalDescription(offer)
    ///
    /// let answer = try await client.createRealtimeCall(
    ///     offerSDP: offer.sdp,
    ///     session: ["type": "realtime", "model": "gpt-realtime"]
    /// )
    /// try await peerConnection.setRemoteDescription(RTCSessionDescription(type: .answer, sdp: answer.sdp))
    /// ```
    ///
    /// Ephemeral client secrets (`/v1/realtime/client_secrets`) are not available through a
    /// gate, because a session started with one bypasses metering and limits.
    ///
    /// - Parameters:
    ///   - offerSDP: The local SDP offer.
    ///   - session: OpenAI session configuration, JSON-encoded.
    ///   - additionalHeaders: Extra headers for the request, such as `X-App-Feature`.
    /// - Returns: The SDP answer and OpenAI's call ID.
    /// - Throws: ``GateAIError/server(statusCode:error:headers:)`` when the gate or OpenAI
    ///   rejects the call (including when a device usage limit has been reached).
    func createRealtimeCall(
        offerSDP: String,
        session: Data,
        additionalHeaders: [String: String] = [:]
    ) async throws -> GateAIRealtimeCallAnswer {
        let boundary = "gateai-\(UUID().uuidString)"
        let body = RealtimeCallRequest.multipartBody(offerSDP: offerSDP, session: session, boundary: boundary)
        var headers = additionalHeaders
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"

        let (data, response) = try await performProxyRequest(
            path: RealtimeCallRequest.path,
            method: .post,
            body: body,
            additionalHeaders: headers
        )

        let headerFields = response.allHeaderFields.reduce(into: [String: String]()) { partialResult, header in
            if let key = header.key as? String, let value = header.value as? String {
                partialResult[key] = value
            }
        }
        guard (200..<300).contains(response.statusCode) else {
            let serverError = try? JSONDecoder().decode(ServerErrorResponse.self, from: data)
            throw GateAIError.server(statusCode: response.statusCode, error: serverError, headers: headerFields)
        }
        guard let sdp = String(data: data, encoding: .utf8), !sdp.isEmpty else {
            throw GateAIError.invalidResponse
        }
        return GateAIRealtimeCallAnswer(sdp: sdp, callId: RealtimeCallRequest.callId(fromLocation: response.value(forHTTPHeaderField: "Location")))
    }

    /// Starts an OpenAI Realtime WebRTC call through the gate, with the session configuration
    /// given as a dictionary. See ``createRealtimeCall(offerSDP:session:additionalHeaders:)-(String,Data,_)``.
    func createRealtimeCall(
        offerSDP: String,
        session: [String: Any],
        additionalHeaders: [String: String] = [:]
    ) async throws -> GateAIRealtimeCallAnswer {
        let encoded = try JSONSerialization.data(withJSONObject: session)
        return try await createRealtimeCall(offerSDP: offerSDP, session: encoded, additionalHeaders: additionalHeaders)
    }
}
