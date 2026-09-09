# Development workflow and repository layout

Lifecycle artifacts belong in `.sdlc/changes/<change-id>/`, as configured by
[.sdlc/config.json](../.sdlc/config.json). See the [records index](../.sdlc/README.md)
for active changes, historical records and the directory migration map.

```text
.sdlc/
  config.json
  README.md
  changes/<change-id>/    # Intent, plan, decisions, review, state and evidence
    evidence/            # Curated logs, screenshots and verification results
  archive/iterations/    # Historical Android V1/V2 records
android/                 # Android implementation
ios/                    # iOS implementation and platform setup/release guides
docs/                   # Shared architecture and development guides
scripts/                # Reusable development and verification utilities
tests/device/ios/       # Reusable agent-device replay flows
```

## Working on a change

1. Read the repository instructions and the relevant change records.
2. Keep scope, decisions, implementation plans and verification evidence together
   in that change directory. Link to earlier work instead of copying its plan.
3. Read `.sdlc/config.json` and the change's `state.json` before advancing its
   lifecycle. Load the SDLC plugin only when explicitly requested; the plugin
   owns lifecycle stages, gates and artifact requirements.
4. Keep reusable scripts and test flows outside the lifecycle records. Store
   curated results in the owning change's `evidence/` directory. Keep private
   captures and build output in ignored `.tools/` directories.
5. Commit related code and lifecycle artifacts together. Update README links
   when the current work changes. A directory move never implies acceptance.

## Evidence discipline

- Record the command, result and evidence path for each acceptance claim.
- Retain failed checks and unresolved limitations alongside successful checks.
- Preserve raw historical logs, manifests and approval records. Their original
  paths and hashes identify the original run or approved document.
- Use a distinct run directory for new evidence; do not overwrite historical
  captures. Android device helpers accept `EVIDENCE_DIR`; their default is a
  timestamped directory under the native-experience change's `evidence/device-runs/`.
- Historical Android V1/V2 records remain under `.sdlc/archive/iterations/`.
  New work belongs to a change directory.
