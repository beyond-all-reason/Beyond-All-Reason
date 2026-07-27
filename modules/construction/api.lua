
local Debuff = VFS.Include("modules/construction/lib/build_debuff.lua")
local Creation = VFS.Include("modules/construction/lib/creation.lua")

---@class ConstructionApi
return {
	---@param unitID integer
	---@param seconds number
	DelayBuilder = function(unitID, seconds)
		Debuff.Apply(unitID, seconds)
	end,

	---@param unitID integer
	---@return boolean
	IsBuilderDelayed = function(unitID)
		return Debuff.IsDelayed(unitID)
	end,

	---Re-decides which defs a team may create. Call when a fact the decision
	---reads has changed; tech calls it when a team's tier moves.
	---@param teamID integer
	RefreshCreation = function(teamID)
		Creation.Refresh(teamID, Spring)
	end,
}
