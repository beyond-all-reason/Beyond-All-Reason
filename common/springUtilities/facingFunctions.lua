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

local facingNames = { [0] = "s", [1] = "e", [2] = "n", [3] = "w" }

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

---Convert a named facing to the engine's facing number.
---@param facing string|integer
---@return integer facing 0 south, 1 east, 2 north, 3 west
local function facingToNumber(facing)
	return facingMap[facing or 0]
end

--- Whether the given facing is east or west
--- @param facing string|integer
--- @return boolean
local function isFacingEW(facing)
	local facingValue = facingMap[facing or 0]
	return facingValue == 1 or facingValue == 3
end

---Convert a compass angle in degrees (0 north, clockwise) to a heading.
---@param angle number
---@param radians boolean? radians, as Spring.GetUnitHeading(unitID, true) returns them, instead of 0-65535
---@return number heading
local function compassAngleToHeading(angle, radians)
	if radians then
		return math.rad(180 - angle)
	end
	return math.floor((angle % 360 - 180) / 360 * -65536)
end

-- A point closer than this is on the start point itself.
local MIN_DIRECTION_DISTANCE = 0.001

---The heading from a point toward a direction: a compass angle ({ angle }) or a point to face ({ x, z }).
---@param fromX number
---@param fromZ number
---@param direction { angle: number?, x: number?, z: number? }
---@return number heading south when the point to face is the start point
local function directionToHeading(fromX, fromZ, direction)
	if direction.angle then
		return compassAngleToHeading(direction.angle)
	end
	local dx, dz = direction.x - fromX, direction.z - fromZ
	if math.abs(dx) < MIN_DIRECTION_DISTANCE and math.abs(dz) < MIN_DIRECTION_DISTANCE then
		return facingToHeading(0)
	end
	-- Not Spring.GetHeadingFromVector: before RecoilEngine #3240 it swaps east and west for dz just above zero.
	return compassAngleToHeading(math.deg(math.atan2(dx, -dz)))
end

return {
	CompassAngleToHeading = compassAngleToHeading,
	DirectionToHeading = directionToHeading,
	FacingToHeading = facingToHeading,
	FacingToNumber = facingToNumber,
	HeadingToFacing = headingToFacing,
	IsFacingEW = isFacingEW,
}
