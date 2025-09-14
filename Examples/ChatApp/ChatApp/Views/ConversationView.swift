import SwiftAI
import SwiftUI

/// Displays the chat conversation as a scrollable list of messages.
struct ConversationView: View {
  /// Array of messages to display in the conversation
  let messages: [SwiftAI.Message]
  let modelAvailability: LLMAvailability
  let isGenerating: Bool

  init(messages: [SwiftAI.Message], modelAvailability: LLMAvailability, isGenerating: Bool = false) {
    self.messages = messages
    self.modelAvailability = modelAvailability
    self.isGenerating = isGenerating
  }

  /// Computed property for backward compatibility
  private var isModelLoading: Bool {
    switch modelAvailability {
    case .available:
      return false
    default:
      return true
    }
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
          VStack(spacing: 8) {
            HStack {
              if case .downloading(let progress) = modelAvailability {
                VStack(alignment: .leading, spacing: 4) {
                  ProgressView(value: progress)
                    .progressViewStyle(.linear)
                  Text("Downloading: \(Int(progress * 100))%")
                    .foregroundColor(.secondary)
                    .font(.caption)
                }
              } else {
                ProgressView()
                  .controlSize(.regular)
                Text("Loading model, please wait...")
                  .foregroundColor(.secondary)
              }
              Spacer()
            }
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
    modelAvailability: .downloading(progress: 0.65),
    isGenerating: true
  )
}
