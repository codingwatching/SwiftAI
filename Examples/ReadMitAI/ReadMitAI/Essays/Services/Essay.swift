import Foundation

/// Represents a Paul Graham essay with metadata needed for display and content fetching.
///
/// This model encapsulates the essential information about an essay that the app needs
/// to present to users and subsequently generate flashcards from the essay content.
/// The URL field enables direct access to the essay's web content for parsing.
struct Essay: Identifiable, Codable {
  /// Unique identifier for SwiftUI list management and internal referencing
  var id = UUID()

  /// Human-readable title of the essay as it appears on paulgraham.com
  /// Used for display in the essays list and as context for flashcard generation
  let title: String

  /// Complete web address pointing to the essay's HTML content
  /// Used for fetching the full essay text when generating flashcards
  let url: URL
}
