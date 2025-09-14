import SwiftUI

@main
struct ChatApp: App {
  var body: some Scene {
    WindowGroup {
      ChatView(viewModel: ChatViewModel(llmProvider: LLMProvider.create()))
    }
  }
}
