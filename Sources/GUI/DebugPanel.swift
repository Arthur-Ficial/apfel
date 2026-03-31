// ============================================================================
// DebugPanel.swift — Request/response JSON viewer with copy buttons
// ============================================================================

import SwiftUI
import AppKit

struct DebugPanel: View {
    @Bindable var viewModel: ChatViewModel

    private var strategyLabel: String { viewModel.contextStrategyRaw }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "ant.circle.fill")
                    .foregroundStyle(.orange)
                Text("Debug Inspector")
                    .font(.headline)
                Spacer()
                Toggle("Auto-follow", isOn: $viewModel.debugAutoFollow)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                if viewModel.selectedMessage != nil {
                    Button("Clear") {
                        viewModel.selectedMessageId = nil
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if let msg = viewModel.selectedMessage {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Message info
                        infoCard {
                            HStack {
                                Label(msg.role == "user" ? "User Message" : "AI Response",
                                      systemImage: msg.role == "user" ? "person.circle" : "cpu")
                                Spacer()
                                if let ms = msg.durationMs {
                                    Text("\(ms)ms")
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                if let tokens = msg.tokenCount {
                                    Text("\(tokens) tokens")
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            .font(.caption)
                        }

                        // Token budget bar
                        if let tokens = msg.tokenCount {
                            let contextWindow = 4096
                            let ratio = min(1.0, Double(tokens) / Double(contextWindow))
                            let color: Color = ratio < 0.5 ? .green : ratio < 0.8 ? .yellow : .red
                            infoCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "gauge.with.dots.needle.33percent")
                                        Text("Context Budget")
                                            .font(.caption.bold())
                                        Spacer()
                                        Text("\(tokens) / \(contextWindow) tokens")
                                            .font(.system(.caption, design: .monospaced))
                                    }
                                    ProgressView(value: ratio)
                                        .tint(color)
                                    HStack {
                                        Image(systemName: "arrow.triangle.branch")
                                        Text("Strategy: \(strategyLabel)")
                                            .font(.system(.caption, design: .monospaced))
                                    }
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // curl command
                        if let curl = msg.curlCommand {
                            codeSection(
                                title: "curl Command (copy & paste to reproduce)",
                                icon: "terminal",
                                text: curl,
                                color: .purple
                            )
                        }

                        // What we SENT to the server
                        if let json = msg.requestJSON {
                            codeSection(
                                title: "What We Sent (HTTP Request Body)",
                                icon: "arrow.up.doc.fill",
                                text: json,
                                color: .orange
                            )
                        }

                        // What the server RESPONDED with (raw, truthful)
                        if let json = msg.responseJSON {
                            codeSection(
                                title: "What We Got Back (Raw Server Response)",
                                icon: "arrow.down.doc.fill",
                                text: json,
                                color: .green
                            )
                        }

                        // Extracted content
                        codeSection(
                            title: "Extracted Content",
                            icon: "text.quote",
                            text: msg.content,
                            color: .primary
                        )
                    }
                    .padding(12)
                }
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "ant.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No message selected")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                    Text("Click the \(Image(systemName: "ant.circle")) Inspect button\nnext to any message")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Components

    @ViewBuilder
    private func infoCard(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func codeSection(title: String, icon: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .fontWeight(.medium)
                Spacer()
                CopyButton(text: text)
            }
            .font(.caption)

            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        }
    }
}

// MARK: - Copy Button with Hover + Click Feedback

struct CopyButton: View {
    let text: String
    @State private var isHovered = false
    @State private var justCopied = false

    var body: some View {
        Button(action: {
            if copyToPasteboard(text) {
                justCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    justCopied = false
                }
            } else {
                NSSound.beep()
            }
        }) {
            Label(justCopied ? "Copied!" : "Copy", systemImage: justCopied ? "checkmark.circle.fill" : "doc.on.doc")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    isHovered
                        ? Color(nsColor: .controlBackgroundColor)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .foregroundColor(justCopied ? .green : .secondary)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    @MainActor
    private func copyToPasteboard(_ value: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.prepareForNewContents(with: .currentHostOnly)
        guard pasteboard.setString(value, forType: .string) else { return false }
        return pasteboard.string(forType: .string) == value
    }
}
