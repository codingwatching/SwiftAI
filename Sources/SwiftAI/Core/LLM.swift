import Foundation

/// Large language model.
public protocol LLM: Model {
  /// The type used to maintain conversation state across interactions.
  ///
  /// Each LLM implementation defines its own thread type to capture
  /// conversation context. Threads must be reference types (`AnyObject`)
  /// to support in-place state updates, and `Sendable` to safely
  /// cross concurrency boundaries.
  ///
  /// Implementations typically wrap session objects or message histories:
  ///
  /// ```swift
  /// // OnDevice LLM with mutable session
  /// final class AppleFoundationModelThread: @unchecked Sendable {
  ///   let session: LanguageModelSession
  /// }
  ///
  /// // API-based LLM tracking messages
  /// final class ClaudeThread: Sendable {
  ///   let messages: [any Message]
  /// }
  /// ```
  ///
  /// For stateless implementations use `NullThread`.
  associatedtype Thread: AnyObject & Sendable = NullThread

  /// Whether the LLM can be used.
  var isAvailable: Bool { get }

  /// Queries the LLM to generate a structured response.
  ///
  /// This method sends a conversation history to the language model along with available tools
  /// and returns a structured response of the specified type. The model can use the provided
  /// tools during generation to access external data or perform computations.
  ///
  /// - Parameters:
  ///   - messages: The conversation history to send to the LLM. Must end with a UserMessage.
  ///   - tools: An array of tools available for the LLM to use during generation
  ///   - type: The expected return type conforming to `Generable`
  ///   - options: Configuration options for the LLM request
  /// - Returns: An `LLMReply` containing the generated response and conversation history
  /// - Throws: An error if the request fails, the response cannot be parsed, or the conversation doesn't end with a UserMessage
  ///
  /// ## Important
  ///
  /// The conversation history must end with a UserMessage. The LLM will use all previous messages
  /// as context and respond to the final UserMessage.
  ///
  /// ## Usage Example
  ///
  /// ```swift
  /// let messages = [
  ///   SystemMessage(chunks: [.text("You are a helpful assistant")]),
  ///   UserMessage(chunks: [.text("What's the weather like?")])
  /// ]
  /// let tools = [weatherTool, calculatorTool]
  /// let reply = try await llm.reply(
  ///   to: messages,
  ///   tools: tools,
  ///   returning: WeatherReport.self,
  ///   options: .default
  /// )
  /// print("Temperature: \(reply.content.temperature)°C")
  /// ```
  func reply<T: Generable>(
    to messages: [any Message],
    tools: [any Tool],
    returning type: T.Type,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T>

  // TODO: Provide defaults for `makeThread`

  /// Creates a new thread for maintaining conversation context.
  ///
  /// - Parameters:
  ///   - tools: Functions available to the model during conversation.
  ///   - messages: Initial conversation history to seed the thread.
  ///
  /// - Returns: A new thread instance initialized with the provided conversation history.
  /// - Throws: An error if the thread cannot be created (e.g. invalid tools or messages).
  ///
  /// Each thread maintains independent conversation state. Multiple threads
  /// can exist simultaneously for parallel conversations:
  ///
  /// ```swift
  /// let llm = MyLLM()
  /// let customerThread = try llm.makeThread(tools: [], messages: [])
  /// let supportThread = try llm.makeThread(tools: [], messages: existingHistory)
  /// ```
  func makeThread(tools: [any Tool], messages: [any Message]) throws -> Thread

  // TODO: Provide defaults for `reply(to:returning:in:options:)`

  /// Generates a response to a prompt within a conversation thread.
  ///
  /// - Parameters:
  ///   - prompt: user message to respond to
  ///   - type: The expected response type.
  ///   - thread: The conversation thread maintaining context.
  ///     The thread will be mutated during execution to capture updated conversation state.
  ///   - options: Configuration for response generation.
  ///
  /// - Returns: The model's response containing the generated content and message history.
  ///
  /// - Throws: `LLMError` describing the failure reason.
  ///
  /// The thread preserves context across multiple interactions:
  ///
  /// ```swift
  ///   var thread = llm.makeThread()
  ///   let greeting = try await llm.reply(
  ///       to: "Hello my name is Manal",
  ///       in: &thread
  ///   )
  ///
  ///   // Thread now contains context from the greeting exchange
  ///   let followUp = try await llm.reply(
  ///      to: "what's my name?",
  ///      in: &thread
  ///   )
  /// ```
  ///
  /// - Important: The thread is mutable. It is updated after each reply to maintain conversation continuity.
  func reply<T: Generable>(
    to prompt: any PromptRepresentable,
    returning type: T.Type,
    in thread: inout Thread,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T>
}

/// A thread implementation that maintains no conversation state.
///
/// Used as the default thread type for LLM implementations that don't
/// preserve context between interactions.
public final class NullThread: Sendable {}

/// MARK: - NullThread Default Implementations

extension LLM where Thread == NullThread {
  /// Default implementation for stateless LLMs.
  public func makeThread(tools: [any Tool], messages: [any Message]) throws -> NullThread {
    return NullThread()
  }

  /// Default implementation that throws an error for stateless LLMs.
  public func reply<T: Generable>(
    to prompt: any PromptRepresentable,
    returning type: T.Type,
    in thread: inout NullThread,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    throw LLMError.generalError("Threading not supported for stateless LLM implementations")
  }
}

// MARK: - Convenience Extensions

extension LLM {
  /// Convenience method with default parameters for common use cases.
  public func reply<T: Generable>(
    to messages: [any Message],
    tools: [any Tool] = [],
    returning type: T.Type = String.self,
    options: LLMReplyOptions = .default
  ) async throws -> LLMReply<T> {
    return try await reply(to: messages, tools: tools, returning: type, options: options)
  }

  // TODO: Add convenience methods for prompt-based queries and threaded replies
}

// MARK: - LLMReply and Options

/// The response from a language model query.
public struct LLMReply<T: Generable> {
  /// The generated content parsed into the requested type.
  public let content: T

  /// The complete conversation history including the model's response.
  ///
  /// Useful for maintaining conversation context across multiple interactions
  /// or for debugging and logging purposes.
  public let history: [any Message]

  public init(content: T, history: [any Message]) {
    self.content = content
    self.history = history
  }
}

/// Configuration options that control language model behavior during generation.
///
/// These options provide fine-grained control over the model's output characteristics,
/// allowing applications to tune the model's creativity and response length to match
/// specific use cases and requirements.
public struct LLMReplyOptions {
  /// Controls randomness in the model's output. Lower values make output more deterministic.
  ///
  /// Range: 0.0 (deterministic) to 2.0 (maximum creativity). Default varies by model.
  public let temperature: Double?

  /// Maximum number of tokens the model can generate in its response.
  ///
  /// Helps control response length and prevent runaway generation. Set to nil for model default.
  public let maximumTokens: Int?

  // TODO: Add sampling modes.

  /// Default configuration with model-specific defaults for all parameters.
  public static let `default` = LLMReplyOptions()

  public init(temperature: Double? = nil, maximumTokens: Int? = nil) {
    self.temperature = temperature
    self.maximumTokens = maximumTokens
  }
}
