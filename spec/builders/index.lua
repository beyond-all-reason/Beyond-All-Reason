local TeamBuilder = VFS.Include("spec/builders/team_builder.lua")
local SpringBuilder = VFS.Include("spec/builders/spring_builder.lua")

---@class Builders
---@field Team TeamBuilder
---@field Spring SpringBuilder
local Builders = {
    Team = TeamBuilder,
    Spring = SpringBuilder
}

return Builders