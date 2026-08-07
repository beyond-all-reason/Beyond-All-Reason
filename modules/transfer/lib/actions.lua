--- Transfer's actions, declared once.
---
--- An action is a thing this module can do. A mode NAMES one to grant it
--- (`.Allow(Transfer.Units)`); a mission CALLS one to perform it
--- (`.Do(Transfer.Units(group, team))`). Both grammars are talking about the
--- same entry in this table, which is the point: they cannot drift, because
--- there is nothing to keep in step.
---
--- Two facets, either of which may be absent:
---   domain/category/tier  the mode facet — what a grant is written against.
---                         Absent means no mode can speak about it (Give).
---   Perform               the mission facet — what performing it does, given
---                         the mission ctx. Absent means no trigger can run it
---                         (Assist, Reclaim, Build, Tech: mode-only, so far).

local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local ResourceTypes = VFS.Include("gamedata/resource_types.lua")
local ConstructionActions = VFS.Include("modules/construction/lib/actions.lua")

--- Which resource a grant is narrowed to. Same shape as a unit category, so
--- .Tax(Transfer.Resources.Metal, 0.3) reads like .Stun(Transfer.Units.Resource, 30).
local ResourceCategory = { Metal = ResourceTypes.METAL, Energy = ResourceTypes.ENERGY }

--- A noun a grant is written against. Sub-nouns (.Units, .Resources.Metal,
--- .AtT2, ...) are the same shape narrowed, which the one indexer says, so a
--- preset's whole noun path stays typed. The facets themselves (domain,
--- category, tier, Perform) stay untyped here — only the DSL boundary reads
--- them, and it does so from untyped runtime code.
---@class TransferGrant
---@field [string] TransferGrant

local Actions = {}

--- .AtT2/.AtT3 variants carry the tech tier; they are the same action, said of
--- a later tier, so they inherit the domain and carry no facet of their own.
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
	Units = withCategories(withTiers({
		domain = "unit",
		---@param ctx MissionContext
		---@param group string
		---@param teamID integer
		Perform = function(ctx, group, teamID)
			ctx.TransferGroup(group, teamID, false)
		end,
	}), ModeEnums.UnitCategory, true),
	-- Metal and Energy: the rate behind them is one modoption today, so both
	-- resolve the same. The narrowing is real all the same — the policy takes
	-- the resource, so pricing them apart is a change of input, not of shape.
	Resources = withCategories(withTiers({ domain = "resource" }), ResourceCategory, true),
	-- No domain: fiat is not a thing a mode can grant or refuse. A mission
	-- that must not be refused says Give, and says it in the open.
	Give = {
		---@param ctx MissionContext
		---@param group string
		---@param teamID integer
		Perform = function(ctx, group, teamID)
			ctx.TransferGroup(group, teamID, true)
		end,
	},
}
-- Construction declares what a builder may do for an ally; the sharing mode
-- grants those alongside transfer's own, so a preset reads as one list.
Actions.Construction = ConstructionActions.Construction

Actions.Take = withCategories({ domain = "take" }, ModeEnums.UnitCategory)
Actions.Tech = { domain = "tech" }

return Actions
