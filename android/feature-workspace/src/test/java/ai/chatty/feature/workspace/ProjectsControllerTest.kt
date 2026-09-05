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
        override suspend fun projects() = ProjectPage(listOf(Project("p1", "Project", issue_count=125, done_count=25)), 1)
        override suspend fun statuses(): StatusCatalog { if (catalogFails) throw java.io.IOException("catalog unavailable"); return StatusCatalog(listOf(IssueStatusEntry("todo", "待开始", "todo"), IssueStatusEntry("qa_custom", "内部验收", "in_review"))) }
        override suspend fun issues(project: String?, noProject: Boolean?, limit: Int, offset: Int, query: String?, status: String?): IssuePage {
            this.offset = offset; this.noProject = noProject
            if (project == "slow") gate?.await()
            return if (offset == 0) IssuePage(listOf(issue.copy(project_id = project)), 2) else IssuePage(listOf(issue, issue.copy(id="i2")), 2)
        }
        override suspend fun issue(id: String) = issue
        override suspend fun updateIssue(id: String, body: IssueUpdate): Issue { writes++; update = body; gate?.await(); issue = issue.copy(status=body.status); return issue }
        override suspend fun runtimes() = emptyList<RuntimeDevice>()
        override suspend fun agents() = emptyList<ChatAgent>()
        override suspend fun squads() = emptyList<Squad>()
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
}
