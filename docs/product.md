# Product — Dormant

> The brief the agent works from. Captured from the requirements conversation, 2026-09-26.

## What it is

Dormant is a local macOS developer utility for managing the lifecycle of project workspaces. It
separates a project's **core files** (source, git repository and history, configuration, docs,
assets) from its **regenerable development state** (dependency folders, build output, caches,
virtual environments, generated files), and lets the developer move projects between **Active**
and **Dormant** states without losing anything.

Central promise: **the repository is permanent, the local development environment is disposable.**
Clean what can be regenerated. Keep what matters. Put unused projects to sleep. Wake them when
you need them.

## Who it's for

Developers with many local project checkouts on one Mac who want their disk space back without
deleting their projects.

## The problem it solves

A project's source is small but its workspace is huge — `node_modules`, `.venv`, `target`, build
output and caches can be gigabytes. Today a developer either deletes the project and loses the
workspace (and possibly uncommitted work), keeps everything and loses tens of GB, or manually
deletes folders and hopes they remember how to rebuild them. Dormant makes the reclaim/rebuild
cycle explicit, safe, and reversible.

## Actions

Available from a Finder right-click menu on a project folder and from the app itself:

- **Open** — open the project in the user's configured/default development environment. Never
  modifies the project.
- **Clean** — keep the project, remove regenerable development state. Shows an understandable
  preview of what will be removed and how much space is reclaimed before anything happens.
  Never deletes arbitrary files because they are large.
- **Archive** — make the local workspace dormant while preserving the project: remove regenerable
  state, compress what remains (source, `.git`, configs) into a local archive, remove the working
  copy. Warns clearly (with counts) about uncommitted changes first. Never deletes the repository.
- **Restore** — bring a dormant project back as a working development workspace: decompress the
  archive, then detect ecosystem dependency commands and show exactly what will run, running them
  only after the user confirms.
- **Project Info** — why a project is consuming disk: location, remote, branch, git status, last
  commit, local size vs core vs regenerable size, Active/Dormant status.
- **Open Repository** — open the project's git remote in the browser (any common host, no
  Dormant backend); unavailable when there is no remote.

## Decisions captured in requirements (2026-09-26)

- **Archive storage strategy:** clean regenerable state, compress what remains to a local archive
  (`~/.dormant/store/`), remove the working copy. Restore = decompress + rebuild. Fully offline;
  no git remote or account required to recover.
- **App surface:** menu bar app with a main window (project list, info, settings); Finder actions
  show their confirmation dialogs.
- **Project tracking:** local registry (scanning a root the user chooses, e.g. `~/Projects`) plus
  an index of every archive Dormant creates — this is what makes dormant projects identifiable
  and restorable.
- **Restore dependency commands:** detected commands are shown and confirmed before running.

## Safety requirements (non-negotiable)

1. Never delete a Git repository as part of normal Archive behavior.
2. Never silently discard uncommitted changes.
3. Never assume an arbitrary large file is safe to delete.
4. Clearly distinguish core files from regenerable state; if unsure, leave it alone.
5. Explain destructive operations before performing them.
6. Prefer reversible operations.
7. Detect git state before operations that could affect the workspace.
8. Never require a Dormant account or cloud service to recover a project.
9. Avoid storing unnecessary copies of user source code.
10. Fail safely when project structure cannot be confidently understood.

## Local-first

No required cloud service, account, telemetry, or Dormant backend. Git repositories and their
remotes stay under the developer's control.

## Non-goals

- Distribution: no code signing, notarization, Apple Developer Program, certificates, or App
  Store submission — explicitly out of scope for the initial local build.
- Any Dormant-hosted service, account system, sync, or telemetry.
- Deleting or rewriting git repositories; aggressive deletion of unrecognized files.
- Windows or Linux support.
- Cleaning files merely because they are large.

## Success looks like

The one workflow that must feel right: right-click a bloated project → **Archive**; get a clear
warning about uncommitted changes, confirm, and watch gigabytes leave the disk while the project
sits safely as a small archive in `~/.dormant/store/`. Days later, **Restore** brings it back and,
after one confirmation of the install commands, it is a working dev environment again. "Done" for
the first release is that flow plus Clean and Project Info, working from Finder, on the
developer's own Mac.
