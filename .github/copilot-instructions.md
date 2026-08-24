# Beyond All Reason - Copilot Instructions

Mixed script types: LuaUI widgets, LuaRules gadgets, BOS animation scripts, shaders, RmlUi documents, busted specs.

## Working in This Repository

Assume no prior BAR/Recoil domain knowledge; retrieve before proposing. When prompting local models, supply the
repository-specific context rather than expecting them to know it.

Before editing code:

1. Identify the subsystem: LuaUI widget, LuaRules gadget, AI script, shader, or BOS.
2. Identify the execution domain: synced vs unsynced.
3. Read 2-4 nearby files and match their style, naming, and conventions.
4. Reuse canonical constants, options, and helpers instead of redefining them.
5. Make the minimal change first; expand only if required.

Keep patches narrowly scoped and easy to review. Large cross-subsystem refactors need an explicit request.

## Keeping These Instructions Current

- Update the affected section in the same pull request whenever a change alters a convention, tool, workflow,
  directory, or command described here.
- Verify a claim before writing it down (run the command, read the config, count the occurrences).
- Delete guidance that no longer matches the repository instead of layering exceptions on top of it.

## Repository Layout Quick Map

- `luaui/` LuaUI widgets and UI code; `luarules/` gadgets (synced and unsynced).
- `common/` shared Lua helpers; `modules/` shared data modules (commands, i18n, graphics, lava).
- `scripts/` unit animation scripts (`.bos` sources plus compiled `.cob`).
- `units/`, `unitbasedefs/`, `weapons/`, `features/`, `gamedata/` definition data.
- `language/<lang>/*.json` translation data; `en` is the only one contributors edit.
- `spec/` busted unit tests; `tools/headless_testing/` in-engine integration test harness.
- `types/` LuaCATS type stubs; `recoil-lua-library/` engine API definitions (git submodule).

## Widget and Gadget Anatomy

Widgets live in `luaui/Widgets/`, gadgets in `luarules/gadgets/`. Both open with a typed alias of the
handler-injected global, which the EmmyLua analyzer relies on (~290/318 widgets, ~267/296 gadgets):

```lua
local widget = widget ---@type Widget -- or: local gadget = gadget ---@type Gadget

function widget:GetInfo()
	return {
		name = "Info",
		desc = "",
		author = "Floris",
		date = "April 2020",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end
```

- Synced-only gadgets guard at the top: `if not gadgetHandler:IsSyncedCode() then return end`. Gadgets serving both
  domains use the `if gadgetHandler:IsSyncedCode() then ... else ... end` split.
- File names carry a subsystem prefix. Widgets: `gui_`, `cmd_`, `unit_`, `gfx_`, `dbg_`, `api_`, `camera_`, `map_`,
  `snd_`. Gadgets: `unit_`, `game_`, `gfx_`, `cmd_`, `dbg_`, `api_`, `map_`. Match the prefix to the file's role.
- `enabled = false` ships the widget disabled by default; do not flip it unasked.

## Cross-Subsystem State

- `WG[...]` is the widget-to-widget table (LuaUI); `GG.*` the gadget-to-gadget table (LuaRules). Expose a small named
  API rather than raw state, and check the entry exists before calling into it.
- Widgets persist settings via `widget:GetConfigData()` / `SetConfigData(data)`. Adding a key is safe; renaming or
  repurposing one silently discards existing user config. Never change serialization or persistent shapes silently.
- `VFS.Include("gamedata/icontypes.lua")` is the pattern for pulling in shared data files.

## Lua 5.1

- Lua 5.1 syntax and semantics throughout. The game runs on Recoil, a SpringRTS fork; engine Lua API:
  https://recoilengine.org/docs/lua-api
- Two compile-time limits per function: **200 locals** and **60 upvalues**. Both count variables live at the same
  time, not how many are declared. Group related state into tables or split the function when approaching either.
- Naming: `camelCase` locals, `PascalCase` globals, `ALL_CAPS` constants. Avoid abbreviations (`ID` excepted) and
  single-letter names outside coordinates. Prefer names already used by similar code over inventing new ones.
