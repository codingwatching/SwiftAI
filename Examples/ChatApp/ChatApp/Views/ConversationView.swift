import SwiftAI
import SwiftUI

/// Displays the chat conversation as a scrollable list of messages.
struct ConversationView: View {
  /// Array of messages to display in the conversation
  let messages: [SwiftAI.Message]
  let isModelLoading: Bool
  let isGenerating: Bool

  init(messages: [SwiftAI.Message], isModelLoading: Bool = false, isGenerating: Bool = false) {
    self.messages = messages
    self.isModelLoading = isModelLoading
    self.isGenerating = isGenerating
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        ForEach(messages, id: \.text) { message in  // FIXME: Make message Identifiable
          MessageView(message)
            .padding(.horizontal, 12)
        }

        // Show loading indicator in conversation if model is loading
        if isModelLoading && messages.count <= 1 {  // Only show if just system message
          HStack {
            ProgressView()
              .controlSize(.regular)
            Text("Loading model, please wait...")
              .foregroundColor(.secondary)
            Spacer()
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
        }

        // Show generation indicator when AI is responding
        if isGenerating {
          HStack {
            ProgressView()
              .controlSize(.mini)
            Text("Thinking...")
              .foregroundColor(.secondary)
              .font(.caption)
            Spacer()
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
        }
      }
    }
    .padding(.vertical, 8)
    .defaultScrollAnchor(.bottom, for: .sizeChanges)
  }
}

#Preview {
  // Display sample conversation in preview
  ConversationView(
    messages: [
      .system(.init(text: "You are a helpful assistant!")),
      .user(.init(text: "Hello!")),
      .ai(.init(text: "Hi there! How can I help you today?")),
      .user(.init(text: "What's the weather like?")),
    ],
    isGenerating: true
  )
}
