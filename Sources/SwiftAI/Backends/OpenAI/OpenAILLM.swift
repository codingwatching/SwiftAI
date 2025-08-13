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
  ///   - tools: Tools available for the conversation
  ///   - messages: Initial conversation history
  ///
  /// - Returns: A new OpenAI thread for stateful conversations
  public func makeThread(tools: [any Tool], messages: [any Message]) throws -> OpenAIThread {
    return OpenAIThread(messages: messages, tools: tools)
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
  ///   - type: The expected return type
  ///   - thread: The conversation thread (will be modified)
  ///   - options: Generation options
  ///
  /// - Returns: The model's response and updated conversation history
  public func reply<T: Generable>(
    to prompt: any PromptRepresentable,
    returning type: T.Type,
    in thread: inout OpenAIThread,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {

    let userMessage = UserMessage(chunks: prompt.chunks)

    var input: CreateModelResponseQuery.Input
    var previousResponseID: String?

    if let responseID = thread.previousResponseID {
      // Continue from previous response.
      input = try CreateModelResponseQuery.Input.from([userMessage])
      previousResponseID = responseID
    } else {
      // Start a new conversation with the user message.
      input = try CreateModelResponseQuery.Input.from(thread.messages + [userMessage])
      previousResponseID = nil
    }

    // Configure structured output if needed.
    let textConfig = try {
      if type == String.self {
        return CreateModelResponseQuery.TextResponseConfigurationOptions.text
      }
      return try .jsonSchema(makeStructuredOutputConfig(for: type))
    }()

    // Add user message to thread first.
    thread = thread.withNewMessage(userMessage)

    repeat {
      let query = CreateModelResponseQuery(
        input: input,
        model: model,
        previousResponseId: previousResponseID,
        text: textConfig,
        tools: try thread.openAiTools.map { .functionTool($0) }
      )

      let response: ResponseObject = try await {
        do {
          return try await client.responses.createResponse(query: query)
        } catch {
          throw LLMError.generalError("OpenAI API error: \(error)")
        }
      }()

      // Convert response to AIMessage
      let aiMsg = try {
        do {
          return try response.asSwiftAIMessage
        } catch {
          throw LLMError.generalError("Failed to convert response to AIMessage: \(error)")
        }
      }()

      thread = thread.withNewMessage(aiMsg).withNewResponseID(response.id)

      let funcCalls = aiMsg.functionCalls

      if !funcCalls.isEmpty {
        var outputToolMessages = [ToolOutput]()
        for toolCall in funcCalls {
          // TODO: Consider sending the error to the LLM.
          let toolOutput = try await thread.execute(toolCall: toolCall)
          thread = thread.withNewMessage(toolOutput)
          outputToolMessages.append(toolOutput)
        }

        input = try CreateModelResponseQuery.Input.from(outputToolMessages)
        previousResponseID = response.id
      }
    } while !(thread.messages.last is AIMessage)

    // Extract final content from the last AI message
    guard let finalAIMessage = thread.messages.last as? AIMessage else {
      throw LLMError.generalError("Final message should be an AIMessage")
    }

    let content: T
    if T.self == String.self {
      content = finalAIMessage.text as! T  // FIXME: Avoid forced unwrapping
    } else {
      // For structured types, parse JSON from text content
      do {
        let jsonData = finalAIMessage.text.data(using: .utf8) ?? Data()
        let decoder = JSONDecoder()
        content = try decoder.decode(T.self, from: jsonData)
      } catch {
        throw LLMError.generalError(
          "Failed to decode structured response: \(error.localizedDescription)")
      }
    }

    return LLMReply(
      content: content,
      history: thread.messages
    )
  }
}

extension AIMessage {
  /// Extracts function calls from this AIMessage.
  ///
  /// This computed property can be used anywhere in the codebase to extract
  /// tool calls from AI messages, making it reusable and testable.
  fileprivate var functionCalls: [ToolCall] {
    chunks.compactMap { chunk in
      if case .toolCall(let toolCall) = chunk {
        return toolCall
      }
      return nil
    }
  }

  // TODO: This code logic is replicated a few times in the codebase. Refactor it.
  /// Convenience property that contains the aggregated text output from all output texts chunks.
  fileprivate var text: String {
    chunks.compactMap { chunk in
      switch chunk {
      case .text(let text):
        return text
      case .structured(let json):
        return json
      case .toolCall(_):
        return nil
      }
    }.joined(separator: "")
  }
}
