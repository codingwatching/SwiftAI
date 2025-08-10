import Foundation

// TODO: Implement comprehensive error handling system
// For now, using minimal error types to get happy path working

/// Errors that can occur during LLM operations.
public enum LLMError: Error {
  /// A configured tool could not be executed.
  ///
  /// This error is thrown when a tool fails during execution, either due to
  /// invalid arguments, internal tool errors, or external dependencies being unavailable.
  case toolExecutionFailed(tool: any Tool, underlyingError: any Error)

  /// A general error with a descriptive message.
  case generalError(String)
}

/// Reasons why a model might be unavailable.
public enum UnavailabilityReason {
  case other(String)
}
