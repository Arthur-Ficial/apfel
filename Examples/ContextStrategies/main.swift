import ApfelCore

let config = ContextConfig(
    strategy: .slidingWindow,
    maxTurns: 8,
    outputReserve: 512,
    permissive: false
)

print("strategy=\(config.strategy.rawValue)")
print("max_turns=\(config.maxTurns ?? 0)")
print("output_reserve=\(config.outputReserve)")
