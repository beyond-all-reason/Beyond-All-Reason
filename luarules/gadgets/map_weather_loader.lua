local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Map Weather (Terraform Brush)",
		desc = "Runs the visual weather spawners a map exported from a Terraform Brush project carries (mapconfig/weather.lua)",
		author = "PtaQ",
		date = "2026-11-05",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Synced on purpose: every client must see the same CEGs, and the weather brush's own route
-- (a LuaRules message per burst) only works with cheats on and would make every client send
-- its own. Visual only: gameplay weather is a game condition the Mission API starts.
-- The spawn loop is the weather brush's (cmd_weather_brush.lua): shape sampling, a 5 s fade
-- in, an 8 s fade out before a timed spawner ends, the saturation cadence.
-- In an editor session the weather brush seeds itself from the same file instead.
if not gadgetHandler:IsSyncedCode() then
	return false
end

local FILE = "mapconfig/weather.lua"
local modOptions = Spring.GetModOptions()
if modOptions.mapeditor or not modOptions.map_atmosphere or not VFS.FileExists(FILE, VFS.MAP) then
	return false
end

local isInside = require("common/brush_shapes").isInside
local SpawnCEG, GetGroundHeight = Spring.SpawnCEG, Spring.GetGroundHeight
local floor, max, min, random = math.floor, math.max, math.min, math.random
local FPS = Game.gameSpeed
local FADE_IN, FADE_OUT = 5 * FPS, 8 * FPS

local spawners = {}

function gadget:Initialize()
	local ok, data = pcall(VFS.Include, FILE, {}, VFS.MAP)
	local list = ok and type(data) == "table" and type(data.spawners) == "table" and data.spawners or {}
	for _, e in ipairs(list) do
		if type(e) == "table" and type(e.cegs) == "table" and #e.cegs > 0 and tonumber(e.x) and tonumber(e.z) then
			local interval = max(1, floor(tonumber(e.interval) or FPS))
			local refresh = max(interval, floor(tonumber(e.refreshInterval) or interval))
			local persistence = tonumber(e.persistence) or -1
			spawners[#spawners + 1] = {
				e = e,
				interval = interval,
				refresh = refresh,
				count = max(1, floor(tonumber(e.count) or 1)),
				saturation = max(1, floor(refresh / interval)),
				expire = persistence >= 0 and max(1, floor(persistence * FPS)) or nil,
				nextFrame = 0,
				cycles = 0,
			}
		end
	end
	if #spawners == 0 then
		gadgetHandler:RemoveGadget(self)
	end
end

local function burst(e, n)
	local radius, lengthScale = tonumber(e.radius) or 100, tonumber(e.lengthScale) or 1
	local shape, angle = e.shape or "circle", tonumber(e.angleDeg) or 0
	local extent, altitude = max(radius, radius * lengthScale), floor(tonumber(e.altitude) or 0)
	for i = 1, n do
		local x, z = e.x, e.z
		for _ = 1, 100 do
			local rx, rz = e.x + (random() * 2 - 1) * extent, e.z + (random() * 2 - 1) * extent
			if isInside(rx - e.x, rz - e.z, radius, shape, angle, lengthScale) then
				x, z = rx, rz
				break
			end
		end
		x, z = max(0, min(Game.mapSizeX, floor(x))), max(0, min(Game.mapSizeZ, floor(z)))
		SpawnCEG(e.cegs[(i - 1) % #e.cegs + 1], x, (GetGroundHeight(x, z) or 0) + altitude, z, 0, 1, 0, 1, 0)
	end
end

function gadget:GameFrame(f)
	for i = #spawners, 1, -1 do
		local s = spawners[i]
		if s.expire and f >= s.expire then
			table.remove(spawners, i)
		elseif f >= s.nextFrame then
			local n = s.count
			if f < FADE_IN then
				n = max(1, floor(s.count * f / FADE_IN + 0.5))
			end
			if s.expire and s.expire - f < FADE_OUT then
				n = max(0, floor(s.count * (s.expire - f) / FADE_OUT + 0.5))
			end
			local saturated = s.cycles >= s.saturation
			if n > 0 then
				burst(s.e, n)
				s.cycles = s.cycles + 1
			end
			s.nextFrame = f + (saturated and s.refresh or s.interval)
		end
	end
	if #spawners == 0 then
		gadgetHandler:RemoveCallIn("GameFrame")
	end
end
