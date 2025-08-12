import Foundation
import OpenAI

/// OpenAI language model integration using the Response API.
public struct OpenAILLM: LLM {
  public typealias Thread = OpenAIThread

  private let client: OpenAIProtocol
  private let model: String
  private let hasApiToken: Bool

  /// Creates a new OpenAI LLM instance.
  ///
  /// - Parameters:
  ///   - apiToken: Your OpenAI API token. If nil, will try to read from OPENAI_API_KEY environment variable.
  ///   - model: The model to use (e.g., "gpt-4", "gpt-3.5-turbo")
  ///   - baseURL: The URL of the API endpoint where requests are sent. If not set, defaults to OpenAI's API endpoint.
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

  /// Creates a new conversation thread for maintaining context.
  ///
  /// - Parameters:
  ///   - tools: Tools available for the conversation (not used in Phase 1)
  ///   - messages: Initial conversation history
  ///
  /// - Returns: A new OpenAI thread for stateful conversations
  public func makeThread(tools: [any Tool], messages: [any Message]) throws -> OpenAIThread {
    return OpenAIThread(messages: messages)
  }

  /// Generates a response to a conversation using OpenAI's Response API.
  ///
  /// - Parameters:
  ///   - messages: The conversation history. Must end with a UserMessage.
  ///   - tools: Tools available for the conversation (not used in Phase 1)
  ///   - type: The expected return type (must be String in Phase 1)
  ///   - options: Generation options (not used in Phase 1)
  ///
  /// - Returns: The model's response and updated conversation history
  public func reply<T: Generable>(
    to messages: [any Message],
    tools: [any Tool],
    returning type: T.Type,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    guard let lastMessage = messages.last, lastMessage.role == .user else {
      throw LLMError.generalError("Conversation must end with a UserMessage")
    }

    // Create a thread with the conversation history excluding the last user message
    let contextMessages = Array(messages.dropLast())
    var thread = try makeThread(tools: tools, messages: contextMessages)

    return try await reply(
      to: lastMessage,
      returning: type,
      in: &thread,
      options: options
    )
  }

  /// Generates a response within an existing conversation thread.
  ///
  /// - Parameters:
  ///   - prompt: The user's prompt
  ///   - type: The expected return type (must be String in Phase 1)
  ///   - thread: The conversation thread (will be modified)
  ///   - options: Generation options (not used in Phase 1)
  ///
  /// - Returns: The model's response and updated conversation history
  public func reply<T: Generable>(
    to prompt: any PromptRepresentable,
    returning type: T.Type,
    in thread: inout OpenAIThread,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    // FIXME: (Phase 1) Only support String generation
    guard T.self == String.self else {
      throw LLMError.generalError("Only String generation is supported in Phase 1")
    }

    let userMessage = UserMessage(chunks: prompt.chunks)

    let input: CreateModelResponseQuery.Input
    let previousResponseID: String?
    if let responseID = thread.previousResponseID {
      // Continue from previous response.
      input = toInputFormat([userMessage])
      previousResponseID = responseID
    } else {
      // Start a new conversation with the user message.
      let updatedMessages = thread.messages + [userMessage]
      input = toInputFormat(updatedMessages)
      previousResponseID = nil
    }
    let query = CreateModelResponseQuery(
      input: input,
      model: model,
      previousResponseId: previousResponseID
    )

    let content: T
    let responseID: String
    do {
      let response = try await client.responses.createResponse(query: query)
      content = try processResponse(response, type: type)
      responseID = response.id
    } catch {
      throw LLMError.generalError("OpenAI API error: \(error)")
    }

    // Update thread with new user message and response ID using functional API
    thread =
      thread
      .withNewMessage(userMessage)
      .withNewMessage(AIMessage(text: content as! String))  // FIXME: Don't use as!
      .withNewResponseID(responseID)

    return LLMReply(
      content: content,
      history: thread.messages
    )

  }
}

/// A conversation thread that maintains OpenAI conversation state.
public final class OpenAIThread: Sendable {
  internal let messages: [any Message]
  internal let previousResponseID: String?

  internal init(messages: [any Message] = [], previousResponseID: String? = nil) {
    self.messages = messages
    self.previousResponseID = previousResponseID
  }

  /// Returns a new thread with an additional message appended to the conversation history.
  internal func withNewMessage(_ message: any Message) -> OpenAIThread {
    let updatedMessages = messages + [message]
    return OpenAIThread(messages: updatedMessages, previousResponseID: previousResponseID)
  }

  /// Returns a new thread with an updated response ID.
  internal func withNewResponseID(_ responseID: String) -> OpenAIThread {
    return OpenAIThread(messages: messages, previousResponseID: responseID)
  }
}

extension OpenAILLM {
  private func processResponse<T: Generable>(
    _ response: ResponseObject,
    type: T.Type
  ) throws -> T {
    // Extract text content from the response output
    var responseText = ""

    for outputItem in response.output {
      switch outputItem {
      case .outputMessage(let outputMessage):
        for content in outputMessage.content {
          switch content {
          case .OutputTextContent(let textContent):
            responseText += textContent.text
          case .RefusalContent(let refusalContent):
            throw LLMError.generalError("Request was refused: \(refusalContent.refusal)")
          }
        }
      default:
        // TODO: Handle function calls and other output types.
        fatalError("Unexpected output item type: \(outputItem)")
      }
    }

    // TODO: Support non text.
    guard let content = responseText as? T else {
      throw LLMError.generalError("Failed to convert response to expected type")
    }

    return content
  }
}
