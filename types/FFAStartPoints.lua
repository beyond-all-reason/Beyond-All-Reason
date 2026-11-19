---@meta

---Legacy global that third-party FFA start-point configs assigned directly.
---`game_ffa_start_setup.lua` now passes layouts up the stack as locals via
---`VFS.Include`, but keeps a backwards-compatibility branch that reads this
---in case such a config still exists in the wild.
---
---Keyed by required start-point count; each value is a layout, i.e. a list of
---map positions, one per ally team.
---@type table<integer, { x: number, z: number }[]>?
---@diagnostic disable-next-line: lowercase-global
ffaStartPoints = nil
