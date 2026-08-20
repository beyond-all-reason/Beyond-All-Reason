# Shared keybind contract

These files are the cross-surface source of truth for keybind editing, so the in-game
editor, Chobby, and the new lobby can each build their own UI without duplicating the
data or the rules. They hold *data and rules only* - no rendering, no engine calls.

## Files

| File | What it is | Schema |
|---|---|---|
| `keybind_catalog.json` | Ordered categories of keybindable commands, with i18n label keys and bind-action ids. | `keybind_catalog.schema.json` |
| `keybind_defaults.json` | The keybind profiles the game ships, each a complete keymap. | `keybind_defaults.schema.json` |

Both are validated in CI by `spec/keybind_catalog_spec.lua`: each file against its schema,
profile names unique across the shipped set, every purely modifier-only action marked
read-only, and every action command written in lower case.

They are separate because a catalog entry is per action while a binding is per action *and*
profile. The four shipped profiles share only 207 of the 381 actions they bind between them,
so there is no single default keyset to hang off a catalog row - merging the two would mean
every row carrying a keyset-per-profile map, which is this file re-expressed inside the
catalog. The sets differ both ways as well: 41 bound actions have no catalog entry - 25 of
those are listed as hidden on purpose, the other 16 surface under "Other" - and 8 catalog
entries are bound in no profile. Adding a bindable
action usually means touching both - the catalog for where it appears, a profile for what
it is bound to out of the box.

A profile is a whole keymap, never a delta - applying one replaces everything, so
there is no base layer to reason about. The shipped profiles carry their bindings
inline rather than pointing at bind files, so a consumer reads one shape whether the
profile came from this file or from the player's own.

Every shipped profile is selectable and read-only; editing one forks a copy under a name
the player chooses.

## Catalog item kinds

Everything the catalog lists is rebindable. An action a player cannot change - one bound to
a bare modifier, or handled by a widget that ships disabled - belongs in `hidden` or nowhere,
not in a category as a row that does nothing.

Each category's `items` entry is one of:

- `{ "action": "<bind command>", "label": "<i18n key>" }` - one rebindable action.
- `{ "prefix": "<action id prefix>" }` - claims every bound action whose id starts with the
  prefix (for numbered families like `group select 0`, `group select 1`, ...). An optional
  `"label"` is interpolated per matched action with the arg after the prefix as `%{n}` (or its
  two whitespace-split tokens as `%{row}`/`%{col}`); an optional `"unit": true` resolves that
  arg from a unit codename to its translated name.

`action` is the bind command exactly as `/bind` expects and `GetKeyBindings` reports it
(command plus space-separated args, e.g. `select AllMap++_ClearSelection_SelectAll+`). The
command is lower case: the engine lower-cases it when parsing a bind line, so a capitalised
id matches nothing.

A prefix entry may list `"members"`: the args the family covers, appended to the prefix to
form each action. Listing them makes those rows exist whether or not anything is bound, so
unbinding one leaves it there to bind again. Families that cannot be enumerated - `buildunit_`
is per unit - list none and are discovered from what is bound instead.

An entry may carry `"alwaysModifier"`, naming a modifier the action always tolerates so no
surface shows it or lets the player pick it:

- `"any"` binds with the engine's `Any+` qualifier and fires whatever is held. The engine
  forces this for its own stateful commands (`drawinmap`, `move*`) regardless.
- `"shift"` has no engine equivalent, so the binding is written twice, bare and `Shift+`,
  and both halves move together. Such an action holds exactly one key, not a list.

A category may carry `"layout": "grid"`, drawn as the grid menu's own 3x4 arrangement rather
than a flat list so the keys read the way they sit on screen.

A single leading `{ "hidden": ["<action id>", ...] }` entry (not a category) lists actions
that are bound but never shown - matched by exact id, not prefix, so a future action can't be
suppressed by coincidence - so they surface neither as a row nor under "Other".

## Ordering

Two orderings, meaning different things.

**Catalog order is presentation.** Where an item sits decides where it appears in an
editor and nothing else. Reorganize freely.

**Bind order in `keybind_defaults.json` is precedence.** The array is written out as bind
lines in order, the engine stamps each with an incrementing index, and two actions on one
keyset are tried in that order - first to succeed wins. Position matters only against
other binds on the same keyset; where a bind sits in the file overall does not.

When adding a bind to a shipped profile:

- On a keyset nothing else uses, position is free. Put it next to related binds.
- On a keyset that already carries an action, the earlier entry gets first refusal. Place
  it above only if it should win.
- Do not reorder existing binds to tidy the file. That silently changes precedence.

A handler that declines (returns falsy) does not hold the key - the next action on that
keyset is tried. Ordering only settles contests between handlers that would both succeed,
so "the wrong thing fires" is not automatically an ordering problem.

`priority` is the override for when the natural order is wrong: action prefixes, highest
first, applied when a profile is written out. It is a stable sort, so listing an action
moves that action and leaves everything else where it was. It ships empty, because preset
order already encodes the intended precedence - add to it only for a case you can point at.

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

The catalog carries i18n *keys*, not resolved strings. The ones it names live in
`language/en/keybinds.json`, in three namespaces: `commands` for things that also appear on
the command card (names and tooltips), `actions` for everything else a player can bind, and
`categories` for the group titles. The loader globs every json in `language/<lang>/`, so the
namespaces merge into one lookup and Transifex picks the file up from the directory filter.

Nothing is written twice. A row whose action *is* a command points at the `commands` entry
rather than repeating the string, which is why the wording there follows the command card.
Two lookups still leave the file: the grid menu's category names stay in `ui.buildMenu.*`
where that menu owns them, and `buildunit_` rows resolve `units.names.*` out of `units.json`.

The editor's own UI - buttons, dialogs, prompts - is not vocabulary and stays in
`interface.json` under `ui.keybinds.editor.*`. A surface that builds its own UI needs the
three namespaces above and none of that.

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
