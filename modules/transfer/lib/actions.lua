local Construction = require("modules/construction/api")
local ConstructionEnums = require("modules/construction/enums")
local ResourceTypes = require("gamedata/resource_types")

local ResourceCategory = { Metal = ResourceTypes.METAL, Energy = ResourceTypes.ENERGY }

---@class TransferGrant
---@field [string] TransferGrant

local Actions = {}

---@param action table
---@param categories table<string, string> field name -> category value
---@return table
local function withCategories(action, categories)
	for enumName, category in pairs(categories) do
		action[enumName] = { domain = action.domain, category = category }
	end
	return action
end

Actions.Transfer = {
	Units = withCategories({
		domain = "unit",
		---@param ctx MissionContext
		---@param group string
		---@param teamID integer
		Perform = function(ctx, group, teamID)
			ctx.TransferGroup(group, teamID, false)
		end,
	}, ConstructionEnums.UnitCategory),
	Resources = withCategories({ domain = "resource" }, ResourceCategory),
	Give = {
		---@param ctx MissionContext
		---@param group string
		---@param teamID integer
		Perform = function(ctx, group, teamID)
			ctx.TransferGroup(group, teamID, true)
		end,
	},
}
Actions.Construction = Construction.Actions

Actions.Take = withCategories({ domain = "take" }, ConstructionEnums.UnitCategory)

return Actions
