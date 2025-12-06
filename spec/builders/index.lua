local TeamBuilder = VFS.Include("spec/builders/team_builder.lua")
local SpringBuilder = VFS.Include("spec/builders/spring_builder.lua")
local ResourceDataBuilder = VFS.Include("spec/builders/resource_data_builder.lua")

---@class Builders
---@field Team TeamBuilder
---@field Spring SpringBuilder
---@field ResourceData ResourceDataBuilder
local Builders = {
    Team = TeamBuilder,
    Spring = SpringBuilder,
    ResourceData = ResourceDataBuilder,
}

return Builders