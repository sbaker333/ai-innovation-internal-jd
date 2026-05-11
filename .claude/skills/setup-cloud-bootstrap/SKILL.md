---
name: setup-cloud-bootstrap
description: Use this skill when the user wants to set up Claude Code on the web (cloud) for a fresh repository — specifically to install Playwright for screenshots, open the sandbox network allowlist for common static-hosting domains (GitHub Pages, Netlify, Vercel, Cloudflare Pages, surge.sh), and register a SessionStart hook so the bootstrap runs automatically in every new cloud session. Invoke when the user says things like "bootstrap this repo for Claude Code on the web", "make screenshots work in cloud sessions", "set up the sandbox for previewing deployed sites", or "make this work the next time I open it in a fresh session".
---

# Cloud bootstrap setup

This skill writes a project-scoped `.claude/` bootstrap so the next cloud session for this repo wakes up with:

- Playwright + chromium ready (screenshot helper at `~/.claude/playwright/shoot.js`)
- Sandbox network allowlist opened for common static-host domains
- WebFetch + Bash permissions pre-allowed for the same hosts
- A SessionStart hook that runs the install script on every fresh session

The install is idempotent — it skips work when a marker file is already in place, so warm starts cost ~10ms.

## When to use

Use this skill when the user wants Claude Code on the web to be able to take screenshots of and curl their deployed sites, without needing manual setup each session. Typical triggers:

- "Set this repo up for cloud bootstrap"
- "Make screenshots work next session"
- "I want Playwright + GitHub Pages access in every fresh session for this project"

Do NOT use this skill for:
- Local Claude Code on a developer machine — the user's local `~/.claude/` already persists across sessions, so no bootstrap is needed.
- Bootstrapping things unrelated to web previewing (use other skills or direct edits).

## Workflow

1. **Confirm scope.** Confirm the user wants this committed to the repo (project-scoped, applies to anyone who clones). If they want it global across all projects, tell them Claude Code on the web has no persistent user-global settings store — they'd need to commit `.claude/` into each repo, or maintain a personal dotfiles repo.

2. **Check for conflicts.** Before writing, check whether `.claude/settings.json` already exists in the project. If yes, read it and merge — preserve any existing hooks (especially Stop hooks) and permission entries. Do NOT clobber.

3. **Write `.claude/settings.json`** (merging if it already exists) with this structure. The hook command path is relative to the repo root.

   ```json
   {
     "$schema": "https://json.schemastore.org/claude-code-settings.json",
     "hooks": {
       "SessionStart": [
         {
           "matcher": "",
           "hooks": [
             {
               "type": "command",
               "command": ".claude/bootstrap-playwright.sh",
               "timeout": 180
             }
           ]
         }
       ]
     },
     "permissions": {
       "allow": [
         "WebFetch(domain:*.github.io)",
         "WebFetch(domain:*.netlify.app)",
         "WebFetch(domain:*.vercel.app)",
         "WebFetch(domain:*.pages.dev)",
         "WebFetch(domain:*.surge.sh)",
         "Bash(npx playwright *)",
         "Bash(npx -y playwright *)",
         "Bash(node ~/.claude/playwright/*)",
         "Bash(node .claude/playwright/*)"
       ]
     },
     "sandbox": {
       "network": {
         "allowedDomains": [
           "*.github.io",
           "*.netlify.app",
           "*.vercel.app",
           "*.pages.dev",
           "*.surge.sh",
           "127.0.0.1",
           "localhost"
         ]
       }
     }
   }
   ```

   Ask the user before adding any extra domains. The deploy hosts above are the common cases; add more sparingly to keep the egress surface tight.

4. **Write `.claude/bootstrap-playwright.sh`** with the install + helper-write logic. The script:
   - Creates `~/.claude/playwright/` (sandbox-ephemeral but fast to rebuild).
   - Installs `playwright@1.56.1` to match pre-bundled chromium at `/opt/pw-browsers/chromium-1194` when present (avoids hitting the network for browser downloads). Falls back to `playwright` latest + `playwright install chromium` otherwise.
   - Writes a screenshot helper to `~/.claude/playwright/shoot.js` with a small CLI: `node shoot.js <url> <out.png> [desktop|mobile|WxH]`. Filenames containing `-full` produce a full-page capture.
   - Emits a SessionStart hook JSON payload with `hookSpecificOutput.additionalContext` so the model immediately knows where the helper lives and how to call it.

   The full script body is in `.claude/bootstrap-playwright.sh` in this repository — copy it verbatim into the new project. (Or read it from `/home/user/ai-innovation-internal-jd/.claude/bootstrap-playwright.sh` if you're inside Claude Code with access to that path; otherwise reconstruct from the template in this skill.)

5. **Make the script executable**: `chmod +x .claude/bootstrap-playwright.sh`.

6. **Run it once to verify**: `.claude/bootstrap-playwright.sh > /tmp/hook-output.json` and check that the JSON output contains the `additionalContext` line. Then verify `~/.claude/playwright/shoot.js` exists and `node ~/.claude/playwright/shoot.js` prints its usage line.

7. **Sanity-check the screenshot helper** by capturing a known-good page (e.g. an existing local HTML file or a public URL): `node ~/.claude/playwright/shoot.js https://example.com /tmp/smoke.png desktop`. Confirm a PNG is produced.

8. **Commit and push**. Stage the two new files (`.claude/settings.json` and `.claude/bootstrap-playwright.sh`) and commit with a clear message. Push to the current branch. Do NOT commit `~/.claude/playwright/` — that's the sandbox-side install, not project content.

9. **Tell the user what to do next.** The hook does not fire retroactively in the current session — it activates in the *next* cloud session on this repo. Suggest: end this session, open a fresh one, and confirm the SessionStart hook emits the additionalContext line and that a curl to one of the allowlisted domains returns 200 (not 403).

## Caveats to surface to the user

- **Project scope only.** This bootstrap applies only to the repo it's committed to. If the user wants it in every repo, they need to repeat the setup (or commit `.claude/` from a template). Claude Code on the web does not currently expose a persistent user-global settings mechanism that survives sandbox resets.

- **Network allowlist takes effect on next session.** Adding domains to `sandbox.network.allowedDomains` mid-session does not hot-reload. The current session's allowlist remains whatever it was at session start.

- **Sandbox-side state is ephemeral.** `~/.claude/playwright/` is recreated every session by the hook. The npm install (~3s) and chromium binary check are the bootstrap's recurring cost.

- **Don't add the install dir to source control.** Only the two files in `.claude/` (settings.json and bootstrap-playwright.sh) belong in the repo. Add `.claude/settings.local.json` to `.gitignore` if you anticipate local overrides.

## File contents reference

If the canonical bootstrap script is not accessible at install time (e.g. you're invoking this skill in a totally fresh environment with no other Claude Code repo to copy from), the full content of `.claude/bootstrap-playwright.sh` should match the template in this skill's repository, which mirrors the script in `/home/user/ai-innovation-internal-jd/.claude/bootstrap-playwright.sh`. The script is roughly 60 lines and self-contained — no external dependencies beyond `node`, `npm`, and `bash`.
