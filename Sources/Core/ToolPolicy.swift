// ============================================================================
// ToolPolicy.swift - Request-scoped tool-calling contract resolved from
// tool_choice, the effective tool set, and parallel_tool_calls, and enforced
// at the response boundary (#480).
// Part of ApfelCore - pure Swift, no external dependencies.
// ============================================================================

import Foundation

/// The enforceable tool-calling contract for one chat-completions request.
///
/// apfel steers the on-device model towards the requested `tool_choice` with
/// prompt instructions (`ContextManager.buildInstructions`), but a small model
/// does not always comply, and prose steering must never be the last barrier
/// between the model's output and an executable `tool_calls` response.
/// `ToolPolicy` is that barrier: `resolve` validates the request scope before
/// generation and `evaluate` validates every detected call before it is
/// exposed to the client or dispatched to an MCP server.
public struct ToolPolicy: Sendable, Equatable {

    /// What the request allows the model to do with tools.
    public enum Mode: Sendable, Equatable {
        /// No tools are in scope (`tool_choice: none`, or no tools at all).
        /// Tool-call-shaped output is ordinary content.
        case disabled
        /// The model may call any tool in scope or answer in plain text.
        case auto
        /// The model must call at least one tool in scope.
        case required
        /// The model must call exactly this function.
        case specific(String)
    }

    /// A request whose tool scope cannot be satisfied. Reported as a 400
    /// with `param: "tool_choice"` before any generation happens.
    public enum ScopeError: Error, Sendable, Equatable {
        /// `tool_choice: required` with no tools in scope.
        case requiredWithoutTools
        /// A named `tool_choice` whose function is neither a client tool nor
        /// an attached MCP tool. `available` lists the names in scope.
        case unknownFunction(name: String, available: [String])
        /// An undecodable `tool_choice`. `ChatRequestValidator` rejects this
        /// earlier on the server path; kept so `resolve` is total for
        /// library consumers.
        case invalidChoice(String)

        /// The request parameter the error is about.
        public var param: String { "tool_choice" }

        /// Human-readable OpenAI-style error message.
        public var message: String {
            switch self {
            case .requiredWithoutTools:
                return "tool_choice 'required' needs at least one tool, but the request has no 'tools' and the server has no MCP tools attached."
            case .unknownFunction(let name, let available):
                let list = available.isEmpty ? "none" : available.joined(separator: ", ")
                return "tool_choice function name '\(name)' does not match any tool in scope. Available: \(list)"
            case .invalidChoice(let raw):
                return "Invalid 'tool_choice' value: \(raw). Must be 'auto', 'none', 'required', or a {\"type\":\"function\",\"function\":{\"name\":\"...\"}} object."
            }
        }
    }

    /// Model output that breaks the request's tool contract. Reported as a
    /// typed server error instead of an HTTP 200 that looks like a completed
    /// answer.
    public struct Violation: Error, Sendable, Equatable {
        /// `tool_choice_not_satisfied` when a forced choice (`required` or a
        /// named function) was not honoured; `tool_call_not_allowed` when the
        /// model called a function outside the resolved scope.
        public let code: String
        /// Human-readable explanation naming the functions involved.
        public let message: String

        public static let notSatisfiedCode = "tool_choice_not_satisfied"
        public static let notAllowedCode = "tool_call_not_allowed"
    }

    /// The verdict for one model response.
    public enum Outcome: Sendable, Equatable {
        /// Deliver the model text as ordinary assistant content.
        case content
        /// Expose or dispatch exactly these validated calls.
        case toolCalls([ParsedToolCall])
        /// The output violates the contract; fail the request.
        case violation(Violation)
    }

    public let mode: Mode
    /// Function names the model may call, in request order. Empty when disabled.
    public let allowedNames: [String]
    /// Maximum number of calls to expose; `1` when `parallel_tool_calls` is
    /// `false`, `nil` when unlimited.
    public let maxCalls: Int?

    /// True when any tool may reach the model or be detected in its output.
    public var toolsInScope: Bool { mode != .disabled }

    /// True for `required` and named choices, where plain text is a violation.
    public var forcesToolCall: Bool {
        switch mode {
        case .required, .specific: return true
        case .disabled, .auto: return false
        }
    }

