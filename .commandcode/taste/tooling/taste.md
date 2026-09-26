# Tooling

- Prefers the standard, well-supported toolchain path over nonstandard workarounds — chose full
  Xcode + XcodeGen over a hand-rolled Command-Line-Tools-only bundle pipeline, even at the cost
  of a large Xcode install. Confidence: 0.7
- Delegates implementation language, frameworks, architecture, and internal design decisions to
  the agent; states product requirements and hard constraints and expects the agent to select
  the stack (spec: "should be selected by the development agent"). Confidence: 0.85
