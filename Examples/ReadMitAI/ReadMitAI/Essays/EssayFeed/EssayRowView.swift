import SwiftUI

/// Individual row component for displaying essay information in the essays list.
struct EssayRowView: View {
  let essay: Essay

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(essay.title)
        .font(.headline)
        .fontWeight(.medium)
        .lineLimit(2)
        .multilineTextAlignment(.leading)

      Text(essay.url.lastPathComponent.replacingOccurrences(of: ".html", with: ""))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }
}

#Preview {
  List {
    EssayRowView(
      essay: Essay(
        title: "How to Do Great Work",
        url: URL(string: "https://www.paulgraham.com/greatwork.html")!))
    EssayRowView(
      essay: Essay(
        title: "The Shape of the Essay Field",
        url: URL(string: "https://www.paulgraham.com/field.html")!))
  }
}
