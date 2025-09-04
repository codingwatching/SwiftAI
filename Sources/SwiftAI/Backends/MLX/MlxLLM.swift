import Foundation
import MLXLMCommon

/// MLX language model integration.
///
/// MlxLLM provides access to on-device language models through the MLX framework,
/// enabling privacy-focused AI features that run entirely on the user's device.
///
/// ## Key Features
///
/// - **On-device processing**: All inference happens locally, ensuring user privacy at no cost.
/// - **Text generation**: Generate text responses.
/// - **Tool calling**: Support for augmenting the LLM with custom functions to enhance its capabilities.
///
/// - Note: Structured output generation is currently not supported.
///   One workaround is to ask the LLM to return a JSON string, and then parse it into your desired type.
///
/// TODO: Mention that the LM needs to be downloaded (usually large), and requires non trivial GPU memory.
///
/// ## Usage Examples
///
/// ### Basic Text Generation
///
/// ```swift
/// let mlxLLM = MlxLLM(configuration: .init(id: "mlx-community/gemma-2-2b-it-4bit"))
///
/// let response = try await llm.reply(
///   to: "What is the capital of France?"
/// )
///
/// print(response.content) // "Paris"
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
/// ### Multi-turn conversations
///
/// ```swift
/// var session = mlxLLM.makeSession()
///
/// let reply1 = try await mlxLLM.reply(
///   to: "My name is Alice",
///   in: session
/// )
///
/// let reply2 = try await mlxLLM.reply(
///   to: "What's my name?", // Will remember "Alice"
///   in: session
/// )
/// ```
public struct MlxLLM: LLM {
  // MARK: - Static Properties

  /// Default directory for storing model files.
  static public let defaultStorageDirectory = URL.documentsDirectory.appending(path: "mlx-models")

  // FIXME: Can we make this safer? It's not thread-safe now.
  /// Internal storage for the default model manager.
  private static var defaultManager = MlxModelManager(storageDirectory: defaultStorageDirectory)

  // MARK: - Instance Properties

  /// Configuration for the MLX model.
  private let configuration: ModelConfiguration

  // MARK: - Computed Properties

  /// Indicates whether the MLX model is currently loaded in memory.
  public var isAvailable: Bool {
    return Self.defaultManager.isModelLoadedInMemory(configuration)
  }

  // MARK: - Initialization

  /// Creates a new MLX LLM instance from a model configuration.
  ///
  /// - Parameter configuration: The model configuration to use.
  public init(configuration: ModelConfiguration) {
    self.configuration = configuration

    // Start a non-blocking task to preload the model
    Task {
      do {
        _ = try await Self.defaultManager.getOrLoadModel(forConfiguration: configuration)
      } catch {
        // Silently ignore errors during preloading - they will be handled
        // when the model is actually used
      }
    }
  }

  // MARK: - Static Configuration

  /// Configures where model files will be stored.
  ///
  /// This method should be called during app startup, before using any
  /// `MlxLLM` instance.
  ///
  /// - Parameter storageDirectory: The directory where model files will be stored.
  /// - Note: If this method is not called, `MlxLLM` instances will use the default storage directory.
  /// - Warning: This method is not thread-safe. It's recommended to call it from the main thread during app startup.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // During app startup
  /// let customDirectory = URL.documentsDirectory.appending(path: "custom-models")
  /// MlxLLM.configure(storageDirectory: customDirectory)
  /// ```
  public static func configure(storageDirectory: URL) {
    defaultManager = MlxModelManager(storageDirectory: storageDirectory)
  }

  // MARK: - Session Management

  public func makeSession(
    tools: [any Tool],
    messages: [Message]
  ) -> MlxSession {
    return MlxSession(
      configuration: configuration,
      tools: tools,
      messages: messages,
      modelManager: Self.defaultManager
    )
  }

  // MARK: - Response Generation

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
    let prompt = Prompt(chunks: lastMessage.chunks)

    // Create session with context.
    let session = makeSession(tools: tools, messages: contextMessages)

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
    in session: MlxSession,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    guard isAvailable else {
      throw LLMError.generalError("Model unavailable")
    }

    return try await session.generateResponse(
      prompt: prompt,
      type: type,
      options: options
    )
  }
}
