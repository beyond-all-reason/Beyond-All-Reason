local facingToHeadingMap = {
	s = 0, n = 32768, e = 16384, w = 49152,
	south = 0, north = 32768, east = 16384, west = 49152,
	[0] = 0, [1] = 32768, [2] = 16384, [3] = 49152,
}

---Convert a named facing to a heading integer (engine uses 0-65535 headings).
---Accepts cardinal direction strings ("s"/"south", "n"/"north", "e"/"east", "w"/"west")
---or facing integers (0=south, 1=east, 2=north, 3=west).
---@param facing string|integer
---@return integer heading value in 0-65535 range
local function facingToHeading(facing)
	return facingToHeadingMap[facing or 0]
end

return {
	FacingToHeading = facingToHeading,
}
