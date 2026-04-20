function gadget:GetInfo()
	return {
		name    = "Weather Brush CEG Spawner",
		desc    = "Synced gadget that spawns CEGs on behalf of the Weather Brush widget",
		author  = "BARb",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------
local SPAWN_HEADER = "$weather_ceg$"
local HEADER_LEN   = #SPAWN_HEADER

----------------------------------------------------------------
-- Localize
----------------------------------------------------------------
local SpawnCEG        = Spring.SpawnCEG
local GetGroundHeight = Spring.GetGroundHeight
local max             = math.max
local min             = math.min
local tonumber        = tonumber

----------------------------------------------------------------
-- Message handler
----------------------------------------------------------------
-- Message format: "$weather_ceg$cegName x z"
-- Multiple spawns can be batched: "$weather_ceg$cegName x z|cegName x z|..."

function gadget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, HEADER_LEN) ~= SPAWN_HEADER then
		return
	end

	if not Spring.IsCheatingEnabled() then
		return true
	end

	local payload = msg:sub(HEADER_LEN + 1)

	for entry in payload:gmatch("[^|]+") do
		local cegName, sx, sz, syOff = entry:match("^(%S+)%s+(%S+)%s+(%S+)%s*(%S*)$")
		local x = tonumber(sx)
		local z = tonumber(sz)
		local yOff = tonumber(syOff) or 0
		if cegName and x and z then
			x = max(0, min(Game.mapSizeX, x))
			z = max(0, min(Game.mapSizeZ, z))
			local y = (GetGroundHeight(x, z) or 0) + yOff
			SpawnCEG(cegName, x, y, z, 0, 1, 0, 1, 0)
		end
	end

	return true
end
