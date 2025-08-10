import Foundation

/// A function or capability that language models can invoke to perform specific tasks.
///
/// Tools extend language model capabilities beyond text generation by providing access to
/// external functions, APIs, and data sources.
///
/// ## Example
///
/// ```swift
/// struct WeatherTool: Tool {
///   @Generable
///   struct Arguments {
///     let city: String
///     let units: String
///   }
///
///   let description = "Get current weather conditions for a specified city"
///
///   func call(arguments: Arguments) async throws -> String {
///     // Fetch weather data from API
///     return "Weather in \(arguments.city): 22°C, \(arguments.units)"
///   }
///
///   // name and parameters are provided automatically via default implementations
/// }
/// ```
public protocol Tool: Sendable {
  /// The input parameters required to execute this tool.
  associatedtype Arguments: Generable

  /// The output data returned by this tool.
  associatedtype Output: PromptRepresentable

  /// A unique and descriptive name for this tool used by a language model to reference it.
  /// For example `get_weather`, `search`, `book_flight`, etc.
  var name: String { get }

  /// A natural language description that provides context about this tool to a language model.
  var description: String { get }

  // TODO: Revisit the naming of this property.
  /// The specification of the parameters this tool accepts.
  ///
  /// Describes the structure and constraints of the arguments that can be passed
  /// to this tool, enabling language models to generate valid tool calls.
  static var parameters: Schema { get }

  /// Executes the tool with the provided arguments.
  ///
  /// - Parameter arguments: The input parameters for tool execution
  /// - Returns: The result of the tool execution
  /// - Throws: Any errors that occur during tool execution
  func call(arguments: Arguments) async throws -> Output

  // TODO: Revisit the type used here. Do we need more structured data?
  /// Executes the tool from encoded arguments.
  ///
  /// This method is useful when you have tool arguments as JSON data, such as from
  /// language model tool calls or external API responses. The JSON data will be
  /// decoded into the tool's Arguments type before execution.
  ///
  /// - Parameter data: JSON-encoded arguments for the tool
  /// - Returns: The result of the tool execution
  /// - Throws: Any errors that occur during argument parsing or tool execution
  func call(_ data: Data) async throws -> any PromptRepresentable
}

// MARK: - Default Implementations

extension Tool where Arguments: Generable {
  /// Default implementation of the tool's name.
  /// Uses the type name directly.
  /// For example, `GetWeatherTool` becomes `GetWeatherTool`.
  public var name: String {
    String(describing: Self.self)
  }

  /// Default implementation of parameters using the Arguments schema.
  public static var parameters: Schema {
    Arguments.schema
  }

  /// Default implementation of the JSON call method.
  /// Decodes the JSON data into Arguments and calls the typed method.
  public func call(_ data: Data) async throws -> any PromptRepresentable {
    let decoder = JSONDecoder()
    // TODO: We should probably throw a SwiftAI error if decoding fails.
    let arguments = try decoder.decode(Arguments.self, from: data)
    return try await call(arguments: arguments)
  }
}
