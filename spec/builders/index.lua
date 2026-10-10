local TeamBuilder = VFS.Include("spec/builders/team_builder.lua")
local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")
local ResourceDataBuilder = VFS.Include("spec/builders/resource_data_builder.lua")
local UnitDefBuilder = VFS.Include("spec/builders/unit_def_builder.lua")
local UnitDefsBuilder = VFS.Include("spec/builders/unit_defs_builder.lua")
local FeatureDefsBuilder = VFS.Include("spec/builders/feature_defs_builder.lua")
local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local TriggerBuilder = VFS.Include("spec/builders/trigger_builder.lua")
local TriggerContextBuilder = VFS.Include("spec/builders/trigger_context_builder.lua")

---@class Builders
---@field Team TeamBuilder
---@field Spring SpringBuilder
---@field SpringUnsynced SpringUnsyncedBuilder
---@field UnitDef UnitDefBuilder
---@field UnitDefs UnitDefsBuilder
---@field FeatureDefs FeatureDefsBuilder
---@field MissionApi MissionApiBuilder
---@field Trigger TriggerBuilder
---@field TriggerContext TriggerContextBuilder
local Builders = {
	Team = TeamBuilder,
	Spring = SpringSyncedBuilder,
	SpringUnsynced = SpringUnsyncedBuilder,
	ResourceData = ResourceDataBuilder,
	UnitDef = UnitDefBuilder,
	UnitDefs = UnitDefsBuilder,
	FeatureDefs = FeatureDefsBuilder,
	MissionApi = MissionApiBuilder,
	Trigger = TriggerBuilder,
	TriggerContext = TriggerContextBuilder,
}

return Builders
