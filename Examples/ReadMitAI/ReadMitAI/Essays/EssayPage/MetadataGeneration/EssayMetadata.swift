import SwiftAI

@Generable
struct EssayMetadata {
  @Guide(description: "Main topic or theme of the essay")
  let topic: String

  @Guide(description: "Reading difficulty level", .anyOf(["Beginner", "Intermediate", "Advanced"]))
  let difficulty: String

  @Guide(description: "Main themes discussed in the essay", .minimumCount(1), .maximumCount(3))
  let keyThemes: [String]
}
