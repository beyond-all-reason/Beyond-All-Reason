local mapWidth = Game.mapSizeX
local mapHeight = Game.mapSizeZ

local spGetMiniMapGeometry = SpringUnsynced.GetMiniMapGeometry
local spGetGroundHeight = SpringShared.GetGroundHeight
local spGetMiniMapRotation = SpringUnsynced.GetMiniMapRotation

local math_floor = math.floor
local PI_HALF = math.pi / 2
local PI_THREE_HALF = 3 * math.pi / 2

local function getMiniMapFlipped()
	if not spGetMiniMapRotation then return false end

	local rot = spGetMiniMapRotation()

	return rot > PI_HALF and rot <= PI_THREE_HALF;
end

local ROTATION = {
    DEG_0 = 0,      -- 0 degrees
    DEG_90 = 1,     -- 90 degrees clockwise
    DEG_180 = 2,    -- 180 degrees
    DEG_270 = 3     -- 270 degrees clockwise (or 90 degrees counter-clockwise)
}

local function getCurrentMiniMapRotationOption() -- Spring.GetMiniMapRotation() returns rads, instead here we return iterations of 90 degrees (0, 1, 2, 3)
	if not spGetMiniMapRotation then return ROTATION.NONE end

	return math_floor((spGetMiniMapRotation() / math.pi * 2 + 0.5) % 4)
end

local function minimapToWorld(x, y, vpy, dualScreen)
	local px, py, sx, sy = spGetMiniMapGeometry()
	if dualScreen == "left" then
		x = x + sx + px
	end
	x = ((x - px) / sx)
	local z = (1 - (y - py + vpy)/sy)

	local currRot = getCurrentMiniMapRotationOption()

	if currRot == ROTATION.DEG_90 then -- rotate 90 degrees
		x,z = z,x
		x = 1 - x
	elseif currRot == ROTATION.DEG_180 then -- rotate 180 degrees
		x = 1 - x
		z = 1 - z
	elseif currRot == ROTATION.DEG_270 then -- rotate 270 degrees
		x, z = z, x
		z = 1 - z
	end

	x = x * mapWidth
	z = z * mapHeight

	y = spGetGroundHeight(x, z)

	return x, y, z
end

return { getMiniMapFlipped = getMiniMapFlipped, minimapToWorld = minimapToWorld, getCurrentMiniMapRotationOption = getCurrentMiniMapRotationOption, ROTATION = ROTATION }
