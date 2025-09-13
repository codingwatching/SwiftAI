import Foundation

extension String {

  /// Splits text into overlapping chunks for AI processing
  ///
  /// - Parameters:
  ///   - chunkSize: Maximum characters per chunk.
  ///   - overlapSize: Characters of overlap between chunks (default: 0)
  ///
  /// - Returns: Array of text chunks with overlapping context
  func chunked(chunkSize: Int, overlapSize: Int = 0) -> [String] {
    // If text fits in one chunk, no chunking needed
    guard count > chunkSize else {
      return [self]
    }

    var chunks: [String] = []
    var startIndex = self.startIndex

    while startIndex < self.endIndex {
      // Calculate end index for this chunk
      let chunkEndIndex =
        self.index(startIndex, offsetBy: chunkSize, limitedBy: self.endIndex) ?? self.endIndex

      // Extract chunk
      let chunk = String(self[startIndex..<chunkEndIndex])
      chunks.append(chunk)

      // Move start index forward, leaving overlap
      let nextStartOffset = chunkSize - overlapSize
      guard
        let nextStartIndex = self.index(
          startIndex, offsetBy: nextStartOffset, limitedBy: self.endIndex)
      else {
        break
      }
      startIndex = nextStartIndex
    }

    return chunks
  }
}
