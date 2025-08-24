import Foundation

/// Large language model.
public protocol LLM: Model {
  /// The type used to maintain the state of a conversation.
  ///
  /// Each LLM implementation defines its own conversation thread type to capture
  /// conversation context. Conversation threads must be reference types (`AnyObject`)
  /// to support in-place state updates, and `Sendable` to safely
  /// cross concurrency boundaries.
  ///
  /// Implementations typically wrap session objects or message histories:
  ///
  /// ```swift
  /// // OnDevice LLM with mutable session
  /// final class AppleFoundationModelConversationThread: @unchecked Sendable {
  ///   let session: LanguageModelSession
  /// }
  ///
  /// // API-based LLM tracking messages
  /// final class ClaudeConversationThread: Sendable {
  ///   var messages: [Message]
  /// }
  /// ```
  ///
  /// For stateless implementations use `NullConversationThread`.
  ///
  /// - Note: A conversation thread represents a single conversation between the LLM and the user.
  ///   Use a new conversation thread for each new conversation.
  associatedtype ConversationThread: AnyObject & Sendable = NullConversationThread

  /// Whether the LLM can be used.
  var isAvailable: Bool { get }

  /// Queries the LLM to generate a structured response.
  ///
  /// This method sends a conversation history to the language model along with available tools
  /// and returns a structured response of the specified type. The model can use the provided
  /// tools during generation to access external data or perform computations.
  ///
  /// - Parameters:
  ///   - messages: The conversation history to send to the LLM. Must end with a user message.
  ///   - tools: An array of tools available for the LLM to use during generation
  ///   - type: The expected return type conforming to `Generable`
  ///   - options: Configuration options for the LLM request
  /// - Returns: An `LLMReply` containing the generated response and conversation history
  /// - Throws: An error if the request fails, the response cannot be parsed, or the conversation doesn't end with a user message
  ///
  /// ## Important
  ///
  /// The conversation history must end with a user message. The LLM will use all previous messages
  /// as context and respond to the final user message.
  ///
  /// ## Usage Example
  ///
  /// ```swift
  /// let messages = [
  ///   .system(.init(text: "You are a helpful assistant")),
  ///   .user(.init(text: "What's the weather like?"))
  /// ]
  /// let tools = [weatherTool, calculatorTool]
  /// let reply = try await llm.reply(
  ///   to: messages,
  ///   returning: WeatherReport.self,
  ///   tools: [weatherTool, calculatorTool],
  ///   options: .default
  /// )
  /// print("Temperature: \(reply.content.temperature)°C")
  /// ```
  func reply<T: Generable>(
    to messages: [Message],
    returning type: T.Type,
    tools: [any Tool],
    options: LLMReplyOptions
  ) async throws -> LLMReply<T>

  /// Creates a new conversation thread for maintaining conversation context.
  ///
  /// - Parameters:
  ///   - tools: Functions available to the model during conversation.
  ///   - messages: Initial conversation history to seed the conversation thread.
  ///
  /// - Returns: A new conversation thread instance initialized with the provided conversation history.
  ///
  /// Each conversation thread maintains independent conversation state. Multiple conversation threads
  /// can exist simultaneously for parallel conversations:
  ///
  /// ```swift
  /// let llm = MyLLM()
  /// let customerConversationThread = llm.makeConversationThread()
  /// let supportConversationThread = llm.makeConversationThread(
  ///   tools: [tool1, tool2],
  ///   messages: [message1, message2]
  /// )
  /// ```
  ///
  /// - Note: A conversation thread represents a single conversation between the LLM and the user.
  ///   Use a new conversation thread for each new conversation.
  func makeConversationThread(tools: [any Tool], messages: [Message]) -> ConversationThread

