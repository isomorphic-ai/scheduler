# Agent Instructions

Before doing substantive work in this repository, read:

- `/Users/fabian/.codex/memories/fabian-collaboration-protocol.md`

Use it as active collaboration context, especially after compaction or resume.

## Git Commit Wrapper

When committing from Codex, use the guarded wrapper:

```bash
/usr/local/bin/codex-git-commit -m "Commit message" -- path [path ...]
```

Commit coherent chunks often. Pass only explicit files; do not use broad
pathspecs such as `.` or directories. The wrapper refuses pre-staged changes,
checks the staged diff, and creates a normal commit.
