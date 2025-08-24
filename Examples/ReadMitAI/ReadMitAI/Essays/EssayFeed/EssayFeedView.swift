import SwiftAI
import SwiftUI

struct EssayFeedView: View {
  @StateObject private var viewModel = EssaysViewModel()
  @Environment(\.llm) private var llm

  var body: some View {
    NavigationStack {
      Group {
        if viewModel.isLoading {
          VStack(spacing: 16) {
            ProgressView()
              .scaleEffect(1.2)
            Text("Loading essays...")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        } else if let errorMessage = viewModel.errorMessage {
          VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
              .font(.system(size: 48))
              .foregroundStyle(.orange)

            Text("Unable to Load Essays")
              .font(.headline)
              .fontWeight(.medium)

            Text(errorMessage)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal)

            Button("Try Again") {
              viewModel.loadEssays()
            }
            .buttonStyle(.borderedProminent)
          }
        } else if viewModel.essays.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "doc.text")
              .font(.system(size: 48))
              .foregroundStyle(.secondary)

            Text("No Essays Found")
              .font(.headline)
              .fontWeight(.medium)

            Text("Pull to refresh to try loading essays again.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        } else {
          List(viewModel.essays) { essay in
            NavigationLink(destination: EssayDetailView(essay: essay, llm: llm)) {
              EssayRowView(essay: essay)
            }
          }
          .refreshable {
            viewModel.loadEssays()
          }
        }
      }
      .navigationTitle("Paul Graham Essays")
      .navigationBarTitleDisplayMode(.large)
    }
    .onAppear {
      if viewModel.essays.isEmpty && !viewModel.isLoading {
        viewModel.loadEssays()
      }
    }
  }
}

#Preview {
  EssayFeedView()
}