- `.lua`, `.rml`, and `.rcss` files must be **UTF-8 without BOM**: a BOM makes Lua fail to parse the file and makes
  RmlUi silently ignore it.

## Runtime, Safety, and Performance

- Be explicit about synced vs unsynced behavior; avoid cross-domain assumptions.
- Keep synced code deterministic; no non-deterministic sources there.
- Do not change networked or game-state semantics unless explicitly requested.
- Per-frame callins (render/update) are hot paths. Avoid per-frame table allocations, cache frequent global and API
  lookups in locals, prefer incremental updates over full scans, and keep string processing out of hot loops.

## OpenGL

- Prefer GL 4.5+ features and modern practice (buffer objects, vertex array objects, shaders); avoid deprecated
  functionality. Target `#version 420` or higher in shaders.
- Use geometry shaders sparingly: they add overhead and are the wrong tool for work a vertex or fragment shader can
  do. Provide a no-geometry-shader fallback path, and test-compile the primary path before relying on the fallback.

## Tooling and Validation

Match the validator to the file type. If unsure of a tool's scope, inspect the project docs and workflows first.

### Toolchain

- Unit tests: busted, driven by lux. CI runs `lx --lua-version 5.1 test` (`.github/workflows/test_unit.yml` pins
  `lux-cli` 0.28.3); configuration lives in `.busted` and `lux.toml`.
- `lux.lock` pins resolved test dependencies and `.emmyrc.json` records their paths; lux rewrites both together, so
  review them as a pair. A stale `.lux/` tree (gitignored) causes a dependency integrity error — delete `.lux/` and
  re-run rather than editing `lux.lock`.
- lux 0.28.x appends duplicate `dependencies` and `entrypoints` entries to `lux.lock` on every cold sync (a run with
  no `.lux/` tree), growing the file by ~13 lines each time without ever converging. Tests still pass. Do not commit
  that churn: `git checkout -- lux.lock` afterwards, and only commit a lockfile change you made deliberately.
- Lint: `luacheck` 1.2.0 with `.luacheckrc`; CI reports only lines changed in the PR (`.github/workflows/lint.yml`).
- Format: StyLua with `.stylua.toml` (tabs, indent width 4, 120 columns, CRLF, sorted requires) and `.styluaignore`;
  `.editorconfig` mirrors the indent and whitespace rules.
- Types: EmmyLua analyzer via `.emmyrc.json`, stubs in `types/`, engine definitions from the `recoil-lua-library`
  submodule. The codebase is at zero type errors — keep it there.
- Integration tests: headless engine via `docker compose -f tools/headless_testing/docker-compose.yml`
  (`.github/workflows/test_integration.yml`). They can also be run without docker against an engine already
  downloaded by an installed BAR client — see `tools/headless_testing/README.md`.
- `BARScriptCompiler.exe` is an external BAR-Devtools binary, not checked into this repository. Use it only for
  `.bos` sources under `scripts/`, never for Lua.
- `.git-blame-ignore-revs` lists bulk formatting and codemod commits; use it when reading history.

### Commands

```sh
lx --lua-version 5.1 test                      # full busted suite (what CI runs)
busted --output=plainTerminal                  # same suite, when the .lux tree is already synced
busted spec/common/lib_spline_spec.lua         # single spec file
lx lint                                        # luacheck over the project; provisions luacheck itself
luacheck path/to/file.lua                      # lint one file, if luacheck is installed directly
stylua path/to/file.lua                        # format one file (`lx fmt` reformats the whole codebase)
```

Scope `luacheck` and `stylua` to the files you touched; repository-wide runs create large unrelated diffs. `lx lint`
reports pre-existing warnings across the tree, so compare against the baseline rather than assuming your change
caused them.

### By file type

- `.lua` (LuaUI/LuaRules/AI/common): relevant `spec/` tests, clean luacheck and StyLua, plus in-engine runtime
  verification (LuaUI reload). Do not reach for BOS tooling.
- `spec/**/*_spec.lua`: busted, per the commands above. Keep `lux.lock` and `.emmyrc.json` in sync when dependencies
  resolve to new versions.
