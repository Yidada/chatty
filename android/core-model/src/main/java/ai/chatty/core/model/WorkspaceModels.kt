package ai.chatty.core.model
import kotlinx.serialization.Serializable

@Serializable data class Project(val id: String, val title: String, val description: String? = null, val status: String = "planned", val priority: String = "none", val issue_count: Int = 0, val done_count: Int = 0, val due_date: String? = null)
@Serializable data class ProjectPage(val projects: List<Project>, val total: Int)
@Serializable data class Issue(val id: String, val identifier: String, val title: String, val status: String, val status_category: String? = null, val priority: String = "none", val description: String? = null, val project_id: String? = null, val assignee_id: String? = null, val assignee_type: String? = null, val due_date: String? = null, val revision: Long? = null,
    val creator_id: String? = null, val creator_type: String? = null, val updated_at: String? = null, val last_activity_at: String? = null)
@Serializable data class IssuePage(val issues: List<Issue>, val total: Int)
@Serializable data class IssueStatusEntry(val key: String, val name: String, val category: String, val archived_at: String? = null)
@Serializable data class StatusCatalog(val statuses: List<IssueStatusEntry>)
// Progress edits do not implicitly start an agent. Execution stays an explicit action in Multica.
@Serializable data class IssueUpdate(val status: String, val suppress_run: Boolean, val expected_revision: Long? = null)
@Serializable data class RuntimeDevice(val id: String, val name: String, val custom_name: String? = null, val status: String = "offline", val runtime_mode: String = "local", val provider: String = "", val device_info: String = "", val last_seen_at: String? = null)
@Serializable data class Squad(val id: String, val name: String, val description: String = "", val leader_id: String = "", val member_count: Int? = null, val archived_at: String? = null)
