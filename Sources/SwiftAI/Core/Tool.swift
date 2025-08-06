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
///   struct Arguments: Generable {
///     let city: String
///     let units: String = "celsius"
///   }
///
///   @Generable
///   struct WeatherData {
///     @Guide("The current temperature in degrees Celsius")
///     let temperature: Int
///
///     @Guide("A brief description of the current weather conditions")
///     let conditions: String
///   }
///
///   let name = "get_weather"
///   let description = "Get current weather conditions for a specified city"
///
///   func call(arguments: Arguments) async throws -> WeatherData {
///     // Fetch weather data from API
///     return WeatherData(temperature: 22, conditions: "Sunny")
///   }
/// }
/// ```
public protocol Tool: Sendable {
  /// The input parameters required to execute this tool.
  associatedtype Arguments: Generable

  /// The output data returned by this tool.
  associatedtype Output: Sendable  // TODO: This should be PromptRepresentable, but we need to define that protocol first.

  /// A unique identifier for this tool, used by language models to reference it.
  ///
  /// Should follow snake_case convention (e.g., "get_weather", "search_contacts").
  var name: String { get }  // TODO: Add a default implementation that returns the type name in snake_case.

  /// A natural language description explaining when and how to use this tool.
  ///
  /// Should clearly describe the tool's purpose, expected inputs, and output format
  /// to help language models understand when to invoke it.
  var description: String { get }

  /// Executes the tool with the provided arguments.
  ///
  /// - Parameter arguments: The input parameters for tool execution
  /// - Returns: The result of the tool execution
  /// - Throws: Any errors that occur during tool execution
  func call(arguments: Arguments) async throws -> Output
}