  /// Generates a response to a prompt within a conversation thread.
  ///
  /// - Parameters:
  ///   - prompt: user message to respond to
  ///   - type: The expected response type.
  ///   - thread: The conversation thread maintaining context.
  ///     The conversation thread will be mutated during execution to capture updated conversation state.
  ///   - options: Configuration for response generation.
  ///
  /// - Returns: The model's response containing the generated content and message history.
  ///
  /// - Throws: `LLMError` describing the failure reason.
  ///
  /// The conversation thread preserves context across multiple interactions:
  ///
  /// ```swift
  ///   var thread = llm.makeConversationThread()
  ///   let greeting = try await llm.reply(
  ///       to: "Hello my name is Manal",
  ///       in: thread
  ///   )
  ///
  ///   // Conversation thread now contains context from the greeting exchange
  ///   let followUp = try await llm.reply(
  ///      to: "what's my name?",
  ///      in: thread
  ///   )
  /// ```
  ///
  /// - Note: The conversation thread is mutable. It is updated after each reply to maintain
  ///   conversation continuity.
  ///
  /// - Note: A conversation thread represents a single conversation between the LLM and the user.
  ///   Use a new conversation thread for each new conversation.
  func reply<T: Generable>(
    to prompt: any PromptRepresentable,
    returning type: T.Type,
    in thread: ConversationThread,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T>
}

/// A conversation thread implementation that maintains no conversation state.
///
/// Used as the default conversation thread type for LLM implementations that don't
/// preserve context between interactions.
public final class NullConversationThread: Sendable {}

/// MARK: - NullConversationThread Default Implementations

extension LLM where ConversationThread == NullConversationThread {
  /// Default implementation for stateless LLMs.
  public func makeConversationThread(tools: [any Tool], messages: [Message])
    -> NullConversationThread
  {
    return NullConversationThread()
  }

  /// Default implementation that throws an error for stateless LLMs.
  public func reply<T: Generable>(
    to prompt: any PromptRepresentable,
    returning type: T.Type,
    in thread: NullConversationThread,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    throw LLMError.generalError(
      "Conversation threading not supported for stateless LLM implementations")
  }
}

// MARK: - Convenience Extensions

extension LLM {
  /// Convenience method with default parameters for common use cases.
  public func reply<T: Generable>(
    to messages: [Message],
    returning type: T.Type = String.self,
    tools: [any Tool] = [],
    options: LLMReplyOptions = .default
  ) async throws -> LLMReply<T> {
    return try await reply(to: messages, returning: type, tools: tools, options: options)
  }

  /// Convenience method to create a conversation thread with default empty tools and messages.
  public func makeConversationThread(tools: [any Tool] = [], messages: [Message] = [])
    -> ConversationThread
  {
    return makeConversationThread(tools: tools, messages: messages)
  }

  /// Convenience method to create a conversation thread with PromptBuilder instructions.
  public func makeConversationThread(
    tools: [any Tool] = [],
    @PromptBuilder instructions: () -> Prompt
  ) -> ConversationThread {
    let prompt = instructions()
    let systemMessage = Message.system(.init(chunks: prompt.chunks))
    return makeConversationThread(tools: tools, messages: [systemMessage])
  }

  /// Convenience method for prompt-based queries with default parameters.
  public func reply<T: Generable>(
    to prompt: any PromptRepresentable,
    returning type: T.Type = String.self,
    tools: [any Tool] = [],
    options: LLMReplyOptions = .default
  ) async throws -> LLMReply<T> {
    let userMessage = Message.user(.init(chunks: prompt.chunks))
    return try await reply(
      to: [userMessage],
      returning: type,
      tools: tools,
      options: options
    )
  }

  /// Convenience method for prompt-based queries with PromptBuilder.
  public func reply<T: Generable>(
    returning type: T.Type = String.self,
    tools: [any Tool] = [],
    options: LLMReplyOptions = .default,
    @PromptBuilder to content: () -> Prompt
  ) async throws -> LLMReply<T> {
    let prompt = content()
    let userMessage = Message.user(.init(chunks: prompt.chunks))
    return try await reply(
      to: [userMessage],
      returning: type,
      tools: tools,
      options: options
    )
  }

  /// Convenience method for threaded replies with default parameters.
  @discardableResult
  public func reply<T: Generable>(
    to prompt: any PromptRepresentable,
    returning type: T.Type = String.self,
    in thread: ConversationThread,
    options: LLMReplyOptions = .default
  ) async throws -> LLMReply<T> {
    return try await reply(to: prompt, returning: type, in: thread, options: options)
  }

  /// Convenience method for threaded replies with PromptBuilder.
  @discardableResult
  public func reply<T: Generable>(
    returning type: T.Type = String.self,
    in thread: ConversationThread,
    options: LLMReplyOptions = .default,
    @PromptBuilder to content: () -> Prompt
  ) async throws -> LLMReply<T> {
    return try await reply(to: content(), returning: type, in: thread, options: options)
  }
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
  public let history: [Message]

  public init(content: T, history: [Message]) {
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
