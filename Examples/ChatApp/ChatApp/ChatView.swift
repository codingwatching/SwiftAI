import SwiftUI

/// Main chat interface view that manages the conversation UI and user interactions.
/// Displays messages and provides input controls for text-based chat.
struct ChatView: View {
  /// View model that manages the chat state and business logic
  @Bindable private var vm: ChatViewModel

  /// Initializes the chat view with a view model
  /// - Parameter viewModel: The view model to manage chat state
  init(viewModel: ChatViewModel) {
    self.vm = viewModel
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Display conversation history
        ConversationView(
          messages: vm.messages,
          modelAvailability: vm.modelAvailability,
          isGenerating: vm.isGenerating
        )

        Divider()

        // Input field with send button
        PromptField(
          prompt: $vm.prompt,
          sendButtonAction: vm.generate
        )
        .disabled(!vm.isModelAvailable)
        .padding()
      }
      .navigationTitle("SwiftAI Chat Example")
      .toolbar {
        ChatToolbarView(vm: vm)
      }
    }
  }
}

#Preview {
  ChatView(viewModel: ChatViewModel(llmProvider: LLMProvider.create()))
}
