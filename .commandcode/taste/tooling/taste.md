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
