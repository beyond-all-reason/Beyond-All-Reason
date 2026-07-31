---@meta

---@class Widget : Addon, RulesUnsyncedCallins
---@field [string] any
---@field MousePress fun(self, x: number, y: number, button: number, ...: any): (boolean|integer)?
---@see Callins
---@see UnsyncedCallins

---@type Widget
---@diagnostic disable-next-line: lowercase-global
widget = nil

---Shared table for widgets.
WG = {}
