# LLM API

- Proposal: [SAI-001](https://github.com/mi12labs/SwiftAI/blob/main/Docs/Proposals/001-llm-api.md)
- Status: **Alpha version Implemented**
- Implementation: [SwiftAI v0.1.0-alpha](https://github.com/mi12labs/SwiftAI/releases/tag/v0.1.0-alpha.1)

## Introduction

Apple has recently opened access to its LLM through the FoundationModels SDK. However, model availability is subject to several device- and user-specific conditions. Therefore in order to use this SDK in production, it’s essential to plan for a fallback strategy when the system model is unavailable.

This document proposes an agnostic LLM API that supports multiple model backends without requiring code rewrites.

## Motivation

Apple’s language model availability depends on factors such as:

- The device must support Apple Intelligence (e.g., iPhone 15 Pro or later)
- Apple Intelligence must be enabled in Settings
- The model must be downloaded locally
- Sufficient battery level
- Other system constraints

Apple recommends always checking whether the system model is available and planning for a fallback when it isn’t.

A simple fallback is to disable the feature entirely—but this limits functionality. A more powerful option is to call a server-hosted LLM. However, this often means maintaining two separate code paths. For example:

```swift
let systemLLM = SystemLanguageModel.default

let aiAnswer: String
if systemLLM.isAvailable {
  // On Device LLM is available.
  let session: LanguageModelSession(systemLLM)
  let response = try await session.respond(to: prompt)
  aiAnswer = response.content
} else {
  // OpenAI as a fallback.
  let client: OpenAIProtocol = /* client initialization code */
  let query = CreateModelResponseQuery(
    input: .textInput(prompt),
    model: .gpt4_1
  )
  let response: ResponseObject = try await client.responses.createResponse(
    query: query
  )
  var text: String = ""
  for output in response.output {
    switch output {
    case .outputMessage(let outputMessage):
      for content in outputMessage.content {
        switch content {
        case .OutputTextContent(let textContent):
            text += textContent
        default: // Other cases omitted
        }
      }
    default: // Other cases omitted
    }
  }
  aiAnswer = text
}
```

The challenge is even greater when working with [structured output](https://platform.openai.com/docs/guides/structured-outputs) and [tool calls](https://platform.openai.com/docs/guides/function-calling), as duplicating logic across local and remote models becomes cumbersome.

Here is an example using [structured outputs](https://platform.openai.com/docs/guides/structured-outputs):

```swift
@Generable
struct ResearchPaper {
  let title: String
  let authors: String
  let abstract: String
  let keywords: [String]
}

let paper: ResearchPaper
if systemLLM.isAvailable {
  // On Device LLM is available.
  let session: LanguageModelSession(systemLLM)
  let response = try await session.respond(to: prompt, generating: ResearchPaper.self)
  paper = response.content
} else {
  // OpenAI as a fallback.
  let query = CreateModelResponseQuery(
    input: .textInput("Return structured output"),
    model: .gpt4_o,
    text: .jsonSchema(.init(
      name: "research_paper",
      schema: .jsonSchema(.init(
        .type(.object),
        .properties([
          "title": Schema.buildBlock(
            .type(.string)
          ),
          "authors": .init(
            .type(.array),
            .items(.init(
              .type(.string)
            ))
          ),
          "abstract": .init(
            .type(.string)
          ),
          "keywords": .init(
            .type(.array),
            .items(.init(
              .type(.string))
            )
          )
        ]),
        .required(["title, authors, abstract, keywords"]),
        .additionalProperties(.boolean(false))
      )),
      description: "desc",
      strict: true
    ))
  )

  // Query Open AI ...
  // Extract json response, then convert it back to swift struct ...
  paper = ...
}
```

To address this, we propose a unified LLM API with a pluggable backend architecture. This API provides type-safe structured output and built-in tool support, enabling developers to switch between local and remote models seamlessly.

## Proposed solution

This API abstracts interaction with language models under a single protocol, regardless of the backend.
It provides:

- Prompt-to-response with type-safe structured output
- Tool calling for model-initiated actions
- Conversation threading for multi-turn exchanges
- Schema-driven generation using Swift macros

The design prioritizes portability: developers can adopt it with minimal changes whether targeting Apple’s FoundationModels or custom server-hosted models.

Here is how the above examples would be written in SwiftAI:

```swift
// Choose your model based on availability
let llm: any LLM = {
  let systemLLM = SystemLLM()
  return systemLLM.isAvailable ? systemLLM : OpenaiLLM(apiKey: "your-api-key")
}()
```

```swift
// Same code works with any model
let response = try await llm.reply(to: "Write a haiku about Berlin.")
print(response.content)
```

```swift
@Generable
struct ResearchPaper {
  let title: String
  let authors: String
  let abstract: String
  @Guide(description: "Important topics in the paper as single words", .minimumCount(1), .maximumCount(10))
  let keywords: [String]
}

// Same code works with any model
let response = try await llm.reply(
  to: "Extract relevant information from this paper ...",
  returning: ResearchPaper.self // Tell the LLM what to output
)

let paper = response.content // content is a ResearchPaper
```

## Detailed design

### The LLM Protocol

The LLM protocol defines the core interface for language model interaction.

#### Core API: Prompt to Response

```swift
protocol LLM: Model {
  func reply<T: Generable>(
    to prompt: any PromptRepresentable,
    tools: [any Tool],
    returning type: T.Type,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T>

  // Other overloads include passing a
  // sequence of messages not just a single prompt.
}
```

- `T: Generable` specifies the structured type expected from the LLM.
- `LLMReply<T>` wraps the typed result and additional metadata.

##### Basic text generation

```swift
let response = try await llm.reply(to: "Explain quantum computing")
print(response.content)
// Returns: "Quantum computing is a type of computation that..."
```

##### Structured output & Tool use

```swift
struct WeatherTool: Tool {
  let description = "Get current weather for a location"

  @Generable
  struct Arguments {
    let location: String
  }

  func call(arguments: Arguments) async throws -> String {
    // Fetch weather data for arguments.location
    return "72°F, sunny in \(arguments.location)"
  }
}

@Generable
struct WeatherReport {
  let temperature: Int
  let conditions: String
  let location: String
}

let report = try await llm.reply(
  to: "What's the weather like in San Francisco?",
  tools: [WeatherTool()],
  returning: WeatherReport.self
)
// LLM calls WeatherTool, then returns structured WeatherReport
```

#### Conversation Management

The LLM API is stateless by design. For multi-turn interactions, `ConversationThread` objects persist conversation context.

```swift
protocol LLM: Model {
  associatedtype ConversationThread: AnyObject & Sendable = NullConversationThread

  func makeConversationThread(
    tools: [any Tool],
    messages: [any Message] // Useful for resuming existing conversations
                            // or passing system instructions.
  ) throws -> ConversationThread

  func reply<T: Generable>(
    to prompt: any PromptRepresentable,
    returning type: T.Type,
    in thread: ConversationThread,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T>
}
```

##### Usage

```swift
let thread = llm.makeConversationThread() {
    // System instructions (aka SystemMessage).
    "You are a helpful assistant. Always be polite."
}

let greeting = try await llm.reply(
  to: "Hello, my name is Alice",
  in: thread
)

// Conversation thread maintains context from previous exchanges
let followUp = try await llm.reply(
  to: "What's my name?",
  in: thread
)
```

### Messages & Content Chunks

A conversation transcript consists of `Message` objects, each associated with a Role. `Message` content is composed of one or more `ContentChunk`s, allowing multimodal data (text, structured output, etc).

```swift
let conversation = [
  SystemMessage("You are a helpful assistant"),
  UserMessage("What's the capital of France?"),
  AIMessage("The capital of France is Paris.")
]
```

```swift
protocol Message: Sendable, Equatable {
  var role: Role { get }
  var chunks: [ContentChunk] { get }
}

enum Role {
  case system, user, ai, toolOutput
}

enum ContentChunk: Sendable, Equatable {
  case text(String)
  case structured(json: String)
}

struct AIMessage: PromptRepresentable, Equatable, Sendable {
  let chunks: [ContentChunk]
  let toolCalls: [ToolCall]
}

struct ToolCall: Sendable, Equatable {
  let id: String
  let toolName: String
  let arguments: StructuredContent
}
```

### Structured Generation

SwiftAI supports type-safe structured output via compile-time macros that produce LLM-readable schemas.

**Key Components**:

- `@Generable`: Makes a type conform to `Generable` and generates a [JSON schema](https://json-schema.org).
- `@Guide`: Adds constraints and documentation to schema properties.

> Naming follows Apple's FoundationModels SDK for easier migration.

#### The Generable Protocol

```swift
protocol Generable: PromptRepresentable, Codable, Sendable {
  static var schema: Schema { get }
}
```

where `Schema` is a data structure that represents a [JSON schema](https://json-schema.org).

#### The `@Generable` Macro

```swift
@attached(extension, conformances: Generable, names: named(schema))
macro Generable(description: String? = nil)
```

#### The `@Guide` Macro

```swift
@attached(peer)
macro Guide(description: String)
macro Guide<T>(description: String? = nil, _ constraints: Constraint<T>...)
```

#### Constraints

Define the specification of an element to generate. The constraint system uses a payload-based approach that can target either the current value or its sub-elements -- useful for example for targeting the elements of an array and not the array itself.

```swift
struct Constraint<Value>: Sendable, Equatable {
  internal let payload: ConstraintPayload
}
```

Under the hood the constraints are represented as

```swift
/// The constraint payload - either constrains this value or sub-values
internal indirect enum ConstraintPayload: Sendable, Equatable {
  case this(ConstraintKind)      // constrains this value
  case sub(AnyConstraint)        // constrains sub-values
}

enum ConstraintKind: Sendable, Equatable {
  case string(StringConstraint)
  case int(IntConstraint)
  case double(DoubleConstraint)
  case boolean(BooleanConstraint)
  case array(ArrayConstraint)
}

enum ArrayConstraint: Sendable, Equatable {
  case count(lowerBound: Int?, upperBound: Int?)
}

enum StringConstraint: Sendable, Equatable {
  case pattern(String)
  case constant(String)
  case anyOf([String])
}

enum IntConstraint: Sendable, Equatable {
  case range(lowerBound: Int?, upperBound: Int?)
}

enum DoubleConstraint: Sendable, Equatable {
  case range(lowerBound: Double?, upperBound: Double?)
}

enum BooleanConstraint: Sendable, Equatable { }
```

##### Example

```swift
@Generable
struct User {
  @Guide(description: "Username", .pattern("^[a-zA-Z][a-zA-Z0-9_]{2,}$"))
  let name: String

  @Guide(description: "User age", .minimum(18))
  let age: Int?

  @Guide(
    description: "User's favorite colors",
    .minimumCount(1),
    .maximumCount(3),
    .element(.anyOf("red", "green", "blue"))
  )
  let favoriteColors: [String]
}
```

Generates the following code:

```swift
extension User: Generable {
  public static var schema: Schema {
    .object(
      name: "User",
      description: nil,
      properties: [
        "name": Schema.Property(
          schema: .string(constraints: [.pattern("^[a-zA-Z][a-zA-Z0-9_]{2,}$")]),
          description: "Username",
          isOptional: false
        ),
        "age": Schema.Property(
          schema: .integer(constraints: [.minimum(18)]),
          description: "User age",
          isOptional: true
        ),
        "favoriteColors": Schema.Property(
          schema: .array(
            items: .string(constraints: [.anyOf("red", "green", "blue")]),
            constraints: [.count(lowerBound: 1, upperBound: 5)]
          ),
          description: "User's favorite colors",
          isOptional: false
        )
      ]
    )
  }
}
```

### Generation Options

SwiftAI provides fine-grained control over LLM generation behavior through `LLMReplyOptions`. These options allow applications to tune the model's creativity, response length, and sampling strategy to match specific use cases and requirements.

#### LLMReplyOptions Structure

```swift
public struct LLMReplyOptions: Sendable, Equatable {
  public let temperature: Double?
  public let maximumTokens: Int?
  public let samplingMode: SamplingMode?
}
```

```swift
public enum SamplingMode: Sendable, Equatable {
  case topP(Double)
  case greedy
}
```

### Tools

SwiftAI enables LLMs to call functions through a structured tool system. Tools extend LLM capabilities by providing access to external data sources, APIs, and custom business logic.

```swift
protocol Tool: Sendable {
  associatedtype Arguments: Generable
  var description: String { get }
  var name: String { get }
  static var parameters: Schema { get }
  func call(arguments: Arguments) async throws -> any PromptRepresentable
  func call(_ data: Data) async throws -> any PromptRepresentable
}
```

## Alternatives considered

- **Different naming** — We considered avoiding FoundationModels terminology (`@Generable`, `@Guide`, `Tool`), but chose alignment to ease migration.
- **Direct FoundationModels types** — We considered using Apple's symbols directly, but this would restrict usage to environments where FoundationModels is available.
