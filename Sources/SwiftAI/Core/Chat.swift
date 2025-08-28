import Foundation

/// A stateful conversation between an LLM and a user.
///
/// Chat actors provide thread-safe management of conversation state, automatically
/// maintaining message history and coordinating interactions with the underlying LLM.
///
/// ## Usage Example
///
/// ```swift
/// let chat = Chat(with: llm, tools: [weatherTool])
/// let response = try await chat.send("What's the weather like?")
/// print(response.content)
/// ```
public actor Chat<LLMType: LLM> {
  /// The conversation history including all messages exchanged.
  public private(set) var messages: [Message]

  /// The language model used for generating responses.
  public let llm: LLMType

  /// The tools available for the LLM to use during the conversation.
  public let tools: [any Tool]

  /// The session for LLMs that support session based conversations.
  /// Nil for stateless LLMs (NullLLMSession).
  private var session: LLMType.Session?

  /// Creates a new chat instance with the specified LLM and tools.
  ///
  /// - Parameters:
  ///   - llm: The language model to use for generating responses
  ///   - tools: The tools available for the LLM to use (defaults to empty array)
  ///   - initialMessages: Initial conversation history (defaults to empty array)
  public init(
    with llm: LLMType,
    tools: [any Tool] = [],
    initialMessages: [Message] = []
  ) {
    self.llm = llm
    self.tools = tools
    self.messages = initialMessages

    // Initialize session for LLMs that support session management (non-NullLLMSession)
    let createdSession = llm.makeSession(tools: tools, messages: initialMessages)
    self.session = (createdSession is NullLLMSession) ? nil : createdSession
  }

  // TODO: Add an init with a system prompt PromptBuilder to allow constructing.

  /// Sends a prompt to the LLM and returns the generated response.
  ///
  /// - Parameters:
  ///   - prompt: The prompt to send to the LLM
  ///   - type: The expected return type conforming to `Generable`
  ///   - options: Configuration options for the LLM request
  /// - Returns: The generated response of the specified type
  public func send<T: Generable>(
    _ prompt: Prompt,
    returning type: T.Type = String.self,
    options: LLMReplyOptions = .default
  ) async throws -> T {
    if let session {
      let reply = try await llm.reply(
        to: prompt,
        returning: type,
        in: session,
        options: options
      )
      self.messages = reply.history
      return reply.content
    } else {
      let userMessage = Message.user(.init(chunks: prompt.chunks))
      let reply = try await llm.reply(
        to: messages + [userMessage],
        returning: type,
        tools: tools,
        options: options
      )
      self.messages = reply.history
      return reply.content
    }
  }

  /// Sends a string prompt to the LLM and returns the generated response.
  public func send<T: Generable>(
    _ prompt: String,
    returning type: T.Type = String.self,
    options: LLMReplyOptions = .default
  ) async throws -> T {
    return try await send(Prompt(prompt), returning: type, options: options)
  }

  /// Sends a prompt constructed with PromptBuilder to the LLM and returns the generated response.
  ///
  /// - Parameters:
  ///   - type: The expected return type conforming to `Generable`
  ///   - options: Configuration options for the LLM request
  ///   - prompt: A closure that builds the prompt content using PromptBuilder syntax
  /// - Returns: The generated response of the specified type
  public func send<T: Generable>(
    returning type: T.Type = String.self,
    options: LLMReplyOptions = .default,
    @PromptBuilder prompt: () -> Prompt
  ) async throws -> T {
    let builtPrompt = prompt()
    return try await send(builtPrompt, returning: type, options: options)
  }
}
