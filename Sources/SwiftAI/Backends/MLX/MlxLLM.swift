import Foundation
import MLXLMCommon

/// MLX language model integration.
///
/// MlxLLM provides access to on-device language models through the MLX framework,
/// enabling privacy-focused AI features that run entirely on the user's device.
///
/// ## Key Features
///
/// - **On-device processing**: All inference happens locally, ensuring user privacy at no cost.
/// - **Text generation**: Generate text responses.
/// - **Tool calling**: Support for augmenting the LLM with custom functions to enhance its capabilities.
///
/// - Note: Structured output generation is currently not supported.
///   One workaround is to ask the LLM to return a JSON string, and then parse it into your desired type.
///
/// TODO: Mention that the LM needs to be downloaded (usually large), and requires non trivial GPU memory.
///
/// ## Usage Examples
///
/// ### Basic Text Generation
///
/// ```swift
/// let mlxLLM = MlxLLM(configuration: .init(id: "mlx-community/gemma-2-2b-it-4bit"))
///
/// let response = try await llm.reply(
///   to: "What is the capital of France?",
///   returning: String.self
/// )
///
/// print(response.content) // "Paris"
/// ```
///
/// ### Tool Calling
///
/// ```swift
/// struct WeatherTool: Tool {
///   let description = "Get current weather for a city"
///
///   @Generable
///   struct Arguments {
///     let city: String
///   }
///
///   func call(arguments: Arguments) async throws -> String {
///     // Your weather API logic here
///     return "It's 72°F and sunny in \(arguments.city)"
///   }
/// }
///
/// let weatherTool = WeatherTool()
/// let response = try await llm.reply(
///   to: "What's the weather like in San Francisco?",
///   tools: [weatherTool],
///   returning: String.self
/// )
/// ```
///
/// ### Multi-turn conversations
///
/// ```swift
/// var session = mlxLLM.makeSession()
///
/// let reply1 = try await mlxLLM.reply(
///   to: "My name is Alice",
///   in: session
/// )
///
/// let reply2 = try await mlxLLM.reply(
///   to: "What's my name?", // Will remember "Alice"
///   in: session
/// )
/// ```
public struct MlxLLM: LLM {
  public typealias Session = MlxSession

  private let configuration: ModelConfiguration
  private let manager = MlxModelManager.shared

  /// Creates a new MLX LLM instance from a model configuration.
  public init(configuration: ModelConfiguration) {
    self.configuration = configuration
  }

  /// Indicates whether the MLX model is currently available for use.
  ///
  /// The model is available if the model files (weights and tokenizer) are downloaded.
  public var isAvailable: Bool {
    // TODO: Implement
    return false
  }

  public func makeSession(
    tools: [any Tool],
    messages: [Message]
  ) -> MlxSession {
    return MlxSession(
      configuration: configuration,
      tools: tools,
      messages: messages,
      modelManager: manager
    )
  }

  /// Generates a response to a conversation using a MLX language model.
  public func reply<T: Generable>(
    to messages: [Message],
    returning type: T.Type,
    tools: [any Tool],
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    guard let lastMessage = messages.last, lastMessage.role == .user else {
      throw LLMError.generalError("Conversation must end with a user message")
    }

    // Split conversation: context (prefix) and the user prompt (last message)
    let contextMessages = Array(messages.dropLast())
    let prompt = Prompt(chunks: lastMessage.chunks)

    // Create session with context.
    let session = makeSession(tools: tools, messages: contextMessages)

    return try await reply(
      to: prompt,
      returning: type,
      in: session,
      options: options
    )
  }

  public func reply<T: Generable>(
    to prompt: Prompt,
    returning type: T.Type,
    in session: MlxSession,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    // FIXME: Maybe check for isAvailable?

    return try await session.generateResponse(
      prompt: prompt,
      type: type,
      options: options
    )
  }
}
