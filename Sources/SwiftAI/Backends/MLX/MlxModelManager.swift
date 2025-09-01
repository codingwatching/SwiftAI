import Foundation
import Hub  // TODO: Maybe add @preconcurrency
import MLXLMCommon

/// Centralized manager for MLX model loading, caching, and lifecycle management.
///
/// This manager handles:
/// - Model downloading
/// - Model sharing between multiple LLM instances
actor MlxModelManager {

  // MARK: - Properties

  /// Cache for loaded model containers.
  ///
  /// This avoids loading the same model in memory multiple times.
  /// Cached models are subject to eviction when resources are low.
  private let modelCache = NSCache<NSString, ModelContainer>()

  /// Hub API instance for downloading models.
  ///
  /// Marked as `nonisolated` because HubApi is thread-safe and needs to be accessed
  /// from `nonisolated` methods like `areModelFilesAvailableLocally`.
  private nonisolated let hubAPI: HubApi

  // MARK: - Initialization

  /// Creates a new model manager instance.
  ///
  /// - Parameter storageDirectory: The directory where model files will be stored.
  init(storageDirectory: URL) {
    self.hubAPI = HubApi(downloadBase: storageDirectory)
  }

  // MARK: - Public Interface

  /// Get or load a model container for the given configuration.
  ///
  /// This method first checks the cache for an existing model container. If not found,
  /// it loads the model from disk/downloads it, caches it, and returns the container.
  ///
  /// - Parameter configuration: The model configuration to load.
  /// - Returns: A loaded ModelContainer instance.
  /// - Throws: An error if the model cannot be loaded.
  func getOrLoadModel(
    forConfiguration configuration: ModelConfiguration
  ) async throws -> ModelContainer {
    let key = makeModelCacheKey(fromConfiguration: configuration)

    // Check cache first.
    if let modelContainer = modelCache.object(forKey: key) {
      return modelContainer
    }

    // Load the model.
    let modelContainer = try await MLXLMCommon.loadModelContainer(
      hub: self.hubAPI,
      configuration: configuration
    )

    // Mark the model as downloaded since we successfully loaded it.
    try markModelAsDownloaded(configuration: configuration)

    // Cache the loaded model.
    modelCache.setObject(modelContainer, forKey: key)

    return modelContainer
  }

  /// Check if model files exist locally on disk.
  ///
  /// For remote models, this checks both that the repository directory exists
  /// and that a `.downloaded` marker file is present. For local directory models,
  /// it simply checks if the directory exists.
  ///
  /// - Parameter configuration: The model configuration to check.
  /// - Returns: `true` if the model files are available locally, `false` otherwise.
  nonisolated func areModelFilesAvailableLocally(configuration: ModelConfiguration) -> Bool {
    switch configuration.id {
    case .id(let id, _):
      return isRemoteModelAvailable(id: id)

    case .directory(let url):
      return isLocalDirectoryModelAvailable(url: url)

    @unknown default:
      return false
    }
  }

  // MARK: - Private Helpers - Model Availability

  /// Check if a remote model is available locally.
  ///
  /// - Parameter id: The model repository ID.
  /// - Returns: `true` if the model is downloaded and ready to use.
  private nonisolated func isRemoteModelAvailable(id: String) -> Bool {
    let repo = Hub.Repo(id: id)
    let localRepoPath = hubAPI.localRepoLocation(repo)

    // Check if the repository directory exists
    guard FileManager.default.fileExists(atPath: localRepoPath.path) else {
      return false
    }

    // Check if the .downloaded marker file exists
    let downloadedMarkerPath = localRepoPath.appending(path: ".downloaded")
    return FileManager.default.fileExists(atPath: downloadedMarkerPath.path)
  }

  /// Check if a local directory model is available.
  ///
  /// - Parameter url: The local directory URL.
  /// - Returns: `true` if the directory exists.
  private nonisolated func isLocalDirectoryModelAvailable(url: URL) -> Bool {
    return FileManager.default.fileExists(atPath: url.path)
  }

  // MARK: - Private Helpers - Download Management

  /// Mark a model as downloaded by creating a .downloaded marker file.
  ///
  /// This method only applies to remote models. Local directory models
  /// don't need download markers.
  ///
  /// - Parameter configuration: The model configuration to mark as downloaded.
  /// - Throws: An error if the marker file cannot be created.
  private func markModelAsDownloaded(configuration: ModelConfiguration) throws {
    switch configuration.id {
    case .id(let id, _):
      try createDownloadMarker(for: id)

    case .directory(_):
      // Local directory models don't need download markers
      return

    @unknown default:
      throw LLMError.generalError("Unknown model configuration type")
    }
  }

  /// Create a download marker file for a remote model.
  ///
  /// - Parameter id: The model repository ID.
  /// - Throws: An error if the marker file cannot be created.
  private func createDownloadMarker(for id: String) throws {
    let repo = Hub.Repo(id: id)
    let localRepoPath = hubAPI.localRepoLocation(repo)
    let downloadedMarkerPath = localRepoPath.appending(path: ".downloaded")

    try "".write(to: downloadedMarkerPath, atomically: true, encoding: .utf8)
  }

  // MARK: - Private Helpers - Cache Management

  /// Generate a cache key for the given model configuration.
  ///
  /// The key is generated by hashing all relevant configuration properties
  /// to ensure that different configurations get different cache entries.
  ///
  /// - Parameter configuration: The model configuration.
  /// - Returns: A cache key string.
  private func makeModelCacheKey(fromConfiguration: ModelConfiguration) -> NSString {
    var hasher = Hasher()

    // Hash the model ID
    switch fromConfiguration.id {
    case .id(let id, let revision):
      hasher.combine(id)
      hasher.combine(revision)
    case .directory(let url):
      hasher.combine(url)
    @unknown default:
      // TODO: Is there a better way to handle this?
      assertionFailure("Unknown model configuration type")
      return ""
    }

    // Hash other configuration properties
    hasher.combine(fromConfiguration.tokenizerId)
    hasher.combine(fromConfiguration.overrideTokenizer)
    hasher.combine(fromConfiguration.defaultPrompt)
    hasher.combine(fromConfiguration.extraEOSTokens)

    let hash = hasher.finalize()
    return NSString(string: String(format: "%02X", hash))
  }
}
