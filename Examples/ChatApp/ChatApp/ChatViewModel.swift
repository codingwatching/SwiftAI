import Combine
import Foundation
import SwiftAI

/// ViewModel that manages the chat interface using SwiftAI for text generation.
/// Handles user input, message history, and generation state.
@Observable
@MainActor
class ChatViewModel {
  private static let availabilityCheckInterval: TimeInterval = 0.5
  private static let defaultSystemMessage = "You are a helpful assistant!"

  /// Provider for creating LLM instances
  private let llmProvider: LLMProvider

  /// Current LLM instance
  private var llm: any LLM

  /// Combine subscriptions for reactive updates
  private var availabilitySubscriptions = Set<AnyCancellable>()

  // MARK: - Model State

  /// Currently selected model
  var selectedModel: ModelID

  /// Detailed availability status for the current model
  var modelAvailability: LLMAvailability = .unavailable(reason: .modelNotDownloaded)

  /// All available models
  var availableModels: [ModelID] {
    llmProvider.availableModels
  }

  /// Whether the current model is ready for use
  var isModelAvailable: Bool {
    llm.isAvailable
  }

  // MARK: - Chat State

  /// Current user input text
  var prompt: String

  /// Chat history containing system, user, and assistant messages
  var messages: [SwiftAI.Message]

  /// Indicates if text generation is in progress
  var isGenerating: Bool

  /// Current generation task, used for cancellation
  private var generationTask: Task<Void, any Error>?

  /// Most recent error message, if any
  var errorMessage: String?

  // MARK: - Initialization

  init(llmProvider: LLMProvider) {
    self.llmProvider = llmProvider
    self.selectedModel = .afm
    self.llm = llmProvider.getLLM(for: .afm)

    self.prompt = ""
    self.messages = [.system(.init(text: Self.defaultSystemMessage))]
    self.isGenerating = false
    self.errorMessage = nil

    startAvailabilityMonitoring()
  }

  @MainActor
  deinit {
    availabilitySubscriptions.removeAll()
  }

  // MARK: - Private Methods

  /// Starts monitoring model availability with periodic updates
  private func startAvailabilityMonitoring() {
    Timer.publish(every: Self.availabilityCheckInterval, on: .main, in: .common)
      .autoconnect()
      .map { _ in self.llm.availability }
      .removeDuplicates()
      .sink { [weak self] availability in
        self?.modelAvailability = availability
      }
      .store(in: &availabilitySubscriptions)
  }

  // MARK: - Public Methods

  /// Updates the selected model and creates a new LLM instance
  func selectModel(_ model: ModelID) {
    selectedModel = model
    llm = llmProvider.getLLM(for: model)
    // Reset availability since we have a new LLM
    modelAvailability = llm.availability
    // Reset chat history
    clear()
  }

  /// Generates response for the current prompt using SwiftAI
  func generate() async {
    guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    guard isModelAvailable else {
      errorMessage = "Model is still loading. Please wait..."
      return
    }

    // Cancel any existing generation task
    if let existingTask = generationTask {
      existingTask.cancel()
      generationTask = nil
    }

    isGenerating = true
    defer { isGenerating = false }

    // Add user message
    messages.append(.user(.init(text: prompt)))

    // Clear the input after sending
    let currentPrompt = prompt
    prompt = ""

    generationTask = Task {
      do {
        let reply = try await llm.reply(to: messages, options: .default)
        try Task.checkCancellation()
        messages = reply.history
      } catch is CancellationError {
        // Task was cancelled by user - no action needed
        // The prompt will be restored in the onCancel handler
      }
    }

    do {
      // Handle task completion and cancellation
      try await withTaskCancellationHandler {
        try await generationTask?.value
      } onCancel: {
        Task { @MainActor in
          generationTask?.cancel()
          // Restore prompt if cancelled
          if prompt.isEmpty {
            prompt = currentPrompt
          }
        }
      }
    } catch {
      errorMessage = error.localizedDescription
    }

    generationTask = nil
  }

  /// Clears all chat state
  func clear() {
    prompt = ""
    generationTask?.cancel()
    messages = [.system(.init(text: Self.defaultSystemMessage))]
    errorMessage = nil
  }
}
