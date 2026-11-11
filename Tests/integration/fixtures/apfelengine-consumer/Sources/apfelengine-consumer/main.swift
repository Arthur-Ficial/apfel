import ApfelCore
import ApfelEngine

// Model-free: builds an engine and reads its data-only status surface without
// generating, so this runs on CI runners without Apple Intelligence.
let engine = EngineFactory.make(systemPrompt: "You are terse.")
let status = await engine.contextStatus(outputReserve: 512)
let usage = await engine.sessionUsage()
print("engine|\(status.contextWindow.tokens > 0)|\(usage.totalTokens)")
