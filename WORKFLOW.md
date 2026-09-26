# Codex, Xcode, and GitHub workflow

## The shared project

Use one local repository for both Codex and Xcode:

`/Users/shilppatel/Documents/developer_1/AirPods Audio Router/AirPods Audio Router`

Open `AirPods Audio Router.xcodeproj` inside that folder in Xcode. The active GitHub repository is [shilp-tech/AirPodsAudioRouterr](https://github.com/shilp-tech/AirPodsAudioRouterr), on `main`.

The current Codex project points to the outer container folder. A local `AGENTS.md` there redirects project work to this repository. For new chats, prefer selecting the inner repository as the Codex project folder and using local mode. Do not select a separate worktree if you want the same Xcode window to show edits.

## What updates when

| Action | Codex / local files | Xcode | GitHub |
| --- | --- | --- | --- |
| Codex saves source changes | Files change in this repository | Saved source is available in the same project | Waits for checks, commit, push |
| You save an edit in Xcode | Codex can read the saved change | Editor has the change | Ask Codex to check and sync it |
| You press Command-R | No source sync needed | Rebuilds and runs the latest saved source | No automatic push from Run |
| Codex completes a task | Reviews and checks the task changes | Uses the same checked files | Commits and pushes if checks pass |
| You edit a file on GitHub | Local file is unchanged until fetched/merged | Sees it after local integration | Remote changes immediately |

Xcode's source group uses filesystem synchronization, so app source files created inside `AirPods Audio Router/` can appear without manually adding each file reference. A paused preview may need Resume. The running app does not update merely because a source file changed: press Command-R. Save Xcode edits before asking Codex to change the same files; avoid editing the same file in both places simultaneously.

## Your normal routine

1. Give the feature or fix request in Codex.
2. Codex edits the shared files, checks the result, and pushes the completed changes to GitHub under the standing instruction in `AGENTS.md`.
3. Press Command-R in Xcode to see the updated app.
4. Refresh GitHub to see the commit.

If you made the changes in Xcode, save them and tell Codex: **“Review my saved Xcode changes, build, and sync to GitHub.”** No background watcher is installed; GitHub updates happen at completed task boundaries, not on every keystroke.

If a build fails, Codex should fix the task's failure before publishing. If the network/push fails, the commit remains local and Codex should explicitly report that GitHub is not yet synchronized. Credentials, build products, and per-user Xcode state intentionally remain local.

## Checks and recovery

Run the reproducible local build from this repository:

```sh
bash scripts/check.sh
```

It uses local ad-hoc signing and temporary DerivedData without changing Xcode project signing settings. It verifies the starter app compiles; it does not test audio capture or routing.

For sync status, use `git status --short --branch`. After a successful fetch, `git rev-list --left-right --count HEAD...origin/main` reports local-only and remote-only commits; `0 0` means the fetched histories match. Remote status is only as fresh as the last fetch/push. Uncommitted edits are shown separately by `git status`.

Ask Codex to revert an unwanted published commit with a new revert commit. Do not force-push or use a hard reset to undo routine work. No scheduled monitor, automatic pull loop, or GitHub build workflow is part of this setup.

## How the Codex instruction persists

The repository's `AGENTS.md` records the agreed check/commit/push workflow. OpenAI documents this file as project guidance loaded by Codex; it does not itself run a background process. [Official AGENTS.md documentation](https://learn.chatgpt.com/docs/agent-configuration/agents-md).
