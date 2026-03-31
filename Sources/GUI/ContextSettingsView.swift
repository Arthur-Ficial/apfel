// ============================================================================
// ContextSettingsView.swift — Context management settings sheet
// Part of apfel GUI
// ============================================================================

import SwiftUI
import ApfelCore

struct ContextSettingsView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    private var currentStrategy: ContextStrategy {
        ContextStrategy(rawValue: viewModel.contextStrategyRaw) ?? .newestFirst
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Context Management")
                .font(.headline)

            Picker("Strategy", selection: $viewModel.contextStrategyRaw) {
                ForEach(ContextStrategy.allCases, id: \.rawValue) { strategy in
                    Text(strategy.rawValue).tag(strategy.rawValue)
                }
            }
            .pickerStyle(.menu)

            strategyDescription

            if currentStrategy == .slidingWindow {
                HStack {
                    Text("Max turns:")
                    TextField("e.g. 6", value: $viewModel.contextMaxTurns, format: .number)
                        .frame(width: 60)
                }
            }

            HStack {
                Text("Output reserve:")
                Stepper(
                    "\(viewModel.contextOutputReserve) tokens",
                    value: $viewModel.contextOutputReserve,
                    in: 128...2048, step: 128
                )
            }

            Divider()

            HStack {
                Button("Reset to Defaults") {
                    viewModel.contextStrategyRaw = ContextStrategy.newestFirst.rawValue
                    viewModel.contextMaxTurns = nil
                    viewModel.contextOutputReserve = 512
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    @ViewBuilder
    private var strategyDescription: some View {
        let desc: String = switch currentStrategy {
        case .newestFirst: "Keeps the most recent turns that fit within the context window."
        case .oldestFirst: "Keeps the oldest turns. Good for reference-heavy conversations."
        case .slidingWindow: "Keeps the last N turns, then enforces the token budget."
        case .summarize: "Compresses old turns into a summary using the on-device model."
        case .strict: "No trimming. Returns an error if context is exceeded."
        }
        Text(desc)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
