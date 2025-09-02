# Creating Custom LLM Integrations

SwiftAI supports a unified protocol for interacting with different language models. By implementing the [LLM](https://github.com/mi12labs/SwiftAI/blob/d07e5c6c2dfd688b9c0f92e5f832c4f66217b8c5/Sources/SwiftAI/Core/LLM.swift#L4) protocol, you can integrate commercial APIs, local inference servers, or experimental models into the same framework, with consistent support for:

- Text generation
- Structured output (`@Generable`, [Generable](https://github.com/mi12labs/SwiftAI/blob/d07e5c6c2dfd688b9c0f92e5f832c4f66217b8c5/Sources/SwiftAI/Core/Generable.swift#L31))
- Tool calling ([Tool](https://github.com/mi12labs/SwiftAI/blob/d07e5c6c2dfd688b9c0f92e5f832c4f66217b8c5/Sources/SwiftAI/Core/Tool.swift#L28))
- Multi-turn conversations (sessions)

This guide walks you through writing a new integration.

## Implement the Core LLM Protocol

Create a class that conforms to the `LLM` protocol. This is the entry point for your custom backend.

```swift
import SwiftAI

final class CustomLLM: LLM {
  typealias Session = CustomLLMSession

  var isAvailable: Bool {
    // Check API key, connectivity, or model availability
    return true
  }

  func reply<T: Generable>(
    to messages: [Message],
    returning type: T.Type,
    tools: [any Tool],
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    // 1. Convert messages to your API format
    // 2. Send request to your LLM
    // 3. Handle tool calls if requested
    // 4. Parse and return the final response
  }

  func makeSession(tools: [any Tool], messages: [Message]) -> CustomLLMSession {
    CustomLLMSession(tools: tools, initialMessages: messages)
  }

  func reply<T: Generable>(
    to prompt: Prompt,
    returning type: T.Type,
    in session: CustomLLMSession,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    // Session-based reply: append to history and forward to your API
  }
}
```

## Define a Session Type

Sessions ([LLMSession](https://github.com/mi12labs/SwiftAI/blob/d07e5c6c2dfd688b9c0f92e5f832c4f66217b8c5/Sources/SwiftAI/Core/LLM.swift#L281)) preserve conversation history across turns. This allows stateful interactions where the model “remembers” earlier messages.

```swift
final class CustomLLMSession: LLMSession {
  init(tools: [any Tool], initialMessages: [Message]) {
    // Initialize with conversation state and tools
  }

  func prewarm(promptPrefix: Prompt?) {
    // Optional: e.g. open connection or warm cache
  }
}
```

Your session may track messages internally and update state after each reply.

## Convert Between Message Formats

SwiftAI uses a unified [Message](https://github.com/mi12labs/SwiftAI/blob/d07e5c6c2dfd688b9c0f92e5f832c4f66217b8c5/Sources/SwiftAI/Core/Message.swift#L17) type. Your integration must map it to your backend’s format.

```swift
private func convertMessages(_ messages: [Message]) -> [YourAPIFormat] {
  // Map system/user/ai/toolOutput roles
  // Extract text or JSON from [ContentChunk](https://github.com/mi12labs/SwiftAI/blob/d07e5c6c2dfd688b9c0f92e5f832c4f66217b8c5/Sources/SwiftAI/Core/Message.swift#L156) values
}
```

## Support Structured Generation

When the reply type is not String, SwiftAI provides a JSON schema ([Schema](https://github.com/mi12labs/SwiftAI/blob/d07e5c6c2dfd688b9c0f92e5f832c4f66217b8c5/Sources/SwiftAI/Core/Schema.swift#L7)) via `@Generable` ([Generable](https://github.com/mi12labs/SwiftAI/blob/d07e5c6c2dfd688b9c0f92e5f832c4f66217b8c5/Sources/SwiftAI/Core/Generable.swift#L31)). Pass this schema to your backend (if supported).

```swift
private func configureStructuredOutput<T: Generable>(
  for type: T.Type,
  in request: inout APIRequest
) {
  if T.self != String.self {
    let schema = T.schema
    request.responseFormat = convertToAPISchema(schema)
  }
}
```

## Process responses and tool calls

Your LLM must support the "tool loop":

- The model may request a tool.
- You execute it and feed the result back.
- The cycle repeats until no more tools are requested.

```swift
func reply<T: Generable>(
  to messages: [Message],
  returning type: T.Type,
  tools: [any Tool],
  options: LLMReplyOptions
) async throws -> LLMReply<T> {
  var conversationHistory = messages

  // Tool loop: continue until model stops calling tools
  while true {
    let apiResponse = try await makeAPIRequest(...)

    // Add AI response to conversation
    let aiMessage = convertToSwiftAIMessage(apiResponse)
    conversationHistory.append(aiMessage)

    // Check if model wants to call tools
    if apiResponse.toolCalls.isEmpty {
      // No tools requested - parse final response and return
      let content = try parseContent(apiResponse, as: type)
      return LLMReply(content: content, history: conversationHistory)
    }

    // Execute tools and add outputs to conversation
    for toolCall in apiResponse.toolCalls {
      let toolOutput = try await executeToolCall(toolCall, tools: tools)
      conversationHistory.append(toolOutput)
    }

    // Continue loop with updated conversation including tool outputs
  }
}
```
