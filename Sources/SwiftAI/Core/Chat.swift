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
/// print(response)
/// ```
public actor Chat {
  /// The conversation history including all messages exchanged.
  public private(set) var messages: [any Message]
  
  /// The language model used for generating responses.
  public let llm: any LLM
  
  /// The tools available for the LLM to use during the conversation.
  public let tools: [any Tool]
  
  /// Creates a new chat instance with the specified LLM and tools.
  ///
  /// - Parameters:
  ///   - llm: The language model to use for generating responses
  ///   - tools: The tools available for the LLM to use (defaults to empty array)
  ///   - initialMessages: Initial conversation history (defaults to empty array)
  public init(with llm: any LLM, tools: [any Tool] = [], initialMessages: [any Message] = []) {
    self.llm = llm
    self.tools = tools
    self.messages = initialMessages
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
    _ prompt: PromptRepresentable,
    returning type: T.Type = String.self,
    options: LLMReplyOptions = .default
  ) async throws -> T {
    let userMessage = UserMessage(chunks: prompt.chunks)
    messages.append(userMessage)
    
    // TODO: This will be very inefficient for on device models because the model
    //  will have to reprocess the entire history each time.
    let reply = try await llm.reply(
      to: messages,
      tools: tools,
      returning: type,
      options: options
    )
    
    messages = reply.history
    
    return reply.content
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