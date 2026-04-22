import ApfelCore

let message = OpenAIMessage(role: "user", content: .text("hello"))
print("\(message.textContent ?? "nil")|\(ContextStrategy.slidingWindow.rawValue)")
