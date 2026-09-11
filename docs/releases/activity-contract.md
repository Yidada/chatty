# Activity contract 1.1 — release 0.2.0

Shared acceptance contract for Web, Android, iOS and macOS.

- Scope: all visible tasks in the selected workspace, regardless of creator. This is not a personal-assignee queue.
- Recent activity: tasks ordered by last activity; reading keeps the task in the list.
- Needs attention: categories `in_review` and `blocked`, including custom status keys. Present two groups: 待验收 / 受阻. Group contents reflect loaded pages, not fabricated category totals.
- Unread: deduplicate recent+attention items by ID, compare `last_activity_at ?? updated_at ?? String(revision ?? 0)` followed by `|status` to local read markers. Only successful detail loading marks read. The navigation dot represents unread only. Attention count is independent.
- Approval: PUT requested done key with expected_revision and suppress_run. Accept only a response with matching issue ID, requested key, category done and an integer revision greater than the previous revision. A 2xx alone is insufficient. Reject stale, mismatched or contradictory receipts and request a refresh. A 409 never reports success.
- Blocked discussion: prepares a draft. Sending or reading does not clear blocked. An observed transition to in_progress means work resumed; done means task completed.
- Pagination: recent and attention queries are independent; loading more must keep the selected scope. Unread dots describe locally observed updates, not a global cross-device unread count.
- Preserve existing credential/account/workspace isolation, nonblocking FIFO and uncertain-send handling.

Acceptance scenarios: custom review status, blocked task beyond first 50 recent items, duplicate task across feeds, read failure, read without completion, task activity changes, valid/invalid approval receipt, conflict, blocked discussion, resumed task, completed task.

Distribution is tracked separately: hosted URL, APK, TestFlight processing/group availability, notarized DMG. A successful build alone does not establish availability in all channels.
