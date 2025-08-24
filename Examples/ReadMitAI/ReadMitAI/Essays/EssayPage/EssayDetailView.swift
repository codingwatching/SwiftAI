import SwiftAI
import SwiftUI

/// Detail view displaying the full content of a Paul Graham essay.
///
/// Presents essay content in a readable format with markdown support,
/// loading states, and error handling. Follows Apple's design guidelines
/// for content presentation and reading experiences.
struct EssayDetailView: View {
  @StateObject private var viewModel: EssayDetailViewModel
  @Environment(\.dismiss) private var dismiss

  init(essay: Essay, llm: any LLM) {
    self._viewModel = StateObject(wrappedValue: EssayDetailViewModel(essay: essay, llm: llm))
  }

  var body: some View {
    Group {
      if viewModel.isLoading {
        VStack(spacing: 16) {
          ProgressView()
            .scaleEffect(1.2)
          Text("Loading essay...")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      } else if let errorMessage = viewModel.errorMessage {
        VStack(spacing: 16) {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 48))
            .foregroundStyle(.orange)

          Text("Unable to Load Essay")
            .font(.headline)
            .fontWeight(.medium)

          Text(errorMessage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

          Button("Try Again") {
            Task {
              await viewModel.loadEssayContent()
            }
          }
          .buttonStyle(.borderedProminent)
        }
      } else if viewModel.content.isEmpty {
        VStack(spacing: 16) {
          Image(systemName: "doc.text")
            .font(.system(size: 48))
            .foregroundStyle(.secondary)

          Text("No Content Available")
            .font(.headline)
            .fontWeight(.medium)

          Text("This essay appears to be empty or could not be processed.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            // AI Summary Section
            VStack(alignment: .leading, spacing: 12) {
              Text("AI Summary")
                .font(.headline)
                .fontWeight(.semibold)

              if viewModel.isGeneratingSummary {
                HStack(spacing: 12) {
                  ProgressView()
                    .scaleEffect(0.8)
                  Text("Generating summary...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
              } else if !viewModel.summary.isEmpty {
                Text(viewModel.summary)
                  .font(.body)
                  .padding()
                  .background(Color(.systemGray6))
                  .cornerRadius(12)
              }
            }
            .padding(.horizontal)
            .padding(.top)

            // AI Metadata Section (demonstrates structured output)
            if let metadata = viewModel.metadata {
              VStack(alignment: .leading, spacing: 12) {
                Text("Essay Metadata")
                  .font(.headline)
                  .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Text("Topic:")
                      .fontWeight(.medium)
                    Text(metadata.topic)
                      .foregroundStyle(.secondary)
                  }

                  HStack {
                    Text("Difficulty:")
                      .fontWeight(.medium)
                    Text(metadata.difficulty)
                      .foregroundStyle(.secondary)
                  }

                  VStack(alignment: .leading, spacing: 4) {
                    Text("Key Themes:")
                      .fontWeight(.medium)
                    HStack {
                      ForEach(metadata.keyThemes, id: \.self) { theme in
                        Text(theme)
                          .font(.caption)
                          .padding(.horizontal, 8)
                          .padding(.vertical, 4)
                          .background(Color.blue.opacity(0.1))
                          .foregroundColor(.blue)
                          .cornerRadius(8)
                      }
                    }
                  }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
              }
              .padding(.horizontal)
            }

            // Divider
            if !viewModel.summary.isEmpty || viewModel.isGeneratingSummary
              || viewModel.metadata != nil
            {
              Divider()
                .padding(.horizontal)
            }

            // Essay Content
            VStack(alignment: .leading, spacing: 0) {
              Text(viewModel.content)
                .font(.body)
                .lineSpacing(4)
                .padding()
            }
          }
        }
      }
    }
    .navigationTitle(viewModel.essay.title)
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button("Done") {
          dismiss()
        }
      }
    }
    .onAppear {
      if viewModel.content.isEmpty && !viewModel.isLoading {
        Task {
          await viewModel.loadEssayContent()
        }
      }
    }
  }
}

#Preview {
  EssayDetailView(
    essay: Essay(
      title: "How to Do Great Work", url: URL(string: "https://www.paulgraham.com/greatwork.html")!),
    llm: SystemLLM()
  )
}
