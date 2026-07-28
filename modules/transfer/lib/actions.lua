
local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local ResourceTypes = VFS.Include("gamedata/resource_types.lua")
local ConstructionActions = VFS.Include("modules/construction/lib/actions.lua")

local ResourceCategory = { Metal = ResourceTypes.METAL, Energy = ResourceTypes.ENERGY }

--- The facets stay untyped: only the DSL boundary reads them, from untyped runtime code.
---@class TransferGrant
---@field [string] TransferGrant

local Actions = {}

---@param action table
---@return table
local function withTiers(action)
	action.AtT2 = { domain = action.domain, category = action.category, tier = 2 }
	action.AtT3 = { domain = action.domain, category = action.category, tier = 3 }
	return action
end

---@param action table
---@param categories table<string, string> field name -> category value
---@param tiers boolean|nil
---@return table
local function withCategories(action, categories, tiers)
	for enumName, category in pairs(categories) do
		action[enumName] = { domain = action.domain, category = category }
		if tiers then
			withTiers(action[enumName])
		end
	end
	return action
end

Actions.Transfer = {
	Units = withCategories(
		withTiers({
			domain = "unit",
			---@param ctx MissionContext
			---@param group string
			---@param teamID integer
			Perform = function(ctx, group, teamID)
				ctx.TransferGroup(group, teamID, false)
			end,
		}),
		ConstructionEnums.UnitCategory,
		true
	),
	Resources = withCategories(withTiers({ domain = "resource" }), ResourceCategory, true),
	Give = {
		---@param ctx MissionContext
		---@param group string
		---@param teamID integer
		Perform = function(ctx, group, teamID)
			ctx.TransferGroup(group, teamID, true)
		end,
	},
}
Actions.Construction = ConstructionActions.Construction

Actions.Take = withCategories({ domain = "take" }, ConstructionEnums.UnitCategory)
Actions.Tech = { domain = "tech" }

return Actions
