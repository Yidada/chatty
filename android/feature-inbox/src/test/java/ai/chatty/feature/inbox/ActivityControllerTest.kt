package ai.chatty.feature.inbox

import ai.chatty.core.model.ChatUser
import ai.chatty.core.model.Issue
import ai.chatty.core.model.IssuePage
import ai.chatty.core.model.IssueStatusEntry
import ai.chatty.core.model.IssueUpdate
import ai.chatty.core.model.ProjectPage
import ai.chatty.core.model.RuntimeDevice
import ai.chatty.core.model.Squad
import ai.chatty.core.model.ChatAgent
import ai.chatty.core.model.StatusCatalog
import ai.chatty.core.network.WorkspaceApi
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

private val STATUSES = listOf(
    IssueStatusEntry("in_progress", "进行中", "in_progress"),
    IssueStatusEntry("in_review", "待审核", "in_review"),
    IssueStatusEntry("blocked", "受阻", "blocked"),
    IssueStatusEntry("done", "已完成", "done")
)

private fun mkIssue(id: String, status: String, category: String? = null, updated: String = "2026-01-01T00:00:00Z", revision: Long = 1) =
    Issue(id = id, identifier = "CLE-$id", title = "title $id", status = status, status_category = category, revision = revision, updated_at = updated)

private class FakeReads(initial: Map<String, String> = emptyMap()) : ActivityReads {
    var stored = initial
    override suspend fun read(workspaceId: String) = stored
    override suspend fun write(workspaceId: String, reads: Map<String, String>) { stored = reads }
}

private class FakeApi : WorkspaceApi {
    override suspend fun me() = ChatUser("u1")
    override suspend fun projects() = ProjectPage(emptyList(), 0)
    override suspend fun issues(project: String?, noProject: Boolean?, limit: Int, offset: Int, query: String?, status: String?, statuses: String?, sort: String?, direction: String?): IssuePage = IssuePage(emptyList(), 0)
    override suspend fun issue(id: String) = mkIssue(id, "todo")
    override suspend fun updateIssue(id: String, body: IssueUpdate) = mkIssue(id, "todo")
    override suspend fun statuses() = StatusCatalog(STATUSES)
    override suspend fun runtimes(): List<RuntimeDevice> = emptyList()
    override suspend fun agents(): List<ChatAgent> = emptyList()
    override suspend fun squads(): List<Squad> = emptyList()
}

class ActivityControllerTest {
    @Test fun badge_counts_unique_unread_across_both_pages_without_attention_count() {
        val review = mkIssue("1", "in_review")
        val blocked = mkIssue("2", "blocked")
        val state = ActivityState(recent = listOf(review), actions = listOf(review, blocked), actionTotal = 2)
        assertEquals(2, state.unreadCount)
        val read = state.copy(reads = listOf(review, blocked).associate { it.id to activityFingerprint(it) })
        assertFalse(read.hasAttention)
        assertEquals(2, read.actionTotal)
    }

    @Test fun fingerprint_prefers_semantic_timestamp_then_status() {
        assertEquals("2026-02-01|in_review", activityFingerprint(mkIssue("1", "in_review", updated = "2026-02-01")))
    }

    @Test fun unread_compares_saved_fingerprint() {
        val i = mkIssue("1", "blocked", updated = "2026-02-01")
        assertTrue(activityUnread(i, emptyMap()))
        assertFalse(activityUnread(i, mapOf("1" to activityFingerprint(i))))
        assertTrue(activityUnread(i, mapOf("1" to "older")))
    }

    @Test fun needs_action_matches_categories() {
        assertTrue(activityNeedsAction(mkIssue("1", "in_review", "in_review"), STATUSES))
        assertTrue(activityNeedsAction(mkIssue("2", "blocked", "blocked"), STATUSES))
        assertFalse(activityNeedsAction(mkIssue("3", "done", "done"), STATUSES))
    }

    @Test fun needs_action_falls_back_to_catalog_category() {
        // Older servers omit status_category; the live catalog supplies it.
        assertTrue(activityNeedsAction(mkIssue("1", "in_review"), STATUSES))
    }

    @Test fun action_keys_uses_catalog_then_literals() {
        assertEquals("blocked,in_review", activityActionKeys(STATUSES))
    }

    @Test fun summary_and_status_name_are_stable() {
        assertEquals("结果已提交，等待验收。", activitySummary(mkIssue("1", "in_review", "in_review"), STATUSES))
        assertEquals("受阻", activityStatusName("blocked", STATUSES))
        assertEquals("进行中", activityStatusName("in_progress", emptyList()))
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test fun apply_moves_item_between_recent_and_actions_and_marks_read() = runTest {
        val reads = FakeReads()
        val controller = ActivityController(FakeApi(), reads, "w1", TestScope(testScheduler))
        controller.refresh()
        advanceUntilIdle()

        val open = mkIssue("7", "in_review", "in_review", updated = "2026-03-01")
        controller.apply(open)
        assertTrue(controller.state.value.actions.any { it.id == "7" })
        assertEquals(1, controller.state.value.actionTotal)
        assertFalse(activityUnread(open, controller.state.value.reads))

        controller.apply(mkIssue("7", "done", "done", updated = "2026-03-02"))
        assertFalse(controller.state.value.actions.any { it.id == "7" })
        assertEquals(0, controller.state.value.actionTotal)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test fun refresh_surfaces_status_catalog_failure() = runTest {
        val failing = object : WorkspaceApi by FakeApi() {
            override suspend fun statuses(): StatusCatalog = throw IllegalStateException("offline")
        }
        val controller = ActivityController(failing, FakeReads(), "w1", TestScope(testScheduler))
        controller.refresh()
        advanceUntilIdle()
        assertTrue(controller.state.value.actionError != null)
    }
}
