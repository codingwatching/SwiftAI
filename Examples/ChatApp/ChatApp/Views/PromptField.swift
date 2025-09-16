import SwiftUI

struct PromptField: View {
  @Binding var prompt: String
  @State private var task: Task<Void, Never>?

  let sendButtonAction: () async -> Void

  init(
    prompt: Binding<String>,
    sendButtonAction: @escaping () async -> Void
  ) {
    self._prompt = prompt
    self.sendButtonAction = sendButtonAction
  }

  var body: some View {
    HStack {
      TextField("Prompt", text: $prompt)
        .textFieldStyle(.roundedBorder)

      Button {
        if isRunning {
          task?.cancel()
          task = nil
        } else {
          task = Task {
            await sendButtonAction()
            task = nil
          }
        }
      } label: {
        Image(systemName: isRunning ? "stop.circle.fill" : "paperplane.fill")
      }
      .keyboardShortcut(isRunning ? .cancelAction : .defaultAction)
    }
  }

  private var isRunning: Bool {
    task != nil && !(task!.isCancelled)
  }
}

#Preview {
  PromptField(prompt: .constant("")) {
  }
}
