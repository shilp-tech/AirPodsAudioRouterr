# AirPods Audio Router working agreement

## One shared checkout

- Work in this repository, which contains `AirPods Audio Router.xcodeproj`, using the local checkout shared with Xcode. Do not create another checkout/worktree for routine work unless the user requests isolation.
- The active repository is `https://github.com/shilp-tech/AirPodsAudioRouterr.git`, branch `main`. The earlier repository without the trailing `r` is not the active destination.
- Start by checking the repository root, branch, remotes, and working tree. Preserve existing user edits. Do not run Git from the outer container folder, which resolves to an unrelated ancestor repository.
- Application sources belong under `AirPods Audio Router/`, the Xcode filesystem-synchronized source group. Keep documentation and development scripts outside that app source directory.

## Completion and GitHub sync

The user has requested automatic GitHub updates after each completed Codex task and its applicable checks. This is standing authorization to commit and push completed project changes to the verified `origin/main`; do not ask for repeat confirmation unless a new risk or ambiguity requires it.

1. Review the diff and preserve unrelated or unfinished work. Fetch origin when checking remote state; fast-forward a clean checkout if appropriate. Resolve ordinary conflicts while preserving both sides' intent. Never force-push or discard user work.
2. For source, project, or build-script changes, run `bash scripts/check.sh` and any relevant tests. For documentation-only changes, check the diff and links without needlessly rebuilding. Fix failures caused by the task. Do not publish a failed code change as a completed task.
3. Review files before staging. This repository is public. Exclude credentials, signing material, build products, Xcode user state, and unrelated files. Stage the intended changes explicitly.
4. Run `git diff --cached --check`, commit with a descriptive message, and push to `origin main`. Preserve existing commits; never rewrite published history for routine sync.
5. Verify the push succeeded and report the commit, validation result, and any remaining local changes. If push fails, retain the local commit and say clearly that GitHub is not synchronized.

Do not install a background save watcher. Xcode edits are shared locally as soon as saved, but are published when the user asks Codex to review/check/sync them or when they are included in the current authorized task. Do not push an unrelated pre-existing change merely to make the checkout clean.

## Xcode and scope

- Use the `AirPods Audio Router` scheme and `My Mac` destination. A running app needs a rebuild/relaunch (Command-R) to reflect source changes; file sharing is not live code injection.
- The checked-in deployment target is currently 26.2 and Swift language mode is 5, with the installed Swift 6.2.4 compiler. Do not silently change these settings.
- Read `ARCHITECTURE_RESEARCH.md` before audio implementation. Implement only the feature requested; project setup does not authorize building the full router.
- Keep UI/control work out of audio real-time callbacks when audio code is introduced.
