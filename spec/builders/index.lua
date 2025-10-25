local TeamBuilder = require("spec/builders/team_builder")
local SpringBuilder = require("spec/builders/spring_builder")

---@class Builders
---@field Team TeamBuilder
---@field Spring SpringBuilder
local Builders = {
    Team = TeamBuilder,
    Spring = SpringBuilder
}

return Builders