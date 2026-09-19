# Shared keybind contract

These files are the cross-surface source of truth for keybind editing, so the in-game
editor, Chobby, and the new lobby can each build their own UI without duplicating the
data or the rules. They hold *data and rules only* - no rendering, no engine calls.

## Files

| File | What it is | Schema |
|---|---|---|
| `keybind_catalog.json` | Ordered categories of keybindable commands, with i18n label keys and bind-action ids. | `keybind_catalog.schema.json` |
| `keybind_defaults.json` | The keybind profiles the game ships, each a complete keymap. | `keybind_defaults.schema.json` |
| `keybind_retired_includes.json` | What the deleted `luaui/configs/hotkeys` fragments bound, for migrating a player's own bind file that still keyloads one. | `keybind_retired_includes.schema.json` |

All three are validated in CI by `spec/common/keybind_catalog_spec.lua`: each file against its schema,
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

A player's own file can still `keyload` the bind files those profiles replaced, which is what
`keybind_retired_includes.json` is for. A preset path resolves by name to the profile that
covers it, but the fragments the presets pulled in - the chat and UI keys, the grid menu, the
number row - name no profile, so without their contents a migration would drop every binding
they held. It is a frozen record of files that no longer exist, not something to keep in step
with the profiles.

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

Where the members exist but are the player's rather than the game's, the entry names where
to read them with `"membersFrom"` instead of listing them. The one source is `"profiles"`,
which is what `keybindprofile ` covers: one bindable action per profile, named after it, so
a key means the same profile whatever is active.

That source is every selectable profile, shipped and the player's own, except the active
one - switching to the profile already loaded can only do nothing. A key that already names
the active profile is still read from the keymap and listed, so there is somewhere to remove
it from.

An entry may carry `"alwaysModifier"`, naming a modifier the action always tolerates so no
surface shows it or lets the player pick it:

- `"any"` binds with the engine's `Any+` qualifier and fires whatever is held. The engine
  forces this for its own stateful commands (`drawinmap`, `move*`) regardless.
- `"shift"` has no engine equivalent, so the binding is written twice, bare and `Shift+`,
  and both halves move together. Such an action holds exactly one key, not a list.

An entry, action or prefix, may carry `"icon"`: the VFS path of a picture for the action,
drawn on its key in the editor's keyboard overview (and wherever else a surface has room for
one). Without one, an order shows the cursor it is already known by in game, and anything
else shows no picture; the field exists so actions can be given pictures as art for them is
made, without any surface changing.

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
shape as the shipped ones plus an `active` field naming the selected profile and a
`written` field recording the keymap last emitted - `{ "name": <profile>, "stamp": <stamp> }`.
The stamp stands for the bindings the file holds rather than its bytes, so changing how the
file is emitted does not make every player's keymap read as edited; it is taken over the same
normalised `<keyset> <action>` lines a comparison uses, plus the meta key. That file
is per-install rather than shared, but its format is the contract - a surface that can
read one can read the other.

A player's profile carries `basedOn`, the name of the profile it is compared with:
recorded when it was forked or duplicated, and otherwise (imported, or made before the
field existed, or naming a profile that no longer exists) inferred on load as the shipped
profile it differs from on the fewest actions, and written back. That is what lets a
surface say which keys the player changed and what the default was. The player can point
it at any other profile, shipped or their own, or at `"none"`, which means no comparison
and is the one value loading leaves alone rather than replacing with a guess.

A shipped profile may carry `description`, an i18n key for a sentence saying what the
profile is for, shown wherever a surface lets the player pick one.

A profile travels as text in the bind-file form the engine loads, headed by a
`// keybind editor profile: <name>` comment: that is what the in-game Export copies to
the clipboard and what Import reads back, and the same text a player would put in
`uikeys.txt` by hand.

- **Which profile are we on?** Read `active` from the player's profile store. If it names
  nothing that exists in either file, fall back to the first shipped profile.
- **Apply a profile.** Write its binds out as `bind <keyset> <action>` lines with a leading
  `fakemeta <key>`, point the engine config string `KeybindingFile` at that file, and
  reload. Reloading clears the keymap first, which is why a profile has to define every
  binding it wants. It does not clear the meta key, so always write that line: leave it out
  and whatever the last profile set stays. A profile naming no key wants the engine's own,
  `space`; `fakemeta none` asks for no Meta modifier at all. Record what was written in the
  store as `written`, above - a surface that skips this makes the next launch read its own
  output as a keymap the player hand-wrote.
- **Reconcile on load.** Either side can have moved since the keymap was written: a game
  update changes a shipped profile, or a tool changes the store between sessions. Compare the
  keymap on disk against `written.stamp`. Equal means nobody has touched the file, so the
  store is the authority and the selected profile is written out again, carrying whichever
  change it was. Unequal means the player edited the file themselves, and that is kept as a
  profile of theirs rather than overwritten. Where there is no stamp to compare - a store from
  before this was recorded, or a player who points the engine at a keymap file of their own -
  fall back to matching the whole keymap against every profile first, which still says nobody
  edited it and stops a file being copied afresh on every launch. That older test cannot tell a
  profile that changed from a file that did, so do not change a shipped profile in the same
  release that starts recording stamps.
- **Edit a binding.** Only in the player's own profiles. Shipped profiles are read-only,
  so the first edit made while one is selected forks it into a copy and edits that.
- **Create / rename / delete.** Names are the identity, so they must stay unique across
  both files; disambiguate rather than overwrite. Deleting the active profile means
  falling back and applying whatever is left. A name is also an id inside the keymaps,
  because `keybindprofile <name>` is what a key switching to that profile is bound to, so
  a rename has to rewrite those binds everywhere they appear and a delete has to drop
  them - in every profile, not just the one being changed.

### Same rules, different plumbing

| Operation | In-game (LuaUI) | Lobby (Chobby / web) |
|---|---|---|
| Read the profile set | `VFS.LoadFile` both JSON files | read the same two files |
| Apply a profile | write `uikeys.txt`, `Spring.SetConfigString`, `keyreload` | write `uikeys.txt` and the config value the game reads on launch |
| Persist an edit | snapshot `Spring.GetKeyBindings` back into the active profile | rewrite the profile entry directly |

## i18n

The catalog carries i18n *keys*, not resolved strings. The ones it names live in
`language/en/commands.json`, in three namespaces: `commands` for things that also appear on
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
- Command descriptions for every action. A catalog item may carry `description`, an i18n
  key for a tooltip sentence; without one the in-game editor falls back to the command
  card's tooltip (`commands.<name>_tooltip`, for a row labelled `commands.<name>`) and then
  to the engine's command description (`cmd.<command>`, `cmd.<command>._description` for the
  structured ones, `cmd.luarules.<command>` for gadget commands). Roughly a third of the
  catalog still has none of those. Widget/mod actions have no `cmd.*` entry, so their
  descriptions depend on the declaration API above.
