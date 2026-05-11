---
name: setup-cloud-bootstrap
description: Use this skill when the user wants to set up Claude Code on the web (cloud) for a fresh repository — specifically to install Playwright for screenshots, open the sandbox network allowlist for common static-hosting domains (GitHub Pages, Netlify, Vercel, Cloudflare Pages, surge.sh), and register a SessionStart hook so the bootstrap runs automatically in every new cloud session. Invoke when the user says things like "bootstrap this repo for Claude Code on the web", "make screenshots work in cloud sessions", "set up the sandbox for previewing deployed sites", or "make this work the next time I open it in a fresh session".
---

# Cloud bootstrap (template-clone workflow)

This skill copies the canonical `.claude/` bootstrap directory from a
personal template repo into the current project. Once committed, the
next fresh cloud session on this repo wakes up with:

- Playwright + chromium ready (screenshot helper at `~/.claude/playwright/shoot.js`)
- Sandbox network allowlist opened for common static-host domains
- WebFetch + Bash permissions pre-allowed for those hosts
- A SessionStart hook that re-runs the install on every fresh session

The install is idempotent — warm starts cost ~10ms because a marker file short-circuits the install path.

## Template repo

```
TEMPLATE_REPO_URL = https://github.com/sbaker333/claude-cloud-bootstrap
```

If you find a `TEMPLATE_REPO_URL` placeholder still in this file when you read it, ask the user for the actual URL and update this skill before proceeding.

## When to use

- "Set this repo up for cloud bootstrap"
- "Make screenshots work next session"
- "I want Playwright + GitHub Pages access in every fresh session for this project"

Do NOT use this skill for local Claude Code on a developer machine — the user's local `~/.claude/` already persists across sessions, so no bootstrap is needed there.

## Workflow

1. **Confirm scope and check for conflicts.** If `.claude/` already exists in the project, read what's there. If `.claude/settings.json` exists, plan to merge (preserve any existing hooks and permissions) rather than overwrite. If `.claude/bootstrap-playwright.sh` exists with different content, ask the user before replacing.

2. **Clone the template** into a temp dir:
   ```bash
   rm -rf /tmp/cc-template
   git clone --depth=1 "$TEMPLATE_REPO_URL" /tmp/cc-template
   ```

   If the clone fails with auth errors (private template repo from a different account), fall back to fetching the raw files via `curl` from `raw.githubusercontent.com` — the user can paste the raw URLs.

3. **Copy `.claude/` into the current repo** (merging settings.json if necessary):
   ```bash
   mkdir -p .claude
   cp -r /tmp/cc-template/.claude/. .claude/
   chmod +x .claude/bootstrap-playwright.sh
   ```

4. **Run the bootstrap once** to verify it works in the current sandbox:
   ```bash
   .claude/bootstrap-playwright.sh > /tmp/hook-output.json 2>&1
   ```
   Confirm the JSON contains `hookSpecificOutput.additionalContext` and that `~/.claude/playwright/shoot.js` exists.

5. **Smoke-test the screenshot helper** against a known-good public URL:
   ```bash
   node ~/.claude/playwright/shoot.js https://example.com /tmp/smoke.png desktop
   ```
   Confirm a non-zero-byte PNG lands at `/tmp/smoke.png`.

6. **Commit and push** the new files (`.claude/settings.json`, `.claude/bootstrap-playwright.sh`, and the skill copy if present) to the project's current branch.

7. **Tell the user what to do next.** The SessionStart hook does not fire retroactively. It activates in the *next* fresh cloud session on this repo. Suggest ending the current session and opening a new one to verify.

## Caveats to surface to the user

- **Project-scoped.** This bootstrap applies only to the repo it's committed to. Other repos need to be set up separately (re-invoke this skill there).

- **Network allowlist takes effect on next session.** Adding domains to `sandbox.network.allowedDomains` mid-session does not hot-reload.

- **Sandbox-side state is ephemeral.** `~/.claude/playwright/` is recreated every session by the hook. The npm install (~3s) and chromium binary check are the bootstrap's recurring cost.

- **Don't commit `~/.claude/` artifacts.** Only `.claude/` (the project-scoped directory) belongs in version control.

- **Template repo must be reachable.** If `TEMPLATE_REPO_URL` becomes private or moves, this skill breaks. Keep the template repo public, or update the URL here when it moves.

## Updating the template

If the user wants to improve the bootstrap (new permissions, new sandbox domains, an updated install script), have them:

1. Open a Claude Code on the web session against the template repo (`$TEMPLATE_REPO_URL`).
2. Make the edits there, commit, push.
3. The next time this skill runs in any other repo, the freshly-cloned template will pick up the improvements automatically. Existing bootstrapped repos do NOT auto-update — they have a snapshot. Suggest a periodic `git pull`-style refresh if drift becomes a problem.
