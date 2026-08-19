local TeamBuilder = VFS.Include("spec/builders/team_builder.lua")
local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")
local ResourceDataBuilder = VFS.Include("spec/builders/resource_data_builder.lua")
local UnitDefBuilder = VFS.Include("spec/builders/unit_def_builder.lua")
local UnitDefsBuilder = VFS.Include("spec/builders/unit_defs_builder.lua")
local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionBuilder = VFS.Include("spec/builders/mission_builder.lua")

---@class Builders
---@field Team TeamBuilder
---@field Spring SpringBuilder
---@field SpringUnsynced SpringUnsyncedBuilder
---@field UnitDef UnitDefBuilder
---@field UnitDefs UnitDefsBuilder
---@field MissionApi MissionApiBuilder
---@field Mission MissionBuilder
local Builders = {
	Team = TeamBuilder,
	Spring = SpringSyncedBuilder,
	SpringUnsynced = SpringUnsyncedBuilder,
	ResourceData = ResourceDataBuilder,
	UnitDef = UnitDefBuilder,
	UnitDefs = UnitDefsBuilder,
	MissionApi = MissionApiBuilder,
	Mission = MissionBuilder,
}

return Builders
