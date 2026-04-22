# Context Strategies

`ContextStrategy` and `ContextConfig` describe how a caller should trim or preserve conversation history before handing a prompt to a model with a fixed context window.

Use `ContextConfig.defaults` for the executable's default behavior, or construct a custom configuration when your app needs to bias toward recency, strictness, or summarization.

```swift
import ApfelCore

let config = ContextConfig(
    strategy: .slidingWindow,
    maxTurns: 8,
    outputReserve: 512,
    permissive: false
)
```

`ApfelCore` does not perform FoundationModels calls itself. It gives you the policy types you can apply around your own transcript or prompt-building logic.
