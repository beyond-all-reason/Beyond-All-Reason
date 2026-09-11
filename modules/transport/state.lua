local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---@class TransportLanding where an unloaded unit came down, and when to pin it there
---@field px number
---@field py number
---@field pz number
---@field dx number
---@field dy number
---@field dz number
---@field rx number
---@field ry number
---@field rz number
---@field frame integer

---@class TransportState
---@field loadedSpeed table<integer, number> air transport -> allowed elmos per frame
---@field settling table<integer, TransportLanding> unloaded unit -> where it landed, and when to pin it
---@field maybeDead table<integer, integer> cargo -> the carrier that just let go
---@field unstacking table<integer, integer> a nano turret -> its def, nudged until clear of any immobile ally
local state = ModuleHandler.State(Modules.Transport) ---@type TransportState
state.loadedSpeed = state.loadedSpeed or {}
state.settling = state.settling or {}
state.maybeDead = state.maybeDead or {}
state.unstacking = state.unstacking or {}

return state
