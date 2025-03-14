local mapWidth = Game.mapSizeX
local mapHeight = Game.mapSizeZ

local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spGetGroundHeight = Spring.GetGroundHeight
local spGetMiniMapRotation = Spring.GetMiniMapRotation

local function getMiniMapFlipped()
	if not spGetMiniMapRotation then return false end

	local rot = spGetMiniMapRotation()

	return rot > math.pi/2 and rot <= 3 * math.pi/2;
end

local function getMiniMapRotationOptions() -- Spring.GetMiniMapRotation() returns rads, instead here we return iterations of 90 degrees (0, 1, 2, 3)
	if not spGetMiniMapRotation then return 0 end

	return math.floor((spGetMiniMapRotation() / math.pi * 2 + 0.5) % 4)
end

local function minimapToWorld(x, y, vpy, dualScreen)
	local px, py, sx, sy = spGetMiniMapGeometry()
	if dualScreen == "left" then
		x = x + sx + px
	end
	x = ((x - px) / sx) * mapWidth
	local z = (1 - (y - py + vpy)/sy) * mapHeight

	if getMiniMapRotationOptions() == 1 then
		local temp = x
		x = mapWidth - z
		z = temp
	elseif getMiniMapRotationOptions() == 2 then
		x = mapWidth - x
		z = mapHeight - z
	elseif getMiniMapRotationOptions() == 3 then
		local temp = x
		x = z
		z = mapHeight - temp
	end

	y = spGetGroundHeight(x, z)

	return x, y, z
end

return { getMiniMapFlipped = getMiniMapFlipped, minimapToWorld = minimapToWorld, getMiniMapRotationOptions = getMiniMapRotationOptions }
