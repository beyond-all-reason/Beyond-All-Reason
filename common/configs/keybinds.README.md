# Shared keybind contract

These files are the cross-surface source of truth for keybind editing, so the in-game
editor, Chobby, and the new lobby can each build their own UI without duplicating the
data or the rules. They hold *data and rules only* - no rendering, no engine calls.

## Files

| File | What it is | Schema |
|---|---|---|
| `keybind_catalog.json` | Ordered categories of keybindable commands, with i18n label keys and bind-action ids. | `keybind_catalog.schema.json` |
| `keybind_presets.json` | Ordered registry of presets (display name -> bind file), with the Custom preset flagged. | `keybind_presets.schema.json` |

Both are validated in CI by `spec/keybind_catalog_spec.lua` (structure + referential
integrity: preset files exist, every i18n key resolves).

The actual bindings live in the plain-text bind files the registry points at
(`luaui/configs/hotkeys/*.txt`, and `uikeys.txt` for Custom). Those are already portable -
a consumer reads or copies them directly; only the registry (which file is which preset)
needs sharing.

## Catalog item kinds

Each category's `items` entry is exactly one of:

- `{ "action": "<bind command>", "label": "<i18n key>" }` - editable; user can rebind it.
- `{ "label": "<i18n key>", "keyLabel": "<i18n key>" }` - informational, read-only key hint.
- `{ "prefix": "<action id prefix>" }` - claims every bound action whose id starts with the
  prefix, listed by raw id (for numbered families like `group 1`, `group 2`, ...). An optional
  `"label"` is interpolated per matched action with the arg after the prefix as `%{n}` (or its
  two whitespace-split tokens as `%{row}`/`%{col}`); an optional `"unit": true` resolves that
  arg from a unit codename to its translated name.

`action` is the bind command exactly as `/bind` expects and `GetKeyBindings` reports it
(command plus space-separated args, e.g. `select AllMap++_ClearSelection_SelectAll+`).

A single leading `{ "hidden": ["<action id prefix>", ...] }` entry (not a category) lists
actions that are bound but never shown - by the same prefix match - so they surface neither
as a row nor under "Other".

## The config contract (behavior each surface implements)

Structure lives in the schemas; these are the operations, which a schema can't express.
Every surface answers the same questions from the same facts:

- **Which preset are we on?** Read the engine config string `KeybindingFile`. Match it
  against `keybind_presets.json` `file` values. `uikeys.txt` means **Custom**; anything
  else is the named preset. If it points at nothing valid, fall back to the first entry.
- **Switch preset.** Set `KeybindingFile` to the target preset's `file`, then reload the
  bindings.
- **Seed Custom.** The first time Custom is selected, `uikeys.txt` may not exist yet - seed
  it from the currently active bindings so the user starts from what they had.
- **Reset Custom to a preset.** Overwrite `uikeys.txt` with the chosen preset's bindings,
  then reload. (Destructive to the user's custom binds - confirm first.)

### Same rules, different plumbing

| Operation | In-game (LuaUI) | Lobby (Chobby / web) |
|---|---|---|
| Read current preset | `Spring.GetConfigString("KeybindingFile")` | read the same engine config value |
| Switch preset | `Spring.SetConfigString` + `keyreload` | write the config value the game reads on launch |
| Seed / reset Custom | `keysave` a preset's binds into `uikeys.txt` | copy the preset file's contents into `uikeys.txt` |

## i18n

The catalog carries i18n *keys*, not resolved strings. Each surface resolves them through
its own localization store - in-game that's `Spring.I18N` (sourced from
`language/en/interface.json`, translated via Transifex). Sharing the *strings* across
surfaces is a separate concern from sharing this structure.

## Not covered yet

- A widget/mod action-declaration API, so widgets register their own bindable actions
  (with label + category + description) into the catalog at runtime instead of only being
  editable when already bound.
- Command descriptions / tooltips. The engine ships per-command descriptions in the shared
  `cmd.*` i18n namespace (in `interface.json`, localized like everything else), so a future
  iteration can show them by resolving `cmd.<command>` (falling back to `cmd.<command>._description`
  for the few structured commands, and `cmd.luarules.<command>` for gadget commands) at display
  time - no catalog change needed, since the catalog already carries the command per row. Widget/mod
  actions have no `cmd.*` entry, so their descriptions depend on the declaration API above.
