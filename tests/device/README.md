# Device replay flows

`ios/` contains the reusable agent-device flows for ChattyFixture:

- `p0-navigation.ad`: foundation navigation smoke flow.
- `v1-core.ad`, `v1-resources.ad`, `v1-workspaces.ad`: V1 fixture scenarios.

Run from the repository root. See [iOS setup](../../ios/README.md) for fixture
setup, simulator selection and `scripts/ios-v1-replay.sh` usage. V1 screenshots
use the owning iOS change's `evidence/v1/` paths; replay JSON goes to the ignored,
timestamped `.tools/ios-v1/` run directory. Preserve committed captures before
intentionally refreshing that evidence.

Historical verification manifests retain the flow paths and hashes from their
original runs. Moving flows and updating screenshot destinations does not rerun
those scenarios. See [the migration map](../../.sdlc/README.md).
