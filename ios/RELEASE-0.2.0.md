# Apple clients 0.2.0 — activity contract 1.1

Applies to iOS build 3 and macOS build 2. Both clients use the same ChattyCore activity and transition logic.

- Recent activity retains read tasks across all visible workspace creators.
- Needs attention groups loaded tasks into review and blocked, including custom status keys. Paging shows loaded and server total counts.
- Navigation indicators represent unread updates only; unread counting deduplicates recent and attention tasks. Reading does not resolve work.
- Status writes require a known revision and a matching server receipt with a newer integer revision. Done acceptance checks category, including custom catalog statuses. Conflicts and uncertain receipts never report approval success.
- Review acceptance reports “已验收”. Blocked-to-in-progress reports work resumed. Discussion prepares the existing chat draft and never resolves blocking automatically.
- macOS VoiceOver announces the same unread semantics as the visible dot.

Validation: 58 ChattyCore tests pass, including deduplicated unread state, read pending tasks, fingerprint and rejected status receipts. Both Release archives compile and are signed; macOS builds for arm64 and x86_64. Distribution availability and real-account interaction require separate checks by the releasing operator. No production task writes were made by these tests.

Build from the versioned project generators. Signing credentials remain local command parameters. Never commit archives, provisioning profiles, certificates, local paths, or raw release logs.
