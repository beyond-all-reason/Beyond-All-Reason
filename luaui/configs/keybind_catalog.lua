-- Loads the shared, cross-surface keybind catalog from JSON (the contract the
-- in-game editor, Chobby, and the new lobby all consume). Returns the ordered
-- array the editor iterates:
--   { category = "<i18n key>", items = { <item>, ... } }
-- where each item is one of:
--   { action = "<bind command>", label = "<i18n key>" }  editable (chips + rebind)
--   { label = "<i18n key>", keyLabel = "<i18n key>" }     informational, read-only
--   { prefix = "<action prefix>", label = "<i18n key>", unit = <bool> }  prefix group
-- plus a leading { hidden = { "<prefix>", ... } } entry of actions never shown.
-- Source of truth: common/configs/keybind_catalog.json
local Json = Json or VFS.Include('common/luaUtilities/json.lua')
return Json.decode(VFS.LoadFile('common/configs/keybind_catalog.json'))
