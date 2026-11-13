local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Map Lights (Terraform Brush)",
		desc = "Places the deferred lights a map exported from a Terraform Brush project carries (mapconfig/lights.lua)",
		author = "PtaQ",
		date = "2026-11-05",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- The file is the light placer's own save format (cmd_light_placer.lua), copied by the map
-- export. The calls below are the placer's spawnLight, so a map shows what its author placed.
-- When the editor is open on such a map, the lights are handed to the placer instead, so they
-- can be edited and saved into a project.
local FILE = "mapconfig/lights.lua"
if not VFS.FileExists(FILE, VFS.MAP) then
	return false
end

local rad, sin, cos = math.rad, math.sin, math.cos

---@type table[]?
local list
---@type table?
local api
local placed = {} -- instanceID -> light shape
local handed = false

local function direction(pitchDeg, yawDeg)
	local p, y = rad(pitchDeg), rad(yawDeg)
	return cos(p) * sin(y), sin(p), cos(p) * cos(y)
end

local function spawnAll()
	api = WG.lightsgl4
	if not (api and list) then
		return
	end
	for _, l in ipairs(list) do
		local pos = type(l.pos) == "table" and l.pos or {}
		local x, z = tonumber(pos[1]), tonumber(pos[3])
		if x and z then
			-- like the placer: height above the ground, not the saved y
			local y = (Spring.GetGroundHeight(x, z) or 0) + (tonumber(l.elevation) or 20)
			local c, br, radius = l.color or { 1, 1, 1 }, tonumber(l.brightness) or 1, tonumber(l.radius) or 200
			local r, g, b = (c[1] or 1) * br, (c[2] or 1) * br, (c[3] or 1) * br
			local mf, sp, sc, lf = l.modelfactor or 1, l.specular or 1, l.scattering or 1, l.lensflare or 0
			local id, shape
			if l.type == "cone" then
				local dx, dy, dz = direction(l.pitch or -90, l.yaw or 0)
				id = api.AddConeLight(
					nil,
					nil,
					nil,
					nil,
					x,
					y,
					z,
					radius,
					r,
					g,
					b,
					1.0,
					dx,
					dy,
					dz,
					l.theta or 0.5,
					0,
					mf,
					sp,
					sc,
					lf,
					nil,
					0,
					1,
					0
				)
				shape = "cone"
			elseif l.type == "beam" then
				local dx, dy, dz = direction(l.pitch or 0, l.yaw or 0)
				local len = l.beamLength or 300
				id = api.AddBeamLight(
					nil,
					nil,
					nil,
					nil,
					x,
					y,
					z,
					radius,
					r,
					g,
					b,
					1.0,
					x + dx * len,
					y + dy * len,
					z + dz * len,
					radius,
					0,
					mf,
					sp,
					sc,
					lf,
					nil,
					0,
					1,
					0
				)
				shape = "beam"
			else
				id = api.AddPointLight(
					nil,
					nil,
					nil,
					nil,
					x,
					y,
					z,
					radius,
					r,
					g,
					b,
					1.0,
					0,
					0,
					0,
					0,
					mf,
					sp,
					sc,
					lf,
					nil,
					0,
					1,
					0
				)
				shape = "point"
			end
			if id then
				placed[id] = shape
			end
		end
	end
end

local function removeAll()
	if api then
		for id, shape in pairs(placed) do
			api.RemoveLight(shape, id, nil)
		end
	end
	placed = {}
end

function widget:Initialize()
	local ok, data = pcall(VFS.Include, FILE, {}, VFS.MAP)
	if not (ok and type(data) == "table" and type(data.lights) == "table") then
		Spring.Echo("[Map Lights] " .. FILE .. " not applied: " .. tostring(ok and "bad format" or data))
		widgetHandler:RemoveWidget(self)
		return
	end
	list = data.lights
	spawnAll()
end

function widget:Update()
	if not list then
		return
	end
	local lp = WG.LightPlacer
	if lp and lp.addLights and not handed then
		-- the editor is open: the placer owns the lights from now on (editable, saved with a project)
		handed = true
		removeAll()
		local items = {}
		for _, l in ipairs(list) do
			local pos = type(l.pos) == "table" and l.pos or {}
			if tonumber(pos[1]) and tonumber(pos[3]) then
				items[#items + 1] = { x = pos[1], z = pos[3], def = l }
			end
		end
		lp.addLights(items)
	elseif handed and not WG.LightPlacer then
		-- the editor closed and its placer took its lights along: show the map's again
		handed = false
		spawnAll()
	elseif not handed and WG.lightsgl4 ~= api then
		-- the deferred lights widget (re)loaded and lost every light
		placed = {}
		spawnAll()
	end
end

function widget:Shutdown()
	if not handed then
		removeAll()
	end
end
