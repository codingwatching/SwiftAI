import Combine
import Foundation
import SwiftAI

/// ViewModel that manages the chat interface using SwiftAI for text generation.
/// Handles user input, message history, and generation state.
@Observable
@MainActor
class ChatViewModel {
  /// Provider for creating LLM instances
  private let llmProvider: LLMProvider

  /// Currently selected model
  var selectedModel: ModelID

  /// Current LLM instance
  private var llm: any LLM

  private var cancellables = Set<AnyCancellable>()

  init(llmProvider: LLMProvider) {
    self.llmProvider = llmProvider
    self.selectedModel = .llama32_1b
    self.llm = llmProvider.getLLM(for: .llama32_1b)

    startAvailabilityTimer()
  }

  @MainActor
  deinit {
    cancellables.removeAll()
  }

  /// Starts a timer to periodically check model availability
  private func startAvailabilityTimer() {
    Timer.publish(every: 0.5, on: .main, in: .common)
      .autoconnect()
      .map { _ in self.llm.availability }
      .removeDuplicates()
      .sink { [weak self] availability in
        self?.modelAvailability = availability
      }
      .store(in: &cancellables)
  }

  /// Current user input text
  var prompt: String = ""

  /// Chat history containing system, user, and assistant messages
  var messages: [SwiftAI.Message] = [
    .system(.init(text: "You are a helpful assistant!"))
  ]

  /// Detailed availability status for the current model
  var modelAvailability: LLMAvailability = .unavailable(reason: .modelNotDownloaded)

  var isModelAvailable: Bool {
    llm.isAvailable
  }

  /// Indicates if text generation is in progress
  var isGenerating = false

  /// Current generation task, used for cancellation
  private var generateTask: Task<Void, any Error>?

  /// Most recent error message, if any
  var errorMessage: String?

  /// All available models
  var availableModels: [ModelID] {
    llmProvider.availableModels
  }

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
    if let existingTask = generateTask {
      existingTask.cancel()
      generateTask = nil
    }

    isGenerating = true
    defer { isGenerating = false }

    // Add user message
    messages.append(.user(.init(text: prompt)))

    // Clear the input after sending
    let currentPrompt = prompt
    prompt = ""

    generateTask = Task {
      do {
        let reply = try await llm.reply(to: messages, options: .default)
        try Task.checkCancellation()
        messages = reply.history
      } catch is CancellationError {
        // Task was cancelled nothing to do here.
      }
    }

    do {
      // Handle task completion and cancellation
      try await withTaskCancellationHandler {
        try await generateTask?.value
      } onCancel: {
        Task { @MainActor in
          generateTask?.cancel()
          // Restore prompt if cancelled
          if prompt.isEmpty {
            prompt = currentPrompt
          }
        }
      }
    } catch {
      errorMessage = error.localizedDescription
    }

    generateTask = nil
  }

  /// Clears all chat state
  func clear() {
    prompt = ""
    generateTask?.cancel()
    messages = [.system(.init(text: "You are a helpful assistant!"))]
    errorMessage = nil
  }
}
