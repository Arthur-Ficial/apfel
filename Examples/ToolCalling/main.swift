import ApfelCore

let tool = ToolDef(
    name: "add",
    description: "Adds two numbers",
    parametersJSON: #"{"type":"object","properties":{"a":{"type":"number"},"b":{"type":"number"}},"required":["a","b"]}"#
)

print(ToolCallHandler.buildOutputFormatInstructions(toolNames: [tool.name]))
print(ToolCallHandler.buildFallbackPrompt(tools: [tool]))
