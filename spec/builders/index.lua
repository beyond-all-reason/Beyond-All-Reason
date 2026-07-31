local TeamBuilder = VFS.Include("spec/builders/team_builder.lua")
local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")
local ResourceDataBuilder = VFS.Include("spec/builders/resource_data_builder.lua")
local UnitDefBuilder = VFS.Include("spec/builders/unit_def_builder.lua")
local UnitDefsBuilder = VFS.Include("spec/builders/unit_defs_builder.lua")

---@class Builders
---@field Team TeamBuilder
---@field Spring SpringBuilder
---@field SpringUnsynced SpringUnsyncedBuilder
---@field UnitDef UnitDefBuilder
---@field UnitDefs UnitDefsBuilder
local Builders = {
    Team = TeamBuilder,
    Spring = SpringSyncedBuilder,
    SpringUnsynced = SpringUnsyncedBuilder,
    ResourceData = ResourceDataBuilder,
    UnitDef = UnitDefBuilder,
    UnitDefs = UnitDefsBuilder,
}

return Builders