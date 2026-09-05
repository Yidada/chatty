package ai.chatty.feature.workspace
import ai.chatty.core.model.*
import ai.chatty.core.network.WorkspaceApi
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class NavigationProjectBoundaryTest {
    private class Fake : WorkspaceApi {
        val row = Issue("i1", "T-1", "Test issue", "todo", project_id = "p1", revision = 7)
        var issue = row; var writes = 0; var update: IssueUpdate? = null; var offset = -1; var noProject: Boolean? = null
        var gate: CompletableDeferred<Unit>? = null
        var catalogFails = false
        var pages: List<Issue>? = null
        var failAtOffset: Int? = null
        var detailFails = false
        var detailGate: CompletableDeferred<Unit>? = null
        override suspend fun projects() = ProjectPage(listOf(Project("p1", "Project", issue_count=125, done_count=25)), 1)
        override suspend fun statuses(): StatusCatalog { if (catalogFails) throw java.io.IOException("catalog unavailable"); return StatusCatalog(listOf(IssueStatusEntry("todo", "待开始", "todo"), IssueStatusEntry("qa_custom", "内部验收", "in_review"))) }
        override suspend fun issues(project: String?, noProject: Boolean?, limit: Int, offset: Int, query: String?, status: String?): IssuePage {
            this.offset = offset; this.noProject = noProject
            if (offset == failAtOffset) throw java.io.IOException("synthetic page failure")
            pages?.let { return IssuePage(it.drop(offset).take(limit), it.size) }
            if (project == "slow") gate?.await()
            return if (offset == 0) IssuePage(listOf(issue.copy(project_id = project)), 2) else IssuePage(listOf(issue, issue.copy(id="i2")), 2)
        }
        override suspend fun issue(id: String): Issue { detailGate?.await(); if (detailFails) throw java.io.IOException("synthetic detail failure"); return pages?.find { it.id == id } ?: issue }
        override suspend fun updateIssue(id: String, body: IssueUpdate): Issue { writes++; update = body; gate?.await(); issue = issue.copy(status=body.status); return issue }
        override suspend fun runtimes() = emptyList<RuntimeDevice>()
        override suspend fun agents() = emptyList<ChatAgent>()
        override suspend fun squads() = emptyList<Squad>()
    }

    @Test fun failedSecondPageRefreshPreservesAllLoadedRowsAndFilter() = runTest {
        val api = Fake(); api.pages = (1..55).map { api.row.copy(id = "i$it") }
        val c = ProjectsController(api, this)
        c.select("p1", "Issue", "todo"); advanceUntilIdle(); c.more(); advanceUntilIdle()
        val before = c.state.value
        api.failAtOffset = 50; c.refresh(); advanceUntilIdle()
        assertEquals(before.issues, c.state.value.issues)
        assertEquals(before.offset, c.state.value.offset)
        assertEquals(before.total, c.state.value.total)
        assertEquals("Issue", c.state.value.query); assertEquals("todo", c.state.value.filter)
        assertNotNull(c.state.value.error); assertFalse(c.state.value.loading)
        api.failAtOffset = null; c.refresh(); advanceUntilIdle()
        assertEquals(55, c.state.value.issues.size); assertNull(c.state.value.error)
    }
    @Test fun failedDetailRefreshKeepsPageAndPreventsStaleWrite() = runTest {
        val api = Fake(); val c = ProjectsController(api, this)
        c.overview(); advanceUntilIdle(); c.select("p1"); advanceUntilIdle(); c.detail(api.row); advanceUntilIdle()
        api.detailFails = true; c.refresh(); advanceUntilIdle()
        assertEquals("i1", c.state.value.detail?.id); assertNotNull(c.state.value.detailError)
        c.changeStatus("qa_custom"); advanceUntilIdle(); assertEquals(0, api.writes)
        api.detailFails = false; api.issue = api.issue.copy(revision = 9); c.refresh(); advanceUntilIdle()
        assertEquals(9L, c.state.value.detail?.revision); assertNull(c.state.value.detailError)
        c.closeDetail(); assertNull(c.state.value.detail); assertEquals("p1", c.state.value.selected)
    }
}
