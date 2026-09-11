package ai.chatty.feature.workspace
import ai.chatty.core.model.*
import ai.chatty.core.network.WorkspaceApi
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ProjectsControllerTest {
    private class Fake : WorkspaceApi {
        val row = Issue("i1", "T-1", "Test issue", "todo", project_id = "p1", revision = 7)
        var issue = row; var writes = 0; var update: IssueUpdate? = null; var offset = -1; var noProject: Boolean? = null
        var gate: CompletableDeferred<Unit>? = null
        var catalogFails = false
        var conflict = false
        var responseStatus: String? = null
        var pages: List<Issue>? = null
        var detailGate: CompletableDeferred<Unit>? = null
        override suspend fun me() = ChatUser("u1")
        override suspend fun projects() = ProjectPage(listOf(Project("p1", "Project", issue_count=125, done_count=25)), 1)
        override suspend fun statuses(): StatusCatalog { if (catalogFails) throw java.io.IOException("catalog unavailable"); return StatusCatalog(listOf(IssueStatusEntry("todo", "待开始", "todo"), IssueStatusEntry("qa_custom", "内部验收", "in_review"), IssueStatusEntry("done_custom", "完成", "done"), IssueStatusEntry("blocked", "受阻", "blocked"), IssueStatusEntry("in_progress", "进行中", "in_progress"))) }
        override suspend fun issues(project: String?, noProject: Boolean?, limit: Int, offset: Int, query: String?, status: String?, statuses: String?, sort: String?, direction: String?): IssuePage {
            this.offset = offset; this.noProject = noProject
            pages?.let { return IssuePage(it.drop(offset).take(limit), it.size) }
            if (project == "slow") gate?.await()
            return if (offset == 0) IssuePage(listOf(issue.copy(project_id = project)), 2) else IssuePage(listOf(issue, issue.copy(id="i2")), 2)
        }
        override suspend fun issue(id: String): Issue { detailGate?.await(); return pages?.find { it.id == id } ?: issue }
        override suspend fun updateIssue(id: String, body: IssueUpdate): Issue { writes++; update = body; gate?.await(); if (conflict) throw retrofit2.HttpException(retrofit2.Response.error<Issue>(409, okhttp3.ResponseBody.create(null, "conflict"))); issue = issue.copy(status=responseStatus ?: body.status, revision=(issue.revision ?: 0) + 1); return issue }
        override suspend fun runtimes() = emptyList<RuntimeDevice>()
        override suspend fun agents() = emptyList<ChatAgent>()
        override suspend fun squads() = emptyList<Squad>()
    }
    @Test fun directDetailLoadsCustomStatusCatalog() = runTest {
        val api = Fake(); api.issue = api.row.copy(status = "qa_custom")
        val c = ProjectsController(api, this); c.detail(api.issue); advanceUntilIdle()
        assertTrue(c.state.value.statuses.any { it.key == "done_custom" })
        assertNull(c.state.value.detailError)
    }
    @Test fun acceptanceRequiresConfirmedDoneCategory() = runTest {
        val api = Fake(); api.issue = api.row.copy(status = "qa_custom")
        val c = ProjectsController(api, this); c.overview(); advanceUntilIdle(); c.detail(api.issue); advanceUntilIdle()
        api.responseStatus = "qa_custom"; c.changeStatus("done_custom"); advanceUntilIdle()
        assertNotEquals("已验收", c.state.value.actionNotice)
        api.responseStatus = "done_custom"; c.detail(api.issue); advanceUntilIdle(); c.changeStatus("done_custom"); advanceUntilIdle()
        assertEquals("已验收", c.state.value.actionNotice)
    }
    @Test fun conflictRefreshesWithoutSuccessNotice() = runTest {
        val api = Fake(); api.issue = api.row.copy(status = "qa_custom")
        val c = ProjectsController(api, this); c.overview(); advanceUntilIdle(); c.detail(api.issue); advanceUntilIdle()
        api.conflict = true; api.issue = api.issue.copy(status = "blocked", revision = 9)
        c.changeStatus("done_custom"); advanceUntilIdle()
        assertEquals(9L, c.state.value.detail?.revision)
        assertEquals("blocked", c.state.value.detail?.status)
        assertNull(c.state.value.actionNotice)
        assertNotNull(c.state.value.detailError)
    }
    @Test fun unblockedFeedbackDoesNotClaimCompletion() = runTest {
        val api = Fake(); api.issue = api.row.copy(status = "blocked")
        val c = ProjectsController(api, this); c.overview(); advanceUntilIdle(); c.detail(api.issue); advanceUntilIdle()
        c.changeStatus("in_progress"); advanceUntilIdle()
        assertEquals("阻塞已解除，任务继续进行", c.state.value.actionNotice)
    }
    @Test fun catalogFailureDoesNotHideProjectsOrEnableEdits() = runTest {
        val api=Fake();api.catalogFails=true;val c=ProjectsController(api,this);c.overview();advanceUntilIdle()
        assertEquals(1,c.state.value.projects.size);assertTrue(c.state.value.statuses.isEmpty());assertNotNull(c.state.value.error)
    }
    @Test fun countsAreServerOwnedAndPagingDeduplicates() = runTest {
        val api=Fake();val c=ProjectsController(api,this);c.overview();advanceUntilIdle()
        assertEquals(.2f,progress(c.state.value.projects.single()),.001f)
        c.select("p1");advanceUntilIdle();c.more();advanceUntilIdle()
        assertEquals(1,api.offset);assertEquals(2,c.state.value.issues.size)
        c.select(NO_PROJECT);advanceUntilIdle();assertEquals(true,api.noProject)
    }
    @Test fun projectSwitchRejectsStaleResponse() = runTest {
        val api=Fake();api.gate=CompletableDeferred();val c=ProjectsController(api,this)
        c.select("slow");runCurrent();c.select("p2");advanceUntilIdle()
        api.gate!!.complete(Unit);advanceUntilIdle()
        assertEquals("p2",c.state.value.selected);assertEquals("p2",c.state.value.issues.single().project_id)
    }
    @Test fun customStatusSingleFlightSuppressesExecution() = runTest {
        val api=Fake();val c=ProjectsController(api,this);c.overview();advanceUntilIdle();c.select("p1");advanceUntilIdle();c.detail(api.row);advanceUntilIdle()
        api.gate=CompletableDeferred();c.changeStatus("qa_custom");c.changeStatus("qa_custom");runCurrent()
        assertEquals(1,api.writes);assertTrue(api.update!!.suppress_run);assertEquals(7L,api.update!!.expected_revision)
        api.gate!!.complete(Unit);advanceUntilIdle();assertEquals("qa_custom",c.state.value.detail?.status);assertFalse(c.state.value.saving)
    }
    @Test fun unknownStatusCannotBeSubmitted() = runTest {
        val api=Fake();val c=ProjectsController(api,this);c.overview();advanceUntilIdle();c.detail(api.row);advanceUntilIdle();c.changeStatus("invented");advanceUntilIdle();assertEquals(0,api.writes)
    }
    @Test fun returningToPagedListKeepsLoadedRowsQueryAndFilter() = runTest {
        val api = Fake(); api.pages = (1..55).map { api.row.copy(id = "i$it") }
        val c = ProjectsController(api, this)
        c.select("p1", "draft query", "todo"); advanceUntilIdle(); c.more(); advanceUntilIdle()
        assertEquals(55, c.state.value.issues.size)
        c.refresh(); runCurrent()
        assertEquals(55, c.state.value.issues.size)
        advanceUntilIdle()
        assertEquals(55, c.state.value.offset)
        assertEquals(55, c.state.value.issues.size)
        assertEquals("draft query", c.state.value.query)
        assertEquals("todo", c.state.value.filter)
    }
    @Test fun returningToDetailRefreshesItsRevisionWithoutLeavingPage() = runTest {
        val api = Fake(); val c = ProjectsController(api, this)
        c.select("p1"); advanceUntilIdle(); c.detail(api.row); advanceUntilIdle()
        api.issue = api.row.copy(revision = 9)
        c.refresh(); advanceUntilIdle()
        assertEquals("p1", c.state.value.selected)
        assertEquals("i1", c.state.value.detail?.id)
        assertEquals(9L, c.state.value.detail?.revision)
    }
    @Test fun leavingProjectRejectsLateDetailResponse() = runTest {
        val api = Fake(); val c = ProjectsController(api, this)
        api.detailGate = CompletableDeferred()
        c.detail(api.row); runCurrent(); c.overview(); runCurrent()
        api.detailGate!!.complete(Unit); advanceUntilIdle()
        assertNull(c.state.value.selected)
        assertNull(c.state.value.detail)
    }
}
