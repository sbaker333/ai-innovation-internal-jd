#!/usr/bin/env bash
# Project SessionStart bootstrap.
# Installs Playwright + writes a screenshot helper into ~/.claude/playwright
# so the model can render and inspect this project's HTML pages.
# Idempotent: skips work when the marker file is present.
set -e

PW_DIR="$HOME/.claude/playwright"
MARKER="$PW_DIR/.installed"

ensure_install() {
  mkdir -p "$PW_DIR"
  cd "$PW_DIR"
  if [ ! -f package.json ]; then
    npm init -y >/dev/null 2>&1
  fi
  # Prefer the version matching pre-bundled browsers in the sandbox image so
  # we don't hit the network for chromium downloads on cold start.
  if [ -d /opt/pw-browsers/chromium-1194 ] && [ ! -d node_modules/playwright ]; then
    npm install --no-audit --no-fund --silent playwright@1.56.1 >/dev/null 2>&1
  elif [ ! -d node_modules/playwright ]; then
    npm install --no-audit --no-fund --silent playwright >/dev/null 2>&1
    PLAYWRIGHT_BROWSERS_PATH="$PW_DIR/browsers" npx playwright install chromium >/dev/null 2>&1 || true
  fi
}

write_helper() {
  cat > "$PW_DIR/shoot.js" <<'EOF'
// Usage: node shoot.js <url> <outPath> [viewport]
//   viewport: "desktop" (1440x900, dsr 1) | "mobile" (390x844, dsr 2) | "WxH"
//   url may be http(s):// or file:///absolute/path
//   include "-full" in the output filename for a full-page capture
const path = require('path');
process.env.PLAYWRIGHT_BROWSERS_PATH = process.env.PLAYWRIGHT_BROWSERS_PATH || '/opt/pw-browsers';
const { chromium } = require(path.join(__dirname, 'node_modules', 'playwright'));

(async () => {
  const [url, out, vpArg = 'desktop'] = process.argv.slice(2);
  if (!url || !out) {
    console.error('usage: node shoot.js <url> <out.png> [desktop|mobile|WxH]');
    process.exit(2);
  }
  let viewport, dsr;
  if (vpArg === 'desktop') { viewport = { width: 1440, height: 900 }; dsr = 1; }
  else if (vpArg === 'mobile') { viewport = { width: 390, height: 844 }; dsr = 2; }
  else {
    const m = /^(\d+)x(\d+)$/.exec(vpArg);
    if (!m) { console.error('bad viewport'); process.exit(2); }
    viewport = { width: +m[1], height: +m[2] }; dsr = 1;
  }
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport, deviceScaleFactor: dsr });
  const p = await ctx.newPage();
  await p.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
  await p.screenshot({ path: out, fullPage: out.includes('-full') });
  await b.close();
  console.log(out);
})();
EOF
}

ensure_install
write_helper
touch "$MARKER"

cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Playwright is available at ~/.claude/playwright. Screenshot helper: \`node ~/.claude/playwright/shoot.js <url> <out.png> [desktop|mobile|WxH]\`. URL may be http(s):// or file:///abs/path. Filenames containing \`-full\` produce a full-page capture. Pre-bundled chromium browsers live at /opt/pw-browsers when present. This project's sandbox network allowlist opens *.github.io, *.netlify.app, *.vercel.app, *.pages.dev, *.surge.sh."
  },
  "suppressOutput": true
}
JSON
