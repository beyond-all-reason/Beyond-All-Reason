-- Shared helper for STAI building rectangles.
-- Returns outX/outZ extents to reserve around a unit while placing it.
-- If a factory has an explicit exit side defined, this returns nil so callers
-- can fall back to their existing lane-calculation logic.

local DEFAULT_OUTSET_MULT = 4
local FACTORY_OUTSET_MULT_X = 6
local FACTORY_OUTSET_MULT_Z = 9

---@param unitName string
---@param unitTable table<string, {xsize:number, zsize:number, buildOptions:any}>
---@param factoryExitSides table<string, number>
---@return table|nil outsets { outX:number, outZ:number } or nil when caller should handle lane
local function getOutsets(unitName, unitTable, factoryExitSides)
	local ut = unitTable[unitName]
	if not ut then
		return nil
	end

	local exitSide = factoryExitSides[unitName]
	if exitSide ~= nil then
		-- Non-zero exit side: caller should compute a lane rectangle.
		if exitSide ~= 0 then
			return nil
		end

		-- Exit side 0 marks air factories: treat like generic buildings (no lane/apron needed).
		return {
			outX = ut.xsize * DEFAULT_OUTSET_MULT,
			outZ = ut.zsize * DEFAULT_OUTSET_MULT,
		}
	end

	if ut.buildOptions then
		-- Factory with unknown exit side: reserve a generous apron.
		return {
			outX = ut.xsize * FACTORY_OUTSET_MULT_X,
			outZ = ut.zsize * FACTORY_OUTSET_MULT_Z,
		}
	end

	return {
		outX = ut.xsize * DEFAULT_OUTSET_MULT,
		outZ = ut.zsize * DEFAULT_OUTSET_MULT,
	}
end

return {
	getOutsets = getOutsets,
}
