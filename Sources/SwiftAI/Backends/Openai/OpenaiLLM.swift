import Foundation
import OpenAI

/// Openai's language model integration using the Response API.
public struct OpenaiLLM: LLM {
  public typealias Session = OpenaiSession

  /// Model name used for inference.
  /// OpenAI offers a wide range of models with different capabilities, performance characteristics, and price points.
  /// Refer to the [model guide](https://platform.openai.com/docs/models) to browse and compare available models.
  public let model: String

  private let client: OpenAIProtocol

  /// Creates a new Openai LLM instance.
  ///
  /// - Parameters:
  ///   - apiToken: Your Openai API token. If nil, will try to read from OPENAI_API_KEY environment variable.
  ///   - model: The model to use for inference (e.g., "gpt-4", "gpt-3.5-turbo").
  ///     Refer to the [model guide](https://platform.openai.com/docs/models) for the full list of available models.
  ///   - organizationIdentifier: Optional OpenAI organization identifier.
  ///   - host: API host. Set this if you use a proxy or your own server. Default is "api.openai.com".
  ///   - basePath: Optional base path if OpenAI API proxy is on a custom path. Default is "/v1".
  ///   - port: The port for the API endpoint. Default is 443.
  ///   - scheme: The URL scheme. Default is "https".
  ///   - customHeaders: Additional headers to include in all requests.
  ///     These values override default headers if names collide.
  ///   - timeoutInterval: Request timeout in seconds (default: 60.0)
  public init(
    apiToken: String? = nil,
    model: String,
    organizationIdentifier: String? = nil,
    host: String = "api.openai.com",
    basePath: String = "/v1",
    port: Int = 443,
    scheme: String = "https",
    customHeaders: [String: String] = [:],
    timeoutInterval: TimeInterval = 60.0
  ) {
    let token = apiToken ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    let configuration = OpenAI.Configuration(
      token: token,
      organizationIdentifier: organizationIdentifier,
      host: host,
      port: port,
      scheme: scheme,
      basePath: basePath,
      timeoutInterval: timeoutInterval,
      customHeaders: customHeaders
    )

    self.client = OpenAI(configuration: configuration)
    self.model = model
  }

  public var isAvailable: Bool {
    true
  }

  public var availability: LLMAvailability {
    .available
  }

  public func makeSession(tools: [any Tool], messages: [Message]) -> OpenaiSession {
    return OpenaiSession(messages: messages, tools: tools, client: client, model: model)
  }

  /// Generates a response to a conversation using Openai's Response API.
  ///
  /// - Parameters:
  ///   - messages: The conversation history. Must end with a user message.
  ///   - tools: Tools available for the conversation (not used in Phase 1)
  ///   - type: The expected return type (must be String in Phase 1)
  ///   - options: Generation options (not used in Phase 1)
  ///
  /// - Returns: The model's response and updated conversation history
  public func reply<T: Generable>(
    to messages: [Message],
    returning type: T.Type,
    tools: [any Tool],
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    guard let lastMessage = messages.last, lastMessage.role == .user else {
      throw LLMError.generalError("Conversation must end with a user message")
    }

    // Create a session with the conversation history excluding the last user message
    let contextMessages = Array(messages.dropLast())
    let session = makeSession(tools: tools, messages: contextMessages)

    let prompt = Prompt(chunks: lastMessage.chunks)
    return try await reply(
      to: prompt,
      returning: type,
      in: session,
      options: options
    )
  }

  /// Generates a response within an existing session.
  ///
  /// - Parameters:
  ///   - prompt: The user's prompt
  ///   - type: The expected return type
  ///   - session: The session (will be modified)
  ///   - options: Generation options
  ///
  /// - Returns: The model's response and updated conversation history
  public func reply<T: Generable>(
    to prompt: Prompt,
    returning type: T.Type,
    in session: OpenaiSession,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    return try await session.generateResponse(
      to: prompt,
      returning: type,
      options: options
    )
  }

  public func replyStream<T: Generable>(
    to messages: [Message],
    returning type: T.Type,
    tools: [any Tool],
    options: LLMReplyOptions
  ) -> AsyncThrowingStream<T.Partial, Error> where T: Sendable {
    guard let lastMessage = messages.last, lastMessage.role == .user else {
      return AsyncThrowingStream { continuation in
        continuation.finish(
          throwing: LLMError.generalError("Conversation must end with a user message"))
      }
    }

    // Create a session with the conversation history excluding the last user message
    let contextMessages = Array(messages.dropLast())
    let session = makeSession(tools: tools, messages: contextMessages)

    let prompt = Prompt(chunks: lastMessage.chunks)
    return replyStream(
      to: prompt,
      returning: type,
      in: session,
      options: options
    )
  }

  public func replyStream<T: Generable>(
    to prompt: Prompt,
    returning type: T.Type,
    in session: OpenaiSession,
    options: LLMReplyOptions
  ) -> AsyncThrowingStream<T.Partial, Error> where T: Sendable {
    return AsyncThrowingStream { continuation in
      Task {
        let stream = await session.generateResponseStream(
          to: prompt,
          returning: type,
          options: options
        )

        do {
          for try await partial in stream {
            continuation.yield(partial)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }
}
