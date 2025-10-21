import SwiftDiagnostics


/// An error that is shown to the client when the @Generable macro is used incorrectly.
struct GenerableMacroError: DiagnosticMessage, Error {
  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity

  init(message: String, id: String) {
    self.message = message
    self.diagnosticID = MessageID(domain: "GenerableMacro", id: id)
    self.severity = .error
  }
}
