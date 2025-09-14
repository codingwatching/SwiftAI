import SwiftUI

@main
struct MLXChatExampleApp: App {
  var body: some Scene {
    WindowGroup {
      ChatView(viewModel: ChatViewModel(llmProvider: LLMProvider.create()))
    }
  }
}

