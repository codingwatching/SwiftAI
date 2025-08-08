import Foundation

// TODO: Implement comprehensive error handling system
// For now, using minimal error types to get happy path working

/// Errors that can occur during LLM operations.
public enum LLMError: Error {
  case generalError(String)
}

/// Reasons why a model might be unavailable.
public enum UnavailabilityReason {
  case other(String)
}
