local facingMap = {
	south = 0,
	east = 1,
	north = 2,
	west = 3,
	s = 0,
	e = 1,
	n = 2,
	w = 3,
	[0] = 0,
	[1] = 1,
	[2] = 2,
	[3] = 3,
}

-- TODO: remove this if/when Spring.CreateFeature and/or Spring.GetHeadingFromFacing supports named facings
---Convert a named facing to a heading integer (engine uses 0-65535 headings).
---@param facing string|integer
---@return integer heading value in 0-65535 range
local function facingToHeading(facing)
	return SpringShared.GetHeadingFromFacing(facingMap[facing or 0])
end

return {
	FacingToHeading = facingToHeading,
}
