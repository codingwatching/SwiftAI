#if canImport(FoundationModels)
import FoundationModels
import Foundation

/// Apple's on-device language model integration.
///
/// SystemLLM provides access to Apple's on-device language model, enabling privacy-focused
/// AI features that run entirely on the user's device without sending data to servers.
///
/// ## Key Features
///
/// - **On-device processing**: All inference happens locally, ensuring user privacy at no cost.
/// - **Tool calling**: Support for augmenting the LLM with custom functions to enhance its capabilities.
/// - **Structured output**: Generate typed Swift objects.
///
/// ## Requirements
///
/// - iOS 26.0+ or macOS 26.0+
/// - Apple Intelligence enabled on the device
/// - Sufficient battery level (Apple may disable the model on low battery)
///
/// ## Usage Examples
///
/// ### Basic Text Generation
///
/// ```swift
/// let systemLLM = SystemLLM()
///
/// let response = try await llm.reply(
///   to: "What is the capital of France?",
///   returning: String.self
/// )
///
/// print(response.content) // "Paris"
/// ```
///
/// ### Structured Output Generation
///
/// ```swift
/// @Generable
/// struct CityInfo {
///   let name: String
///   let country: String
///   let population: Int
/// }
/// let cityData = try await llm.reply(
///   to: "Tell me about Tokyo",
///   returning: CityInfo.self
/// )
///
/// print(cityData.content.name)       // "Tokyo"
/// print(cityData.content.population) // 13960000
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
/// ### Threaded Conversations
///
/// ```swift
/// var thread = systemLLM.makeConversationThread(tools: [], messages: [])
///
/// let reply1 = try await systemLLM.reply(
///   to: "My name is Alice",
///   in: thread
/// )
///
/// let reply2 = try await systemLLM.reply(
///   to: "What's my name?", // Will remember "Alice"
///   in: thread
/// )
/// ```
///
/// - Note: Always check `isAvailable` before making inference calls and handle errors appropriately.
@available(iOS 26.0, macOS 26.0, *)
public struct SystemLLM: LLM {
  public typealias ConversationThread = SystemLLMConversationThread

  private let model: SystemLanguageModel

  public init() {
    self.model = SystemLanguageModel.default
  }

  /// Indicates whether Apple's on-device language model is currently available for use.
  ///
  /// The model availability depends on several factors controlled by Apple Intelligence:
  ///
  /// - **Device compatibility**: iOS 26.0+ or macOS 26.0+ with Apple Intelligence support.
  /// - **User settings**: Apple Intelligence must be enabled in device settings.
  /// - **System resources**: Sufficient battery level and available memory.
  /// - **Regional availability**: Apple Intelligence may not be available in all regions.
  public var isAvailable: Bool {
    model.isAvailable
  }

  // TODO: Add throwing documentation, and if any requirements on the messages.

  /// Creates a new conversation thread with the specified tools and initial message history,
  ///
  /// The conversation thread enables conversation continuation by passing it to `reply`, preserving
  /// context and tool availability across turns.
  ///
  /// - Parameters:
  ///   - tools: Array of tools available for the conversation. Tools are automatically
  ///            integrated into the conversation context and can be called by the model
  ///   - messages: Initial conversation history to seed the conversation thread. Can be empty for
  ///               new conversations or contain previous messages to continue a conversation
  ///
  /// - Returns: A `FoundationLanguageModelConversationThread` that maintains conversation state
  public func makeConversationThread(
    tools: [any Tool],
    messages: [Message]
  ) -> SystemLLMConversationThread {
    return SystemLLMConversationThread(
      model: model,
      tools: tools,
      messages: messages
    )
  }

  /// Generates a response to a conversation using Apple's on-device language model.
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

    // Create thread with context
    let thread = makeConversationThread(tools: tools, messages: contextMessages)

    // Use the threaded reply method
    return try await reply(
      to: lastMessage,
      returning: type,
      in: thread,
      options: options
    )
  }

  /// Generates a response within an existing conversation thread
  ///
  /// This method continues an established conversation by generating a response to a new prompt
  /// while maintaining the full conversation context stored in the conversation thread. The conversation thread automatically
  /// accumulates the conversation history across multiple interactions.
  ///
  /// - Parameters:
  ///   - prompt: The user's prompt represented as any `PromptRepresentable` (typically a string)
  ///   - type: The expected return type conforming to `Generable`
  ///   - thread: The conversation thread to continue. **This will be modified** to include
  ///             the new user prompt and AI response in its conversation history
  ///   - options: Generation options (currently not implemented - will be added in future versions)
  ///
  /// - Returns: An `LLMReply<T>` containing the generated content and complete conversation history
  public func reply<T: Generable>(
    to prompt: any PromptRepresentable,  // TODO: This should probably be a UserMessage to avoid `reply(to: AIMessage(...))`
    returning type: T.Type,
    in thread: SystemLLMConversationThread,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    guard isAvailable else {
      // TODO: Throw a more specific error
      throw LLMError.generalError("Model unavailable")
    }

    let userMessage = Message.user(.init(chunks: prompt.chunks))
    do {
      return try await thread.generateResponse(
        userMessage: userMessage,
        type: type,
        options: options
      )
    } catch let error as LanguageModelSession.GenerationError {
      throw mapAppleError(error)
    } catch {
      throw LLMError.generalError("Generation failed: \(error)")
    }
  }
}
#endif
