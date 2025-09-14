import SwiftAI
import SwiftUI

@main
struct ReadMitAIApp: App {
  private let llm = SystemLLM()

  var body: some Scene {
    WindowGroup {
      EssayFeedView()
        .environment(\.llm, llm)
    }
  }
}
