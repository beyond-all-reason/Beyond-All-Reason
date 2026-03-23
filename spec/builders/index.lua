local TeamBuilder = VFS.Include("spec/builders/team_builder.lua")
local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local ResourceDataBuilder = VFS.Include("spec/builders/resource_data_builder.lua")

---@class Builders
---@field Team TeamBuilder
---@field Spring SpringBuilder
local Builders = {
    Team = TeamBuilder,
    Spring = SpringSyncedBuilder,
    ResourceData = ResourceDataBuilder,
}

return Builders