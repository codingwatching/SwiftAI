import Foundation

/// Large language model.
public protocol LLM: Model {
  /// Whether the LLM can be used.
  var isAvailable: Bool { get }

  /// Queries the LLM to generate a structured response.
  ///
  /// This method sends a conversation history to the language model along with available tools
  /// and returns a structured response of the specified type. The model can use the provided
  /// tools during generation to access external data or perform computations.
  ///
  /// - Parameters:
  ///   - messages: The conversation history to send to the LLM
  ///   - tools: An array of tools available for the LLM to use during generation
  ///   - type: The expected return type conforming to `Generable`
  ///   - options: Configuration options for the LLM request
  /// - Returns: An `LLMReply` containing the generated response and conversation history
  /// - Throws: An error if the request fails or the response cannot be parsed
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
