import Foundation
import SwiftSoup

/// Manages fetching and parsing Paul Graham essays from paulgraham.com.
///
/// Handles web scraping and parsing of HTML structure to extract essay metadata.
/// The service provides a clean interface for loading essay data without managing
/// UI state or persistence concerns.
class EssayService {

  /// Fetches and parses essays from paulgraham.com/articles.html
  func loadEssays() async throws -> [Essay] {
    let url = URL(string: "https://www.paulgraham.com/articles.html")!
    let (data, _) = try await URLSession.shared.data(from: url)
    let html = String(data: data, encoding: .utf8) ?? ""

    return extractEssays(from: html)
  }

  func readEssay(from url: URL) async throws -> String {
    let html = try await fetchEssayContent(from: url)
    return parseEssay(html)
  }

  /// Fetches the raw HTML content of a specific essay
  func fetchEssayContent(from url: URL) async throws -> String {
    let (data, _) = try await URLSession.shared.data(from: url)
    return String(data: data, encoding: .utf8) ?? ""
  }

  /// Parses HTML of the essay page and extracts clean text content.
  ///
  /// Uses SwiftSoup to parse the HTML with Paul Graham's specific page structure
  /// and extracts the main essay content. Converts basic formatting to markdown
  /// while focusing on readable text output.
  func parseEssay(_ html: String) -> String {
    do {
      let doc = try SwiftSoup.parse(html)

      // Paul Graham's specific content selector
      let contentSelector =
        "body > table > tbody > tr > td:nth-child(3) > table:nth-child(4) > tbody > tr > td"

      guard let content = try doc.select(contentSelector).first() else {
        throw NSError(
          domain: "HTMLParsingError", code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Content not found"])
      }

      return try content.text(trimAndNormaliseWhitespace: true)

    } catch {
      return "Error loading essay content. Please try again."
    }
  }

  /// Extracts essay titles and URLs from HTML using regex patterns.
  ///
  /// Parses the specific structure of paulgraham.com/articles.html where essays
  /// follow the pattern: <a href="filename.html">Title</a>. The regex captures
  /// both the filename and title text to construct Essay objects with full URLs.
  private func extractEssays(from html: String) -> [Essay] {
    // Regex breakdown: <a href="([^"]+)">([^<]+)</a>
    // <a href=" - matches literal opening anchor tag with href attribute
    // ([^"]+)  - capture group 1: matches one or more characters that are NOT quotes
    //            this captures the filename (e.g., "greatwork.html")
    // ">       - matches literal quote and closing bracket
    // ([^<]+)  - capture group 2: matches one or more characters that are NOT <
    //            this captures the link text/title (e.g., "How to Do Great Work")
    // </a>     - matches literal closing anchor tag
    let pattern = #"<a href="([^"]+)">([^<]+)</a>"#

    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return []
    }

    let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

    return matches.compactMap { match -> Essay? in
      guard match.numberOfRanges >= 3,
        let filenameRange = Range(match.range(at: 1), in: html),
        let titleRange = Range(match.range(at: 2), in: html)
      else {
        return nil
      }

      let filename = String(html[filenameRange])
      let title = String(html[titleRange])

      // Only process relative links (essays), not absolute URLs (external links)
      guard !filename.hasPrefix("http") else { return nil }

      // Filter out non-essay files
      guard filename != "rss.html" else { return nil }

      guard let url = URL(string: "https://www.paulgraham.com/\(filename)") else {
        return nil
      }

      return Essay(title: title, url: url)
    }
  }
}
