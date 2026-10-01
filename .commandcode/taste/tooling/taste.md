# Tooling

- Prefers the standard, well-supported toolchain path over nonstandard workarounds — chose full
  Xcode + XcodeGen over a hand-rolled Command-Line-Tools-only bundle pipeline, even at the cost
  of a large Xcode install. Confidence: 0.7
- Delegates implementation language, frameworks, architecture, and internal design decisions to
  the agent; states product requirements and hard constraints and expects the agent to select
  the stack (spec: "should be selected by the development agent"). Confidence: 0.85
- When a framework is warranted (e.g. site/web work), wants it lightweight and minimal — said
  "go use a lightweight framework" and picked Eleventy (single devDependency, static output,
  zero client JS) over heavier toolchains (Astro) or hand-rolled setups (Vite, plain HTML) for
  a small promo site. Confidence: 0.7
- Browser of choice is Brave ("i use brave") — verify web/UI work in a headed Brave session:
  launch Brave with `--remote-debugging-port` + a scratch `--user-data-dir`, then connect
  agent-browser over CDP (`agent-browser connect 9222`) instead of using agent-browser's default
  browser. Confidence: 0.85
- This machine's npm is configured with `NODE_ENV=production` / `omit=dev`, which silently
  strips devDependencies from installs — use explicit `npm ci --include=dev` (and record the
  gotcha in the repo's troubleshooting docs). Confidence: 0.7
- Node/npm is not on the system PATH on this machine (nvm is sourced in `~/.zshrc` — interactive only, so even a login shell misses it — plus Homebrew at `/opt/homebrew/bin`): anything shelling out to dev tooling from a GUI-launched app inherits launchd's minimal PATH (`/usr/bin:/bin:/usr/sbin:/sbin`) and fails with exit 127 "no such file or directory" on `npm`. Don't wrap commands in a login shell (`/bin/zsh -l -c` doesn't help here); resolve executables against a hardcoded ordered list of known install locations (nvm newest-node-first, volta, bun, cargo, asdf shims, `~/.local/bin`, `~/go/bin`, Homebrew, `/usr/local…`, system dirs). Confidence: 0.8
- Wants macOS apps shipped as a drag-to-Applications DMG ("when people do brew install i want user to get dmg file they will drag the app to applicaiton folder") — one `.dmg` artifact serves both the Homebrew cask (installs from it automatically) and direct site downloads (the drag window). Confidence: 0.7
- Editor of choice is VS Code — the "Open a project" action is the hardcoded `code .`, with the VS Code app-bundle bin path (`/Applications/Visual Studio Code.app/Contents/Resources/app/bin`) included in tool lookup. Confidence: 0.85
