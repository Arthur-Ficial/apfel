// ============================================================================
// MessageBubble.swift — Chat message bubble with always-visible action buttons
// ============================================================================

import SwiftUI
import AppKit

struct MessageBubble: View {
    let message: ChatMsg
    let isSelected: Bool
    let onSelect: () -> Void
    var onSpeak: (() -> Void)? = nil

    @State private var inspectHovered = false

    var body: some View {
        VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
            // Role + timing header
            HStack(spacing: 6) {
                if message.role == "user" { Spacer() }

                Text(message.role == "user" ? "You" : "Apple Intelligence")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                if let ms = message.durationMs {
                    Text("· \(ms)ms")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let tokens = message.tokenCount {
                    Text("· ~\(tokens) tokens")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if message.isStreaming {
                    ProgressView()
                        .controlSize(.mini)
                }

                if message.role == "assistant" { Spacer() }
            }
            .padding(.horizontal, 20)

            // Bubble
            HStack(alignment: .top, spacing: 0) {
                if message.role == "user" { Spacer(minLength: 100) }

                Text(message.content.isEmpty && message.isStreaming ? "Thinking..." : message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .foregroundStyle(message.content.isEmpty && message.isStreaming ? .tertiary : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )

                if message.role == "assistant" { Spacer(minLength: 100) }
            }
            .padding(.horizontal, 16)

            // Action buttons — ALWAYS visible, clearly clickable
            HStack(spacing: 8) {
                if message.role == "user" { Spacer() }

                // Inspect button
                Button(action: onSelect) {
                    HStack(spacing: 4) {
                        Image(systemName: "ant.circle")
                        Text("Inspect")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        inspectHovered
                            ? (isSelected ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .onHover { hovering in
                    inspectHovered = hovering
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }

                // Copy button
                CopyButton(text: message.content)

                // Speak button (assistant messages only)
                if message.role == "assistant", let onSpeak {
                    Button(action: onSpeak) {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2")
                            Text("Speak")
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                }

                if message.role == "assistant" { Spacer() }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
    }

    private var bubbleColor: Color {
        if message.role == "user" {
            return Color.accentColor.opacity(0.12)
        } else {
            return Color(nsColor: .controlBackgroundColor)
        }
    }

}