- Definition and gamedata changes: `spec/gamedata/unitdefs_spec.lua` covers def loading.
- `.bos`: `BARScriptCompiler.exe` (external tool).
- Shaders: compile path plus runtime fallback behavior where applicable.
- `.rml` / `.rcss`: in-engine UI behavior and performance-sensitive interactions.

## Tests

- Add or update unit tests for the behavior you change, not only for shared logic in `common/` and `modules/`: new
  logic arrives with tests, changed logic has its tests updated, and a bug fix gets a test that fails without it.
- When rendering or engine callins make code hard to test, extract the decision-making part into a testable function
  and cover that. Only genuinely rendering-bound behavior stays manual and in-engine.
- Tests live in `spec/`, mirroring source layout (`spec/common/`, `spec/luaui/Widgets/`, `spec/gamedata/`) and named
  `*_spec.lua`. `.busted` sets `pattern = "_spec"` and `ROOT = spec/`, and puts `common/`, `luarules/`, `luaui/`, and
  `spec/` on `package.path`, so require modules by their repo-relative path.
- `spec/spec_helper.lua` mocks the engine surface (`Spring`, `LOG`, `GG`, `unpack`) — extend it instead of re-mocking
  per file. Build engine state with `spec/builders/` (`spring_synced_builder`, `unit_def_builder`, and friends)
  rather than hand-rolled tables.

## Compatibility and Data Ownership

- Preserve backward compatibility for saved config formats and widget options.
- Prefer canonical shared sources (constants, options, helpers) over local duplication; do not re-implement existing
  helpers or constants locally.
- Document any required behavior change in the change summary.

## Modifying local or repo equivalent copies

- Unless specifically instructed, do not also update repo equivalent or local widget copies. Keep working with the
  file we started prompting with.

## Contribution Policy

- Disclose AI-assisted changes in the pull request per `AI_POLICY.md`, and have a human verify them. The PR template
  has an "AI / LLM usage statement" section.
- One concern per pull request; PRs are squash-merged, so the title must describe the whole change
  (`.github/PULL_REQUEST_GUIDELINES.md`).
- Fill in the "Test steps" checklist in `.github/PULL_REQUEST_TEMPLATE.md`, and attach before/after media for visible
  changes.
- Player-visible balance and gameplay changes get a `changelog.txt` entry under the current `# Month` heading, in the
  existing style: `• [Unit] 1500 -> 1400 health`. Internal refactors and tooling changes do not.
- Style expectations beyond this file live in `CONTRIBUTING.md` (engine-call overhead, caching Defs lookups, correct
  iterators, comments explain "why" not "what", no dead code).

## Text and Translations

- All user-facing text goes through I18N: `Spring.I18N('ui.example.textname', { insertionvar = 'text' })`, available
  in LuaUI only. Never hardcode user-facing strings, and never use I18N for internal code or debug messages.
- Translations live in `language/<lang>/*.json`: `interface.json` for UI strings, plus `units.json`,
  `features.json`, and `tips.json`. Keys are nested objects, so `ui.topbar.button.quit` maps to
  `{ "ui": { "topbar": { "button": { "quit": ... } } } }`.
- Only add strings to `language/en/`; the community handles other languages through Transifex
  (`language/transifex.yml`).

## RmlUi

- Follow RmlUi syntax and semantics, but optimize for performance: avoid unnecessary DOM updates, reflows, excessive
  event handling, and shadow DOM usage. Prefer absolute positioning and fixed layouts to reduce layout
  recalculations, class-based styling over complex CSS selectors, and RmlUi's own event system over external
  libraries or custom event handling.
- Repository practices and instructions: `.github/RmlUi-instructions.md`. Its model-first, data-binding, RCSS, and
  performance guidance is sound, but several sections describe helpers and files reverted in #8240 — confirm a
  helper exists before calling it, and use the widgets in `luaui/RmlWidgets/` as the working reference.
- Engine-implemented RmlUi Lua documentation: https://recoilengine.org/docs/lua-api/#RmlUi
- Upstream RmlUi documentation (may be ahead): https://github.com/mikke89/RmlUiDoc/tree/master/pages/rml
