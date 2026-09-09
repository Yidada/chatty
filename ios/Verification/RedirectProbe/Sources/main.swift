import Foundation
import ChattyCore
import ChattyFixtureSupport
let client = FixtureClient()
do {
    _ = try await client.projects()
    fatalError("Expected redirect to be rejected")
} catch let error as FixtureError {
    guard error == .http(302) else { fatalError("Unexpected fixture error: \(error)") }
    print("PASS: default FixtureClient rejects HTTP 302")
}

let api = APIClient(baseURL: URL(string: "http://127.0.0.1:8765")!, token: "synthetic", workspace: "fixture")
do {
    _ = try await api.data("/api/projects")
    fatalError("APIClient followed a redirect")
} catch APIError.http(302) {
    print("APIClient rejected 302 before redirect sink")
}
api.invalidate()
