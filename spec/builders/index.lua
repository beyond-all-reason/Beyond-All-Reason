local TeamBuilder = VFS.Include("spec/builders/team_builder.lua")
local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local ResourceDataBuilder = VFS.Include("spec/builders/resource_data_builder.lua")
local ModeTestHelpers = VFS.Include("spec/builders/mode_test_helpers.lua")

---@class Builders
---@field Team TeamBuilder
---@field Spring SpringSyncedBuilder
---@field ResourceData ResourceDataBuilder
---@field Mode table
local Builders = {
    Team = TeamBuilder,
    Spring = SpringSyncedBuilder,
    ResourceData = ResourceDataBuilder,
    Mode = ModeTestHelpers,
}

return Builders