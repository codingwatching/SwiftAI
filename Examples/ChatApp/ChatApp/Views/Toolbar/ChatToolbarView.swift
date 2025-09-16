import SwiftUI

/// Toolbar view for the chat interface that displays error messages and model selection controls.
struct ChatToolbarView: View {
  /// View model containing the chat state and controls
  @Bindable var vm: ChatViewModel

  var body: some View {
    // Display error message if present
    if let errorMessage = vm.errorMessage {
      ErrorView(errorMessage: errorMessage)
    }

    // Button to clear chat history
    Button {
      vm.clear()
    } label: {
      Image(systemName: "trash")
    }
    .disabled(vm.isGenerating)

    // Model selection picker
    Picker("Model", selection: $vm.selectedModel) {
      ForEach(vm.availableModels) { model in
        HStack {
          Text(model.displayName)
          if model == vm.selectedModel && !vm.isModelAvailable {
            ProgressView()
              .controlSize(.mini)
          }
        }
        .tag(model)
      }
    }
    .disabled(vm.isGenerating)
    .onChange(of: vm.selectedModel) { oldValue, newValue in
      vm.selectModel(newValue)
    }
  }
}
