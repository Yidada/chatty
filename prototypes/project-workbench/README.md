# Chatty project workbench prototype

A standalone browser prototype for project-wide progress and unified Mika intake.

## Run

From the repository root:

```sh
python3 -m http.server 4173 --bind 0.0.0.0 --directory prototypes/project-workbench
```

Open `http://localhost:4173`. A phone on the same LAN can use the Mac's LAN IP
with port 4173. Serve this directory only; do not serve the repository root.

## Try the flow

1. Open Mika and ask `缓存有哪些方案？` — it stays a discussion.
2. Send `帮我优化项目列表的加载速度` — a tracked task receipt appears.
3. Open that task, continue with Mika, and send `补充要求：先验证弱网场景`.
4. On the workbench, read a review item: unread clears while the action remains.
5. Accept its result or choose the blocked task's environment to resolve the action.
6. Use `模拟新进展` to advance a sample task and surface a new update.

All project creators are included. The project selector limits the workbench view.
Conversations, drafts, decisions and tasks persist in this browser's localStorage.
The Projects page and desktop sidebar offer reset. Storage is per browser/origin;
phone and desktop state are independent.

## Scope

Uses synthetic data and deterministic local responses. It does not call Multica,
an AI service, or a device; choosing an environment does not start actual execution.
Task tracking, navigation, state transitions, unread semantics and persistence are
implemented for the prototype. The optional Google font falls back to system fonts.

Source: `index.html`, `styles.css`, `app.js`; no build or package installation needed.
Lifecycle records: `.sdlc/changes/20260910-web-project-progress-and-mika-intake-prototype/`.
