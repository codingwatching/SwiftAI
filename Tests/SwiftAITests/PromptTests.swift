import Testing
import SwiftAI
import Foundation

// MARK: - Test Helpers

extension PromptRepresentable {
  /// Extracts all text content from chunks, joined with newlines to separate paragraphs.
  /// This helper makes tests resilient to chunk merging or other implementation changes.
  var textContent: String {
    return chunks.compactMap { chunk in
      if case .text(let content) = chunk {
        return content
      }
      return nil
    }.joined(separator: "\n")
  }
}

// MARK: - Prompt Tests

@Test func promptBasicStringInitializer() {
  let prompt = Prompt("Hello, world!")
  
  #expect(prompt.textContent == "Hello, world!")
}

@Test func promptBuilderWithStrings() {
  let userInput = "Swift programming"
  let prompt = Prompt {
    "System: You are a helpful assistant."
    "User input: \(userInput)"
    "Please respond clearly."
  }
  
  let expectedText = "System: You are a helpful assistant.\nUser input: Swift programming\nPlease respond clearly."
  #expect(prompt.textContent == expectedText)
}

@Test func stringPromptRepresentableConformance() {
  let string: any PromptRepresentable = "Hello from string"
  
  #expect(string.textContent == "Hello from string")
}

@Test func promptFromChunks() {
  let chunks: [ContentChunk] = [
    .text("First part"),
    .text("Second part")
  ]
  let prompt = Prompt(chunks: chunks)
  
  #expect(prompt.textContent == "First part\nSecond part")
}

@Test func emptyPromptBuilder() {
  let prompt = Prompt {
    // Empty builder should work
  }
  
  #expect(prompt.textContent == "")
}

@Test func singleItemPromptBuilder() {
  let prompt = Prompt {
    "Single item"
  }
  
  #expect(prompt.textContent == "Single item")
}

// MARK: - Control Flow Tests

@Test func promptBuilderWithIfStatement() {
  let includeContext = true
  let prompt = Prompt {
    "Main content"
    if includeContext {
      "Additional context"
    }
  }
  
  #expect(prompt.textContent == "Main content\nAdditional context")
}

@Test func promptBuilderWithIfStatementFalse() {
  let includeContext = false
  let prompt = Prompt {
    "Main content"
    if includeContext {
      "Additional context"
    }
  }
  
  #expect(prompt.textContent == "Main content")
}

@Test func promptBuilderWithIfElseStatement() {
  let useAdvanced = true
  let prompt = Prompt {
    "System prompt"
    if useAdvanced {
      "Advanced mode instructions"
    } else {
      "Basic mode instructions"
    }
  }
  
  #expect(prompt.textContent == "System prompt\nAdvanced mode instructions")
}

@Test func promptBuilderWithIfElseStatementFalse() {
  let useAdvanced = false
  let prompt = Prompt {
    "System prompt"
    if useAdvanced {
      "Advanced mode instructions"
    } else {
      "Basic mode instructions"
    }
  }
  
  #expect(prompt.textContent == "System prompt\nBasic mode instructions")
}

@Test func promptBuilderWithForLoop() {
  let examples = ["Example 1", "Example 2", "Example 3"]
  let prompt = Prompt {
    "Here are some examples:"
    for example in examples {
      "- \(example)"
    }
  }
  
  let expectedText = "Here are some examples:\n- Example 1\n- Example 2\n- Example 3"
  #expect(prompt.textContent == expectedText)
}

@Test func promptBuilderWithEmptyForLoop() {
  let examples: [String] = []
  let prompt = Prompt {
    "Examples:"
    for example in examples {
      "- \(example)"
    }
  }
  
  #expect(prompt.textContent == "Examples:")
}

@Test func promptBuilderComplexControlFlow() {
  let includeExamples = true
  let examples = ["Swift", "Python"]
  let isAdvanced = false
  
  let prompt = Prompt {
    "Programming language guide"
    if isAdvanced {
      "Advanced concepts will be covered"
    } else {
      "This covers basic concepts"
    }
    if includeExamples {
      "Languages included:"
      for language in examples {
        "- \(language) programming"
      }
    }
  }
  
  let expectedText = "Programming language guide\nThis covers basic concepts\nLanguages included:\n- Swift programming\n- Python programming"
  #expect(prompt.textContent == expectedText)
}