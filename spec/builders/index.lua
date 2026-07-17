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
---@field Spring EngineSyncedBuilder
---@field SpringUnsynced EngineUnsyncedBuilder
---@field ResourceData ResourceDataBuilder
---@field UnitDef UnitDefBuilder
---@field UnitDefs UnitDefsBuilder
---@field Mode table
local Builders = {
	Team = TeamBuilder,
	EngineSynced = EngineSyncedBuilder,
	EngineUnsynced = EngineUnsyncedBuilder,
	-- Aliases from before the Spring -> Engine builder rename; existing specs use them.
	Spring = EngineSyncedBuilder,
	SpringUnsynced = EngineUnsyncedBuilder,
	ResourceData = ResourceDataBuilder,
	UnitDef = UnitDefBuilder,
	UnitDefs = UnitDefsBuilder,
}

-- Mode helpers pull in the policy pipeline (context_factory / resource_transfer_synced),
-- so load them lazily: specs that never touch Builders.Mode don't drag the pipeline into
-- their layer, which keeps the lower stacked PRs (library, modes/economy) self-contained.
return setmetatable(Builders, {
	__index = function(t, k)
		if k == "Mode" then
			local mod = VFS.Include("spec/builders/mode_test_helpers.lua")
			rawset(t, "Mode", mod)
			return mod
		end
	end,
})
