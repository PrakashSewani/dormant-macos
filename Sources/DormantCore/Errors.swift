public enum DormantError: Error, Equatable, Sendable {
  case notAProject
  case gitUnavailable
  case archiveExists
  case targetNotEmpty
  case tarFailed(stderr: String)
  case verificationFailed(details: String)
  case registryFailure
  case installCommandFailed(cmd: String, status: Int32, stderr: String)
  case cloneFailed(stderr: String)
}
