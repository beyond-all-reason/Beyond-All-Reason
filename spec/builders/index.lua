local TeamBuilder = VFS.Include("spec/builders/team_builder.lua")
local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")
local ResourceDataBuilder = VFS.Include("spec/builders/resource_data_builder.lua")
local UnitDefBuilder = VFS.Include("spec/builders/unit_def_builder.lua")
local UnitDefsBuilder = VFS.Include("spec/builders/unit_defs_builder.lua")

---@class Builders
---@field Team TeamBuilder
---@field Spring SpringSyncedBuilder
---@field SpringUnsynced SpringUnsyncedBuilder
---@field ResourceData ResourceDataBuilder
---@field UnitDef UnitDefBuilder
---@field UnitDefs UnitDefsBuilder
---@field Mode table
local Builders = {
	Team = TeamBuilder,
	Spring = SpringSyncedBuilder,
	SpringUnsynced = SpringUnsyncedBuilder,
	ResourceData = ResourceDataBuilder,
	UnitDef = UnitDefBuilder,
	UnitDefs = UnitDefsBuilder,
}

return setmetatable(Builders, {
	__index = function(t, k)
		if k == "Mode" then
			local mod = VFS.Include("spec/builders/mode_test_helpers.lua")
			rawset(t, "Mode", mod)
			return mod
		end
		-- Owned by the missions module and loaded lazily for the same reason.
		if k == "Mission" then
			local mod = VFS.Include("modules/missions/spec/builders/mission_builder.lua")
			rawset(t, "Mission", mod)
			return mod
		end
	end,
})
