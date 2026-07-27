local Debuff = VFS.Include("modules/construction/lib/build_debuff.lua")
local Creation = VFS.Include("modules/construction/lib/creation.lua")
local Placement = VFS.Include("modules/construction/lib/placement.lua")

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

	---@param teamID integer
	RefreshCreation = function(teamID)
		Creation.Refresh(teamID, Spring)
	end,

	---@param unitDefID integer
	---@param builderTeam integer
	---@param x number
	---@param y number
	---@param z number
	---@return boolean
	MayPlace = function(unitDefID, builderTeam, x, y, z)
		return Placement.Decide(unitDefID, builderTeam, x, y, z, Spring)
	end,

	---May this team put a mex on the metal spot at x, z. One rule: the gadget refuses a build order by it, and a
	---widget colours the spot by it.
	---@param teamID integer
	---@param x number
	---@param z number
	---@return boolean
	MayPlaceMexAt = function(teamID, x, z)
		return Placement.DecideMexAt(teamID, x, z, Spring)
	end,

	---@param unitDefID integer
	---@return boolean
	IsExtractor = function(unitDefID)
		return Placement.IsExtractor(unitDefID)
	end,
}
