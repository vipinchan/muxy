import Testing

@testable import Muxy

@Suite("PullRequestList JSON fields")
struct PullRequestListFieldsTests {
    @Test("excludes statusCheckRollup when checks are disabled")
    func excludesChecks() {
        let fields = GitRepositoryService.pullRequestListJSONFields(includeChecks: false)
        #expect(!fields.contains("statusCheckRollup"))
        #expect(fields.contains("number"))
        #expect(fields.contains("headRefName"))
    }

    @Test("includes statusCheckRollup when checks are enabled")
    func includesChecks() {
        let fields = GitRepositoryService.pullRequestListJSONFields(includeChecks: true)
        #expect(fields.contains("statusCheckRollup"))
    }
}
