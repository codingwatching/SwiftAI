import Foundation
import OpenAI

/// Openai's language model integration using the Response API.
public struct OpenaiLLM: LLM {
  public typealias Session = OpenaiSession

  private let client: OpenAIProtocol
  private let model: String
  private let hasApiToken: Bool

  /// Creates a new Openai LLM instance.
  ///
  /// - Parameters:
  ///   - apiToken: Your Openai API token. If nil, will try to read from OPENAI_API_KEY environment variable.
  ///   - model: The model to use (e.g., "gpt-4", "gpt-3.5-turbo")
  ///   - baseURL: The URL of the API endpoint where requests are sent. If not set, defaults to Openai's API endpoint.
  ///   - timeoutInterval: Request timeout in seconds (default: 60.0)
  public init(
    apiToken: String? = nil, model: String, baseURL: String? = nil,
    timeoutInterval: TimeInterval = 60.0
  ) {
    let token = apiToken ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    let configuration: OpenAI.Configuration
    if let baseURL = baseURL {
      configuration = OpenAI.Configuration(
        token: token,
        host: baseURL,
        timeoutInterval: timeoutInterval
      )
    } else {
      configuration = OpenAI.Configuration(token: token, timeoutInterval: timeoutInterval)
    }

    self.client = OpenAI(configuration: configuration)
    self.model = model
    self.hasApiToken = !token.isEmpty
  }

  /// Returns true if there is a non-empty API token.
  public var isAvailable: Bool {
    hasApiToken
  }

  /// The detailed availability status of the OpenAI language model.
  ///
  /// This checks for API key presence and returns appropriate availability status.
  /// Network connectivity checks are not performed for performance reasons.
  public var availability: LLMAvailability {
    if hasApiToken {
      return .available
    } else {
      return .unavailable(reason: .apiKeyMissing)
    }
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
  ) -> sending AsyncThrowingStream<T.Partial, Error> where T: Sendable {
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
  ) -> sending AsyncThrowingStream<T.Partial, Error> where T: Sendable {
    guard isAvailable else {
      return AsyncThrowingStream { continuation in
        continuation.finish(throwing: LLMError.generalError("OpenAI API key missing"))
      }
    }

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
