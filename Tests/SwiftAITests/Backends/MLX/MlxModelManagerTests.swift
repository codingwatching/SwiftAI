import Foundation
import Hub
import MLXLLM
import MLXLMCommon
import Testing

@testable import SwiftAI

struct MlxModelManagerTests {
  let hubAPI: HubApi
  let manager: MlxModelManager
  let storageDir: URL

  init() {
    storageDir = URL.temporaryDirectory.appending(path: "test-mlx-models")
    manager = MlxModelManager(storageDirectory: storageDir)
    hubAPI = HubApi(downloadBase: storageDir)
  }

  // MARK: - Tests

  @Test
  func testAreModelFilesAvailableLocally_RepoDoesNotExistLocally_ReturnsFalse() {
    let configuration = ModelConfiguration(id: "non-existent/model")
    let isDownloaded = manager.areModelFilesAvailableLocally(configuration: configuration)

    #expect(isDownloaded == false)
  }

  @Test
  func testAreModelFilesAvailableLocally_MarkerFileExists_ReturnsTrue() throws {
    // Create a test repository directory structure using HubAPI
    let repoId = makeTestRepoId()
    let repoPath = getLocalRepoLocation(for: repoId)
    try FileManager.default.createDirectory(at: repoPath, withIntermediateDirectories: true)

    // Create the .downloaded marker file
    let markerPath = repoPath.appending(path: ".downloaded")
    try "".write(to: markerPath, atomically: true, encoding: .utf8)

    let configuration = ModelConfiguration(id: repoId)
    let isDownloaded = manager.areModelFilesAvailableLocally(configuration: configuration)

    #expect(isDownloaded == true)
  }

  @Test
  func testAreModelFilesAvailableLocally_RepoExistsButNoMarkerFile_ReturnsFalse() throws {
    // Create a test repository directory without the marker file using HubAPI
    let repoId = makeTestRepoId()
    let repoPath = getLocalRepoLocation(for: repoId)
    try FileManager.default.createDirectory(at: repoPath, withIntermediateDirectories: true)

    let configuration = ModelConfiguration(id: repoId)
    let isDownloaded = manager.areModelFilesAvailableLocally(configuration: configuration)

    #expect(isDownloaded == false)
  }

  @Test
  func testAreModelFilesAvailableLocally_LocalDirectoryExists_ReturnsTrue() throws {
    // Create a test local directory with random name
    let localDir = storageDir.appending(path: makeTestRepoId())
    try FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)

    let configuration = ModelConfiguration(directory: localDir)
    let isDownloaded = manager.areModelFilesAvailableLocally(configuration: configuration)

    #expect(isDownloaded == true)
  }

  @Test
  func testAreModelFilesAvailableLocally_LocalDirectoryDoesNotExist_ReturnsFalse() {
    let nonExistentDir = storageDir.appending(path: makeTestRepoId())
    let configuration = ModelConfiguration(directory: nonExistentDir)
    let isDownloaded = manager.areModelFilesAvailableLocally(configuration: configuration)

    #expect(isDownloaded == false)
  }

  // MARK: - Utility Functions

  private func makeTestRepoId(prefix: String = "test-model") -> String {
    let randomSuffix = UUID().uuidString.prefix(4)
    return "\(prefix)/repo-\(randomSuffix)"
  }

  private func getLocalRepoLocation(for repoId: String) -> URL {
    let repo = Hub.Repo(id: repoId)
    return hubAPI.localRepoLocation(repo)
  }
}
