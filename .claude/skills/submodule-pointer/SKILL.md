---
name: submodule-pointer
description: Keep the recoil-lua-library submodule pointer out of commits — run after any git checkout, and before git add -A / commit -a.
---

Prefer to run `git submodule update --recursive --force` after a `git checkout` if recoil-lua-library is dirty in the worktree, always ensure the `recoil-lua-library` reference is cleared (`git restore --staged recoil-lua-library`) before `git add -A` / `git commit -a`, so the local submodule pointer never sneaks into a commit.
