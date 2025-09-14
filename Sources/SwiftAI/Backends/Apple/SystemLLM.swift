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
/// ### Session-based Conversations
///
/// ```swift
/// var session = systemLLM.makeSession()
///
/// let reply1 = try await systemLLM.reply(
///   to: "My name is Alice",
///   in: session
/// )
///
/// let reply2 = try await systemLLM.reply(
///   to: "What's my name?", // Will remember "Alice"
///   in: session
/// )
/// ```
///
/// - Note: Always check `isAvailable` before making inference calls and handle errors appropriately.
@available(iOS 26.0, macOS 26.0, *)
public struct SystemLLM: LLM {
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

  /// The detailed availability status of the Apple on-device language model.
  ///
  /// This provides more specific information about why the model might be
  /// unavailable, allowing applications to provide better user feedback and
  /// handle different scenarios appropriately.
  public var availability: LLMAvailability {
    switch model.availability {
    case .available:
      return .available
    case .unavailable(let reason):
      return .unavailable(reason: reason.swiftAIReason)
    }
  }

  // TODO: Add throwing documentation, and if any requirements on the messages.

  public func makeSession(
    tools: [any Tool],
    messages: [Message]
  ) -> SystemLLMSession {
    return SystemLLMSession(
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

    // Create session with context
    let session = makeSession(tools: tools, messages: contextMessages)

    let prompt = Prompt(chunks: lastMessage.chunks)
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
    in session: SystemLLMSession,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    guard isAvailable else {
      // TODO: Throw a more specific error
      throw LLMError.generalError("Model unavailable")
    }

    do {
      return try await session.generateResponse(
        prompt: prompt,
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

@available(iOS 26.0, macOS 26.0, *)
extension SystemLanguageModel.Availability.UnavailableReason {
  /// Maps Apple's FoundationModel unavailability reasons to SwiftAI's enum.
  var swiftAIReason: LLMUnavailabilityReason {
    switch self {
    case .deviceNotEligible:
      return .deviceNotSupported
    case .appleIntelligenceNotEnabled:
      return .appleIntelligenceNotEnabled
    case .modelNotReady:
      return .modelNotReady
    @unknown default:
      return .other("\(self)")
    }
  }
}
#endif
