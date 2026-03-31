// ============================================================================
// MainWindow.swift — Three-panel layout: Chat + Debug + Logs
// ============================================================================

import SwiftUI

struct MainWindow: View {
    @Bindable var viewModel: ChatViewModel
    let apiClient: APIClient

    var body: some View {
        VStack(spacing: 0) {
            // Main content: Chat + Debug sidebar
            HSplitView {
                ChatView(viewModel: viewModel)
                    .frame(minWidth: 350)

                DebugPanel(viewModel: viewModel)
                    .frame(minWidth: 280, idealWidth: 380, maxWidth: 500)
                    .opacity(viewModel.showDebugPanel ? 1 : 0)
                    .frame(width: viewModel.showDebugPanel ? nil : 0)
                    .clipped()
            }

            // Bottom: Log viewer (always rendered, visibility toggled)
            Divider()
                .opacity(viewModel.showLogPanel ? 1 : 0)
            LogViewer(apiClient: apiClient)
                .frame(height: viewModel.showLogPanel ? 180 : 0)
                .clipped()
                .opacity(viewModel.showLogPanel ? 1 : 0)
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: { viewModel.clear() }) {
                    Label("Clear", systemImage: "trash")
                }
                .keyboardShortcut("k", modifiers: .command)
                .help("Clear chat (Cmd+K)")

                Button(action: { viewModel.showSelfDiscussion = true }) {
                    Label("Self-Discuss", systemImage: "bubble.left.and.bubble.right")
                }
                .help("AI debates itself on a topic")
                .disabled(viewModel.isSelfDiscussing)

                Divider()

                Button(action: { viewModel.showContextSettings = true }) {
                    Label("Context", systemImage: "gearshape")
                }
                .help("Context management settings")

                Toggle(isOn: $viewModel.showDebugPanel) {
                    Label("Debug", systemImage: "ant.circle")
                }
                .keyboardShortcut("d", modifiers: .command)
                .help("Toggle debug panel (Cmd+D)")

                Toggle(isOn: $viewModel.showLogPanel) {
                    Label("Logs", systemImage: "list.bullet.rectangle")
                }
                .keyboardShortcut("l", modifiers: .command)
                .help("Toggle log viewer (Cmd+L)")
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .sheet(isPresented: $viewModel.showSelfDiscussion) {
            SelfDiscussionView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showContextSettings) {
            ContextSettingsView(viewModel: viewModel)
        }
    }
}
