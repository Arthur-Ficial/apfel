// ============================================================================
// SecurityMiddleware.swift - Origin check, token auth, and CORS handling
// Part of apfel - Apple Intelligence from the command line
// ============================================================================

import Foundation
import Hummingbird
import ApfelCore

/// Hummingbird middleware that enforces origin checking, token authentication,
/// and CORS headers. Replaces the scattered ad-hoc CORS logic.
struct SecurityMiddleware<Context: RequestContext>: RouterMiddleware {
    let config: ServerConfig

    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        let origin = request.headers[.init("Origin")!]

        // OPTIONS preflight: return CORS headers, skip origin/token checks
        if request.method == .options {
            return preflightResponse(origin: origin)
        }

        // Origin check (enabled by default)
        if config.originCheckEnabled {
            if !OriginValidator.isAllowed(origin: origin, allowedOrigins: config.allowedOrigins) {
                let msg = "Origin '\(origin ?? "unknown")' is not allowed. Use --allowed-origins to configure."
                return errorResponse(status: .forbidden, message: msg, type: "forbidden", requestOrigin: origin)
            }
        }

        // Token check (opt-in). /health stays public on loopback by default,
        // but non-loopback token-protected deployments require auth unless
        // the operator explicitly opts into public health checks.
        let isHealth = request.uri.path == "/health"
        let shouldCheckToken = config.token != nil && (!isHealth || config.healthRequiresAuthentication)
        if shouldCheckToken {
            let authHeader = request.headers[.authorization]
            if !OriginValidator.isValidToken(provided: authHeader, expected: config.token) {
                return errorResponse(
                    status: .unauthorized,
                    message: "Invalid or missing Bearer token.",
                    type: "authentication_error",
                    requestOrigin: origin,
                    bearerChallenge: true
                )
            }
        }

        // Pass through to route handler
        var response = try await next(request, context)

        // Add CORS headers if enabled
        applyCORSHeaders(to: &response.headers, requestOrigin: origin)

        return response
    }

    // MARK: - Private

    private func preflightResponse(origin: String?) -> Response {
        var headers = HTTPFields()
        if config.cors {
            applyCORSHeaders(to: &headers, requestOrigin: origin)
            headers[.init("Access-Control-Allow-Methods")!] = "GET, POST, OPTIONS"
            headers[.init("Access-Control-Allow-Headers")!] = "Content-Type, Authorization"
            headers[.init("Access-Control-Max-Age")!] = "86400"
        }
        return Response(status: .noContent, headers: headers)
    }

    private func corsOriginValue(requestOrigin: String?) -> String? {
        if !config.originCheckEnabled || config.allowedOrigins.contains("*") {
            return "*"
        }
        if let requestOrigin,
           OriginValidator.isAllowed(origin: requestOrigin, allowedOrigins: config.allowedOrigins) {
            return requestOrigin
        }
        return nil
    }

    private func applyCORSHeaders(to headers: inout HTTPFields, requestOrigin: String?) {
        guard let allowOrigin = corsOriginValue(requestOrigin: requestOrigin) else { return }
        headers[.init("Access-Control-Allow-Origin")!] = allowOrigin
        if allowOrigin != "*" {
            headers[.init("Vary")!] = "Origin"
        }
    }

    private func errorResponse(
        status: HTTPResponse.Status,
        message: String,
        type: String,
        requestOrigin: String?,
        bearerChallenge: Bool = false
    ) -> Response {
        let error = OpenAIErrorResponse(error: .init(message: message, type: type, param: nil, code: nil))
        let body = jsonString(error)
        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        applyCORSHeaders(to: &headers, requestOrigin: requestOrigin)
        if bearerChallenge {
            headers[.init("WWW-Authenticate")!] = "Bearer"
        }
        return Response(status: status, headers: headers, body: .init(byteBuffer: .init(string: body)))
    }
}
