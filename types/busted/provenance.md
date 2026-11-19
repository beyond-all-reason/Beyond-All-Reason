# types/busted — vendored LuaCATS annotations for busted

**Upstream:** https://github.com/LuaCATS/busted
**Commit:** `5ed85d0e016a5eb5eca097aa52905eedf1b180f1` (2022-11-23)

## Why vendored

Lux does not yet support pulling LuaCATS annotations from library deps.
See https://github.com/lumen-oss/lux/issues/953 — once that lands, this
directory should be deleted in favor of declaring `busted` as a normal
Lux dev-dep and letting the type annotations flow through automatically.

## Contents

- `library/busted.lua` — type stubs for `describe`, `it`, `setup`,
  `teardown`, `before_each`, `after_each`, `finally`, `pending`,
  `async`/`done`, etc. Emmylua picks these up because they sit under the
  workspace root with `---@meta` markers.
- `config.json` — upstream lua-language-server addon manifest (kept for
  parity; not consumed by emmylua).

## License

Upstream LuaCATS/busted does **not** ship a `LICENSE` file at the commit
vendored above. The underlying `busted` test framework
(https://github.com/lunarmodules/busted) is MIT-licensed; the type
annotations in this repo are community-contributed and, per upstream
issue tracker discussion, treated as public-domain / MIT-equivalent by
convention.

If license clarity matters for a downstream distribution, open an issue
at the upstream repo requesting an explicit `LICENSE` file be added.
