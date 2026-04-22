import ApfelCore

let request = ChatCompletionRequest(
    model: "apple-foundationmodel",
    messages: [
        OpenAIMessage(role: "system", content: .text("Be concise.")),
        OpenAIMessage(role: "user", content: .text("Say hello")),
    ],
    stream: false,
    stream_options: nil,
    temperature: 0.2,
    max_tokens: 64,
    seed: nil,
    tools: nil,
    tool_choice: nil,
    response_format: nil,
    logprobs: nil,
    n: nil,
    stop: nil,
    presence_penalty: nil,
    frequency_penalty: nil,
    user: "example-user",
    x_context_strategy: nil,
    x_context_max_turns: nil,
    x_context_output_reserve: nil
)

print("model=\(request.model)")
print("messages=\(request.messages.count)")
