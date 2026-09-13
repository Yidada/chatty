## AI-Native SDLC Integration

- Load `$ai-native-sdlc` only when the user explicitly invokes it.
- Keep lifecycle artifacts in `.sdlc/changes/<change-id>/` and commit them with the related code.
- Read `.sdlc/config.json` and the active change's `state.json` before advancing the workflow.
- Repository and closer `AGENTS.md` instructions own architecture, commands, style, and technical constraints. The plugin owns lifecycle stages, risk, gates, artifacts, and evidence.

## asc cli reference

See `ASC.md` for the command catalog and workflows.
