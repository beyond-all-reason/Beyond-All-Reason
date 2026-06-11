local TeamBuilder = VFS.Include("spec/builders/team_builder.lua")
local EngineSyncedBuilder = VFS.Include("spec/builders/engine_synced_builder.lua")
local EngineUnsyncedBuilder = VFS.Include("spec/builders/engine_unsynced_builder.lua")
local ResourceDataBuilder = VFS.Include("spec/builders/resource_data_builder.lua")
local UnitDefBuilder = VFS.Include("spec/builders/unit_def_builder.lua")
local UnitDefsBuilder = VFS.Include("spec/builders/unit_defs_builder.lua")

---@class Builders
---@field Team TeamBuilder
---@field EngineSynced EngineSyncedBuilder
---@field EngineUnsynced EngineUnsyncedBuilder
---@field UnitDef UnitDefBuilder
---@field UnitDefs UnitDefsBuilder
local Builders = {
	Team = TeamBuilder,
	EngineSynced = EngineSyncedBuilder,
	EngineUnsynced = EngineUnsyncedBuilder,
	ResourceData = ResourceDataBuilder,
	UnitDef = UnitDefBuilder,
	UnitDefs = UnitDefsBuilder,
}

return Builders
