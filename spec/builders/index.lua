local TeamBuilder = require("spec/builders/team_builder")
local SpringRepositoryBuilder = require("spec/builders/spring_repository_builder")

---@class Builders
---@field Team TeamBuilder
---@field SpringRepository SpringRepositoryBuilder
local Builders = {
    Team = TeamBuilder,
    SpringRepository = SpringRepositoryBuilder,
}

return Builders