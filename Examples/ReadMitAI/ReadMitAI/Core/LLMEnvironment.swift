import SwiftAI
import SwiftUI

private struct LLMEnvironmentKey: EnvironmentKey {
  static let defaultValue: any LLM = SystemLLM()
}

extension EnvironmentValues {
  var llm: any LLM {
    get { self[LLMEnvironmentKey.self] }
    set { self[LLMEnvironmentKey.self] = newValue }
  }
}
