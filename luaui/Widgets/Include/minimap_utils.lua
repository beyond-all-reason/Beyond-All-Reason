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

local function minimapToWorld(x, y, vpy, dualScreen)
	local px, py, sx, sy = spGetMiniMapGeometry()
	if dualScreen == "left" then
		x = x + sx + px
	end
	x = ((x - px) / sx) * mapWidth
	local z = (1 - (y - py + vpy)/sy) * mapHeight

	if getMiniMapFlipped() then
		x = mapWidth - x
		z = mapHeight - z
	end

	y = spGetGroundHeight(x, z)

	return x, y, z
end

return { getMiniMapFlipped = getMiniMapFlipped, minimapToWorld = minimapToWorld }
