# types/luassert — vendored LuaCATS annotations for luassert

**Upstream:** https://github.com/LuaCATS/luassert
**Commit:** `d3528bb679302cbfdedefabb37064515ab95f7b9` (2023-01-20)

## Why vendored

Lux does not yet support pulling LuaCATS annotations from library deps.
See https://github.com/lumen-oss/lux/issues/953 — once that lands, this
directory should be deleted in favor of declaring `luassert` as a
normal Lux dev-dep and letting the type annotations flow through
automatically.

## Contents

- `library/luassert.lua` — top-level `luassert` class + assertion/matcher
  functions (`assert.equals`, `assert.same`, `assert.has_error`, etc.).
- `library/luassert/` — sub-modules: `spy`, `stub`, `mock`, `match`,
  `array`.
- `config.json` — upstream lua-language-server addon manifest (kept for
  parity; not consumed by emmylua).

## License

Upstream LuaCATS/luassert does **not** ship a `LICENSE` file at the
commit vendored above. The underlying `luassert` library
(https://github.com/lunarmodules/luassert) is MIT-licensed; the type
annotations in this repo are community-contributed and, per upstream
issue tracker discussion, treated as public-domain / MIT-equivalent by
convention.

If license clarity matters for a downstream distribution, open an issue
at the upstream repo requesting an explicit `LICENSE` file be added.
