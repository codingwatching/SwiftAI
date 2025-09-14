import Foundation

/// A type that can be represented as content for language models.
///
/// Types conforming to this protocol can be used as building blocks for constructing
/// prompts, enabling composition and reuse of prompt components across different
/// use cases.
public protocol PromptRepresentable {
  /// The parts that represent this prompt component.
  var chunks: [ContentChunk] { get }
}

extension PromptRepresentable {
  /// A convenience property that contains the aggregated text output from all text representable chunks.
  ///
  /// - .text chunks are returned as is.
  /// - .structured chunks are converted to JSON string
  public var text: String {
    chunks.map { chunk in
      switch chunk {
      case .text(let text):
        return text
      case .structured(let content):
        return content.jsonString
      }
    }.joined(separator: "")
  }
}

/// A structured representation of content to be sent to language models.
///
/// Prompts provide a type-safe way to construct and compose content for LLM interactions.
/// They can contain plain text, structured data, and support dynamic construction through
/// result builders for complex prompt composition.
///
/// ## Usage Example
///
/// ```swift
/// let prompt = Prompt("Tell me about Swift programming")
/// let reply = try await llm.reply(to: [UserMessage(prompt: prompt)])
/// ```
public struct Prompt: PromptRepresentable, Sendable {
  /// The content chunks that make up this prompt.
  public let chunks: [ContentChunk]

  /// Creates a prompt from a plain text string.
  ///
  /// - Parameter content: The text content for the prompt
  public init(_ content: String) {
    self.chunks = [.text(content)]
  }

  /// Creates a prompt from content chunks.
  ///
  /// - Parameter chunks: The content chunks for the prompt
  public init(chunks: [ContentChunk]) {
    self.chunks = chunks
  }

  /// Creates a prompt using a result builder for dynamic composition.
  ///
  /// - Parameter content: A closure that builds the prompt content
  public init(@PromptBuilder content: () -> Prompt) {
    let builtPrompt = content()
    self.chunks = builtPrompt.chunks
  }
}

// MARK: - PromptBuilder

/// A result builder for constructing prompts from multiple components.
///
/// PromptBuilder enables declarative syntax for building complex prompts from
/// multiple parts, allowing for dynamic prompt composition and reusable components.
///
/// ## Usage Example
///
/// ```swift
/// let prompt = Prompt {
///   "System: You are a helpful assistant."
///   "User input: \(userQuery)"
///   "Please respond in a friendly tone."
/// }
/// ```
@resultBuilder
public struct PromptBuilder {
  public static func buildBlock(_ components: PromptRepresentable...) -> Prompt {
    let allChunks = components.flatMap { $0.chunks }
    return Prompt(chunks: allChunks)
  }

  public static func buildExpression(_ expression: PromptRepresentable) -> PromptRepresentable {
    return expression
  }

  public static func buildOptional(_ component: PromptRepresentable?) -> PromptRepresentable {
    if let component = component {
      return component
    } else {
      return Prompt(chunks: [])
    }
  }

  public static func buildEither(first component: PromptRepresentable) -> PromptRepresentable {
    return component
  }

  public static func buildEither(second component: PromptRepresentable) -> PromptRepresentable {
    return component
  }

  /// Enables for loops and array generation in prompt builders.
  public static func buildArray(_ components: [PromptRepresentable]) -> PromptRepresentable {
    let allChunks = components.flatMap { $0.chunks }
    return Prompt(chunks: allChunks)
  }
}

// MARK: - Basic Conformances

/// String conforms to PromptRepresentable for convenient prompt construction.
extension String: PromptRepresentable {
  public var chunks: [ContentChunk] {
    return [.text(self)]
  }
}
