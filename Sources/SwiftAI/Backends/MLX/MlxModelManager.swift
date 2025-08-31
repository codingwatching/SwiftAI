import Foundation
import Hub  // TODO: Maybe add @preconcurrency
import MLXLMCommon

/// Centralized manager for MLX model loading, caching, and lifecycle management.
///
/// This manager handles:
/// - Model downloading
/// - Model sharing between multiple LLM instances
public actor MlxModelManager {
  /// Shared instance of the global model manager.
  static private var _shared: MlxModelManager?
  static private var wasConfigured = false
  static public let defaultStorageDirectory = URL.documentsDirectory.appending(path: "mlx-models")

  /// Configures the global model manager with a custom storage directory.
  ///
  /// This method should be called once during app startup, before accessing the shared instance.
  /// Subsequent calls to this method will be ignored.
  ///
  /// - Parameter storageDirectory: The directory where model files will be stored.
  /// - Note: If this method is not called, the shared instance will use the default storage directory.
  /// - Warning: This method should only be called from the main thread during app startup.
  ///
  /// # Example
  ///
  /// ```swift
  /// // During app startup
  /// let customDirectory = URL.documentsDirectory.appending(path: "custom-models")
  /// MlxModelManager.configureOnce(storageDirectory: customDirectory)
  /// ```
  public static func configureOnce(storageDirectory: URL) {
    guard !wasConfigured else {
      return
    }

    wasConfigured = true
    _shared = MlxModelManager(storageDirectory: storageDirectory)
  }

  /// The shared instance of the model manager.
  ///
  /// If `configureOnce(storageDirectory:)` was called, returns the configured instance.
  /// Otherwise, returns an instance using the default storage directory.
  ///
  /// - Returns: The shared MlxModelManager instance.
  public static var shared: MlxModelManager {
    if let instance = _shared {
      return instance
    }

    // Create default instance if not configured
    let defaultInstance = MlxModelManager()
    if !wasConfigured {
      _shared = defaultInstance
      wasConfigured = true
    }
    return defaultInstance
  }

  #if DEBUG
  /// Resets the configuration for testing purposes.
  ///
  /// - Warning: This method is only available in DEBUG builds and should only be used in tests.
  public static func _resetForTesting() {
    _shared = nil
    wasConfigured = false
  }
  #endif

  /// Cache for loaded model containers.
  private let modelCache = NSCache<NSString, ModelContainer>()

  /// Hub API instance for downloading models.
  private let hubAPI: HubApi

  /// Creates a new model manager instance.
  ///
  /// - Parameter storageDirectory: The directory where model files will be stored.
  ///   Defaults to `~/Documents/mlx-models/`.
  private init(storageDirectory: URL = defaultStorageDirectory) {
    self.hubAPI = HubApi(downloadBase: storageDirectory)
  }

  /// Check if model files exist on disk
  func isModelDownloaded(configuration: ModelConfiguration) -> Bool {
    // Placeholder implementation - will be fully implemented in Milestone 2
    return false
  }

  /// Get or load a model container for the given configuration
  func getOrLoadModelContainer(for configuration: ModelConfiguration) async throws -> ModelContainer
  {
    let key = makeModelCacheKey(configuration: configuration)
    if let modelContainer = modelCache.object(forKey: key) {
      return modelContainer
    }

    let modelContainer = try await MLXLMCommon.loadModelContainer(
      hub: self.hubAPI,
      configuration: configuration
    )
    modelCache.setObject(modelContainer, forKey: key)

    return modelContainer
  }
}

func makeModelCacheKey(configuration: ModelConfiguration) -> NSString {
  var hasher = Hasher()
  switch configuration.id {
  case .id(let id, let revision):
    hasher.combine(id)
    hasher.combine(revision)
  case .directory(let url):
    hasher.combine(url)
  @unknown default:
    // TODO: IS there a better way to handle this?
    fatalError("Unknown model configuration type")
  }
  hasher.combine(configuration.tokenizerId)
  hasher.combine(configuration.overrideTokenizer)
  hasher.combine(configuration.defaultPrompt)
  hasher.combine(configuration.extraEOSTokens)
  let hash = hasher.finalize()
  return NSString(string: String(format: "%02X", hash))
}
