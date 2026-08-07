# Shared keybind contract

These files are the cross-surface source of truth for keybind editing, so the in-game
editor, Chobby, and the new lobby can each build their own UI without duplicating the
data or the rules. They hold *data and rules only* - no rendering, no engine calls.

## Files

| File | What it is | Schema |
|---|---|---|
| `keybind_catalog.json` | Ordered categories of keybindable commands, with i18n label keys and bind-action ids. | `keybind_catalog.schema.json` |
| `keybind_defaults.json` | The keybind profiles the game ships, each a complete keymap, plus retired ones kept for migration. | `keybind_defaults.schema.json` |

Both are validated in CI by `spec/keybind_catalog_spec.lua` (structure + referential
integrity: every i18n key resolves, every bind has a keyset and an action).

A profile is a whole keymap, never a delta - applying one replaces everything, so
there is no base layer to reason about. The shipped profiles carry their bindings
inline rather than pointing at bind files, so a consumer reads one shape whether the
profile came from this file or from the player's own.

The `retired` list holds presets the game no longer offers. They are never selectable;
they exist so a player still pointed at one keeps their keys, as a profile of their own
named after the preset. A surface that only ever shows current profiles can ignore it.

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

A single leading `{ "hidden": ["<action id>", ...] }` entry (not a category) lists actions
that are bound but never shown - matched by exact id, not prefix, so a future action can't be
suppressed by coincidence - so they surface neither as a row nor under "Other".

## The config contract (behavior each surface implements)

Structure lives in the schemas; these are the operations, which a schema can't express.
Every surface answers the same questions from the same facts.

The player's own profiles live in `LuaUI/Config/keybind_profiles.json`, in the same
shape as the shipped ones plus an `active` field naming the selected profile. That file
is per-install rather than shared, but its format is the contract - a surface that can
read one can read the other.

- **Which profile are we on?** Read `active` from the player's profile store. If it names
  nothing that exists in either file, fall back to the first shipped profile.
- **Apply a profile.** Write its binds out as `bind <keyset> <action>` lines (plus a
  leading `fakemeta <key>` if it has one), point the engine config string `KeybindingFile`
  at that file, and reload. Reloading clears the keymap first, which is why a profile has
  to define every binding it wants.
- **Edit a binding.** Only in the player's own profiles. Shipped profiles are read-only,
  so the first edit made while one is selected forks it into a copy and edits that.
- **Create / rename / delete.** Names are the identity, so they must stay unique across
  both files; disambiguate rather than overwrite. Deleting the active profile means
  falling back and applying whatever is left.

### Same rules, different plumbing

| Operation | In-game (LuaUI) | Lobby (Chobby / web) |
|---|---|---|
| Read the profile set | `VFS.LoadFile` both JSON files | read the same two files |
| Apply a profile | write `uikeys.txt`, `Spring.SetConfigString`, `keyreload` | write `uikeys.txt` and the config value the game reads on launch |
| Persist an edit | snapshot `Spring.GetKeyBindings` back into the active profile | rewrite the profile entry directly |

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
