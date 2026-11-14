local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitBuildFacing = Spring.GetUnitBuildFacing

---@param unitDef table
---@param facing integer? 0 south, 1 east, 2 north, 3 west
---@return number width in elmos, along x
---@return number depth in elmos, along z
local function getFootprintSize(unitDef, facing)
	local width, depth = unitDef.xsize * 8, unitDef.zsize * 8
	if facing == 1 or facing == 3 then
		return depth, width
	end
	return width, depth
end

--- The allied frame a blueprint of unitDefID at x, z would assist instead of starting a new unit.
--- Compares the two footprint rectangles; the engine goes on to read the yardmap per cell.
---@param unitDefID integer
---@param teamID integer
---@param x number
---@param z number
---@param facing integer?
---@return integer? unitID
local function getAssistableFrame(unitDefID, teamID, x, z, facing)
	local unitDef = UnitDefs[unitDefID] --[[@as table]]
	local width, depth = getFootprintSize(unitDef, facing)
	for _, unitID in ipairs(spGetUnitsInCylinder(x, z, math.diag(width, depth))) do
		if
			spGetUnitDefID(unitID) == unitDefID
			and spGetUnitIsBeingBuilt(unitID)
			and spAreTeamsAllied(spGetUnitTeam(unitID), teamID)
		then
			local frameWidth, frameDepth = getFootprintSize(unitDef, spGetUnitBuildFacing(unitID))
			local ux, _, uz = spGetUnitPosition(unitID)
			if math.abs(ux - x) < (width + frameWidth) / 2 and math.abs(uz - z) < (depth + frameDepth) / 2 then
				return unitID
			end
		end
	end
	return nil
end

return {
	GetFootprintSize = getFootprintSize,
	GetAssistableFrame = getAssistableFrame,
}
