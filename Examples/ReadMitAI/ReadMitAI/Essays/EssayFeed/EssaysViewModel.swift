import Combine
import Foundation

/// ViewModel managing the essays list screen state and business logic.
///
/// Coordinates between the EssayService and the UI layer, handling loading states,
/// error conditions, and essay data presentation. Follows MVVM pattern by keeping
/// UI state separate from business logic while providing reactive updates to views.
@MainActor
class EssaysViewModel: ObservableObject {
  /// Current list of essays loaded from Paul Graham's website
  @Published var essays: [Essay] = []

  /// Indicates whether a network request is currently in progress
  @Published var isLoading = false

  /// Error message to display if essay loading fails
  @Published var errorMessage: String?

  /// Service dependency for fetching essay data
  private let essayService = EssayService()

  /// Loads essays from the network and updates UI state accordingly.
  ///
  /// Manages the complete loading lifecycle: sets loading state, calls service,
  /// handles success/error cases, and ensures UI updates happen on main thread.
  /// Clears any previous error state before attempting to load.
  func loadEssays() {
    isLoading = true
    errorMessage = nil

    Task {
      do {
        let loadedEssays = try await essayService.loadEssays()
        self.essays = loadedEssays
      } catch {
        self.essays = []
        self.errorMessage =
          "Failed to load essays. Please check your internet connection and try again."
      }

      self.isLoading = false
    }
  }
}