    /// Resolve the policy for a request.
    ///
    /// - Parameters:
    ///   - toolChoice: the decoded `tool_choice`, `nil` when omitted (auto).
    ///   - toolNames: names of every tool in scope - client `tools` or, when
    ///     the client sent none, the server's attached MCP tools.
    ///   - parallelToolCalls: the decoded `parallel_tool_calls`.
    public static func resolve(
        toolChoice: ToolChoice?,
        toolNames: [String],
        parallelToolCalls: Bool?
    ) -> Result<ToolPolicy, ScopeError> {
        let maxCalls: Int? = parallelToolCalls == false ? 1 : nil
        switch toolChoice {
        case .some(ToolChoice.none):
            return .success(ToolPolicy(mode: .disabled, allowedNames: [], maxCalls: maxCalls))
        case .some(.invalid(let raw)):
            return .failure(.invalidChoice(raw))
        case .some(.required):
            guard !toolNames.isEmpty else { return .failure(.requiredWithoutTools) }
            return .success(ToolPolicy(mode: .required, allowedNames: toolNames, maxCalls: maxCalls))
        case .some(.specific(let name)):
            guard toolNames.contains(name) else {
                return .failure(.unknownFunction(name: name, available: toolNames))
            }
            return .success(ToolPolicy(mode: .specific(name), allowedNames: toolNames, maxCalls: maxCalls))
        case Optional<ToolChoice>.none, .some(.auto):
            guard !toolNames.isEmpty else {
                return .success(ToolPolicy(mode: .disabled, allowedNames: [], maxCalls: maxCalls))
            }
            return .success(ToolPolicy(mode: .auto, allowedNames: toolNames, maxCalls: maxCalls))
        }
    }

    /// The tool definitions the model should see: none when disabled, only
    /// the forced function for a named choice, otherwise all of them.
    public func scopedTools(from tools: [OpenAITool]?) -> [OpenAITool]? {
        switch mode {
        case .disabled:
            return nil
        case .specific(let name):
            return tools?.filter { $0.function.name == name }
        case .auto, .required:
            return tools
        }
    }

    /// Judge the calls detected in one model response.
    ///
    /// - Parameters:
    ///   - detected: the result of `ToolCallHandler.detectToolCall(in:)`.
    ///   - enforceNames: when `false`, calls to functions outside the scope
    ///     are passed through instead of rejected. The MCP auto-execute path
    ///     uses this because `MCPManager` already rejects unknown tools and
    ///     feeds the error back to the model so it can recover (#241). The
    ///     client-tools path keeps the default, since the client cannot
    ///     execute a function it never defined.
    public func evaluate(_ detected: [ParsedToolCall]?, enforceNames: Bool = true) -> Outcome {
        let calls = detected ?? []
        switch mode {
        case .disabled:
            return .content
        case .auto:
            guard !calls.isEmpty else { return .content }
        case .required:
            guard !calls.isEmpty else {
                return .violation(Violation(
                    code: Violation.notSatisfiedCode,
                    message: "tool_choice 'required' was not satisfied: the model answered with plain text instead of calling one of: \(allowedNames.joined(separator: ", "))."))
            }
        case .specific(let name):
            guard !calls.isEmpty else {
                return .violation(Violation(
                    code: Violation.notSatisfiedCode,
                    message: "tool_choice function '\(name)' was not satisfied: the model answered with plain text instead of calling it."))
            }
            let others = calls.map(\.name).filter { $0 != name }
            if !others.isEmpty {
                return .violation(Violation(
                    code: Violation.notSatisfiedCode,
                    message: "tool_choice function '\(name)' was not satisfied: the model called \(others.map { "'\($0)'" }.joined(separator: ", ")) instead."))
            }
        }
        if enforceNames {
            let unknown = calls.map(\.name).filter { !allowedNames.contains($0) }
            if !unknown.isEmpty {
                return .violation(Violation(
                    code: Violation.notAllowedCode,
                    message: "the model called \(unknown.map { "'\($0)'" }.joined(separator: ", ")), which is not in the request's tools. Available: \(allowedNames.joined(separator: ", "))."))
            }
        }
        if let maxCalls, calls.count > maxCalls {
            return .toolCalls(Array(calls.prefix(maxCalls)))
        }
        return .toolCalls(calls)
    }
}
