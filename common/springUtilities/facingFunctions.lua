local facingMap = {
	south = 0,
	east  = 1,
	north = 2,
	west  = 3,
	s = 0,
	e  = 1,
	n = 2,
	w  = 3,
	[0] = 0,
	[1] = 1,
	[2] = 2,
	[3] = 3,
}

local facingNames = { [0] = 's', [1] = 'e', [2] = 'n', [3] = 'w' }

-- TODO: remove this if/when Spring.CreateFeature and/or Spring.GetHeadingFromFacing supports named facings
---Convert a named facing to a heading integer (engine uses 0-65535 headings).
---@param facing string|integer
---@return integer heading value in 0-65535 range
local function facingToHeading(facing)
	return Spring.GetHeadingFromFacing(facingMap[facing or 0])
end

---Convert a heading integer (engine 0-65535) to a named facing letter.
---@param heading integer
---@return string facing one of 's', 'e', 'n', 'w'
local function headingToFacing(heading)
	return facingNames[Spring.GetFacingFromHeading(heading)]
end

--- Whether the given facing is east or west
--- @param facing string|integer
--- @return boolean
local function isFacingEW(facing)
	local facingValue = facingMap[facing or 0]
	return facingValue == 1 or facingValue == 3
end

return {
	FacingToHeading = facingToHeading,
	HeadingToFacing = headingToFacing,
	IsFacingEW = isFacingEW,
}
