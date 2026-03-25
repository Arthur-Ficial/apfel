// ============================================================================
// ChatView.swift — Main chat interface with message list and input field
// ============================================================================

import SwiftUI
import AppKit

enum FocusField {
    case messageInput
    case systemPrompt
}

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @FocusState private var focusedField: FocusField?

    var body: some View {
        VStack(spacing: 0) {
            // System prompt — always visible, compact
            HStack(spacing: 8) {
                Text("System:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
                TextField("Optional system prompt", text: $viewModel.systemPrompt)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .focused($focusedField, equals: .systemPrompt)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.messages.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.messages) { msg in
                                MessageBubble(
                                    message: msg,
                                    isSelected: viewModel.selectedMessageId == msg.id,
                                    onSelect: {
                                        viewModel.selectedMessageId = msg.id
                                        viewModel.showDebugPanel = true
                                    },
                                    onSpeak: msg.role == "assistant" ? {
                                        viewModel.tts.speak(msg.content)
                                    } : nil
                                )
                                .id(msg.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.messages.last?.content) { _, _ in
                    scrollToBottom(proxy)
                }
            }

            Divider()

            // Input bar
            HStack(alignment: .center, spacing: 8) {
                // Speaker toggle
                Button(action: { viewModel.speakEnabled.toggle() }) {
                    Image(systemName: viewModel.speakEnabled ? "speaker.wave.3.fill" : "speaker.slash")
                        .font(.body)
                        .foregroundColor(viewModel.speakEnabled ? .accentColor : .gray)
                }
                .buttonStyle(.borderless)
                .help(viewModel.speakEnabled ? "Speech on — click to mute" : "Speech off — click to enable")
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }

                // Text input
                TextField("Type a message, press Enter to send...", text: $viewModel.currentInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .focused($focusedField, equals: .messageInput)
                    .onSubmit {
                        Task { await viewModel.send() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focusedField = .messageInput
                        }
                    }

                // Send button
                Button(action: {
                    Task { await viewModel.send() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        focusedField = .messageInput
                    }
                }) {
                    Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSend ? .accentColor : Color(nsColor: .tertiaryLabelColor))
                }
                .buttonStyle(.borderless)
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .onAppear {
            // Focus the message input on launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = .messageInput
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "apple.logo")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("Apple Intelligence")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Text("Press Enter to send")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var canSend: Bool {
        !viewModel.currentInput.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isStreaming
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let lastId = viewModel.messages.last?.id {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}
