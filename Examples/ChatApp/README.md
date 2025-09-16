# ChatApp: SwiftAI Interactive Chat Demo

> **A simple chat application demonstrating SwiftAI integration for iOS and macOS.**

ChatApp is a sample demo app where you can chat with various AI models. Switch between Apple's on-device models and MLX models to see how SwiftAI's unified API works across different implementations.

## 📱 App Features

- Chat with text
- Choose between Apple System LLM and 10+ MLX models
- Local inference

---

## 📁 Codebase Structure

```text
ChatApp/
├── App.swift                    # App entry point
├── ⭐ ChatViewModel.swift       # Core SwiftAI integration
├── ⭐ LLMProvider.swift         # Model instantiation
├── ModelID.swift                # Catalog of Models to choose from
├── ChatView.swift               # Main chat interface
├── Views/
│   ├── ConversationView.swift   # Chat view
│   ├── MessageView.swift        # Individual message UI
│   ├── PromptField.swift        # Input field
│   └── Toolbar/
│       ├── ChatToolbarView.swift  # Model selection & controls
│       └── ErrorView.swift        # Error display
└── ChatApp.entitlements           # App permissions
```

---

## 🔥 Key Concepts in App

### 1. Model Abstraction - Unified API Across Implementations

SwiftAI represents all language models using a single `LLM` protocol. This makes it easy to switch between different model implementations without changing your business logic.

**Example from ChatApp:**

```swift
class LLMProvider {
  func getLLM(for model: ModelID) -> any LLM {
    switch model {
    case .afm:
      return SystemLLM()  // Apple's on-device model
    case .qwen3_0_6b:
      return modelManager.llm(with: LLMRegistry.qwen3_0_6b_4bit)  // MLX model
    case .mistral_7b:
      return modelManager.llm(with: LLMRegistry.mistral7B4bit)    // MLX model
    }
  }
}

// Same code works with any model
let response = try await llm.reply(to: "Hello, how are you?")
```

### 2. Model Availability Monitoring - Understanding `llm.availability`

ChatApp demonstrates how to monitor and respond to different model availability states in real-time.

**The Three Main States:**

```swift
public enum LLMAvailability {
  case available                           // ✅ Ready to use
  case unavailable(reason: LLMUnavailabilityReason)  // ❌ Not ready
  case downloading(progress: Double)       // ⏳ Downloading model
}
```

---

## 🚀 Running the App

### Requirements

- iOS 26.0+ / macOS 26.0+
- Xcode 26.0+
- Swift 5.10+

- Apple Intelligence ON to use Apple Foundation Model
- Physical Phone or Mac to run MLX models

### Setup

1. **Clone the repository:**

   ```bash
   git clone https://github.com/mi12labs/SwiftAI.git
   cd SwiftAI/Examples/ChatApp
   ```

2. **Open in Xcode:**

   ```bash
   open ChatApp.xcodeproj
   ```

3. **Run the app:**
   - Select your target device (Mac or Physical Phone)
   - Press `Cmd+R` to build and run
