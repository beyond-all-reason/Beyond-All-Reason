local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Map Lighting",
		desc = "Changes map lighting, time of day and skybox at runtime (GG.MapLighting)",
		author = "Floris",
		date = "2026-10",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--[[
	Provides the synced API:
		GG.MapLighting.SetLighting(values, duration)
		GG.MapLighting.SetTimeOfDay(hour, duration, dayLength)
		GG.MapLighting.SetSkybox(texture, rotation)
		GG.MapLighting.Reset(duration)

	values, all optional; each call changes only the values it names:
		groundAmbientColor, groundDiffuseColor, groundSpecularColor,
		unitAmbientColor, unitDiffuseColor, unitSpecularColor     {r, g, b}
		groundShadowDensity, unitShadowDensity                    0 to 1
		sunAzimuth     compass degrees, 0 = north (-z), 90 = east (+x)
		sunElevation   degrees above the horizon, kept between 1 and 90
		brightness     multiplier >= 0 on all colours, tint {r, g, b} multiplier
	Hour 12 (0 to 24) is the lighting above; other hours move the sun and dim the light without changing its
	colours, with a dim light from the other side of the sky at night.
	dayLength (seconds per 24 hours) keeps the clock running once the hour is reached.
	texture is a DDS cubemap; rotation turns the sky about the vertical axis, in degrees.
	Durations are game seconds, default 0. Reset returns to the map's own lighting.
	Callers validate the values; the mission API does so when it loads a mission.

	gl.GetSun is unsynced only, so the synced side only forwards. The unsynced side reads the map's
	lighting at the first change and blends on game time, so all clients and replays look the same.
	Like map_nightmode.lua it drives GG.NightFactor and NightFactorChanged, for effects that do not read the
	engine's lighting; that gadget's /luarules NightMode commands are a separate debug tool.
]]

local SYNCACTION = "MapLighting"
local COLOR_FACTORS = {
	groundAmbientColor = "ambient",
	groundDiffuseColor = "diffuse",
	groundSpecularColor = "specular",
	unitAmbientColor = "ambient",
	unitDiffuseColor = "diffuse",
	unitSpecularColor = "specular",
}

local function clamp(value, low, high)
	return math.min(math.max(value, low), high)
end

if gadgetHandler:IsSyncedCode() then
	local spGetGameFrame = Spring.GetGameFrame

	local function toFrames(seconds)
		return math.floor((seconds or 0) * Game.gameSpeed + 0.5)
	end

	GG.MapLighting = {
		SetLighting = function(values, duration)
			SendToUnsynced(SYNCACTION, "SetLighting", spGetGameFrame(), toFrames(duration), values)
		end,
		SetTimeOfDay = function(hour, duration, dayLength)
			SendToUnsynced(SYNCACTION, "SetTimeOfDay", spGetGameFrame(), toFrames(duration), hour, toFrames(dayLength))
		end,
		SetSkybox = function(texture, rotation)
			SendToUnsynced(SYNCACTION, "SetSkybox", spGetGameFrame(), texture, rotation)
		end,
		Reset = function(duration)
			SendToUnsynced(SYNCACTION, "Reset", spGetGameFrame(), toFrames(duration))
		end,
	}

	function gadget:Shutdown()
		GG.MapLighting = nil
	end
else
	local spGetGameFrame = Spring.GetGameFrame
	local spSetAtmosphere = Spring.SetAtmosphere
	local spSetSunDirection = Spring.SetSunDirection
	local spSetSunLighting = Spring.SetSunLighting
	local glGetAtmosphere = gl.GetAtmosphere
	local glGetSun = gl.GetSun

	local sin, cos, asin, atan2, sqrt = math.sin, math.cos, math.asin, math.atan2, math.sqrt
	local rad, deg, pi = math.rad, math.deg, math.pi

	local UNIT_LIGHT_KEPT = 0.66 -- units follow a third of the change, so they stay readable
	local NOTIFY_SECONDS = 1 -- widgets lose the night factor on /luaui reload

	local function dayKey(hour, diffuse, ambient, specular, sky, shadow)
		return { hour = hour, diffuse = diffuse, ambient = ambient, specular = specular, sky = sky, shadow = shadow }
	end

	-- Light levels on the map's noon lighting for the morning; the afternoon mirrors them. They only scale the
	-- map's own colours, never tint them: BAR's planets are not Earth, their skies have the map's colours.
	-- The sun and the night light swap places at SUN_FLIP_HOUR, while there are no shadows and the light is dimmest.
	-- stylua: ignore start
	---@type table<integer, table>
	local DAY_KEYS = {
		--     hour  diffuse  ambient  specular  sky (and fog)  shadow
		dayKey(0,    0.25,    0.27,    0.20,     0.08,          0.45),
		dayKey(4.5,  0.25,    0.27,    0.20,     0.08,          0.45),
		dayKey(5.4,  0.10,    0.27,    0.05,     0.17,          0),
		dayKey(5.6,  0.11,    0.28,    0.05,     0.20,          0),
		dayKey(6,    0.51,    0.48,    0.40,     0.51,          0.55),
		dayKey(7,    0.79,    0.74,    0.75,     0.78,          0.85),
		dayKey(9,    0.96,    0.96,    0.95,     0.97,          1),
		dayKey(12,   1,       1,       1,        1,             1),
	}
	-- stylua: ignore end
	local SUN_FLIP_HOUR = 5.5 -- and 24 - 5.5
	local SUN_SWING = 75 -- degrees of azimuth from noon to the flip
	local TWILIGHT_ELEVATION = 6 -- degrees
	local NIGHT_LIGHT_ELEVATION = 40 -- degrees, the dim light from the other side of the sky

	-- shared with map_nightmode.lua, so it is read from GG each time
	GG.NightFactor = GG.NightFactor or { red = 1, green = 1, blue = 1, shadow = 1, altitude = 1 }

	local active = false -- false while the map's own lighting shows
	local base = {} ---@type table the lighting before the first change
	---@type { from: table, to: table, startFrame: number, frames: number }
	local lighting = { from = {}, to = {}, startFrame = 0, frames = 0 }
	---@type { fromHour: number, toHour: number, startFrame: number, frames: number, dayFrames: number }
	local clock = { fromHour = 12, toHour = 12, startFrame = 0, frames = 0, dayFrames = 0 }
	local skybox = { applied = false } ---@type { pending: string?, applied: boolean, rotation: number? }
	local resetting, dirty, settled = false, false, false
	local lastFrame ---@type number?
	local lastDirection ---@type number[]?
	local lastSunLighting ---@type table?
	local notifySeconds = 0 ---@type number
	local mapSkybox ---@type boolean?

	local function mix(a, b, f)
		return a + (b - a) * f
	end

	local function ease(f)
		return f * f * (3 - 2 * f)
	end

	local function shortArc(from, to, period)
		local difference = (to - from) % period
		if difference > period / 2 then
			difference = difference - period
		end
		return difference
	end

	local function ratio(value, reference)
		if reference < 1e-6 then
			return 1
		end
		return clamp(value / reference, 0, 4)
	end

	local function directionFromAngles(azimuth, elevation)
		local a, e = rad(azimuth), rad(elevation)
		return sin(a) * cos(e), sin(e), -cos(a) * cos(e)
	end

	local function anglesFromDirection(x, y, z)
		local azimuth = (x * x + z * z > 1e-4) and deg(atan2(x, -z)) or 180
		return azimuth % 360, deg(asin(clamp(y, -1, 1)))
	end

	local function timeOfDayFactors(hour)
		local h = hour <= 12 and hour or 24 - hour
		local i = 2
		while DAY_KEYS[i].hour < h do
			i = i + 1
		end
		local a, b = DAY_KEYS[i - 1], DAY_KEYS[i]
		local f = (h - a.hour) / (b.hour - a.hour)
		local factors = {} ---@type table<string, number>
		for _, key in ipairs({ "diffuse", "ambient", "specular", "sky", "shadow" }) do
			factors[key] = mix(a[key], b[key], f)
		end
		return factors
	end

	local function sunPath(hour, azimuth, elevation)
		local low = math.min(TWILIGHT_ELEVATION, elevation)
		local peak, d = elevation, nil
		if hour >= SUN_FLIP_HOUR and hour <= 24 - SUN_FLIP_HOUR then
			d = (hour - 12) / (12 - SUN_FLIP_HOUR)
		else
			d = ((hour < 12 and hour + 24 or hour) - 24) / SUN_FLIP_HOUR
			azimuth = azimuth + 180
			peak = math.max(low, math.min(NIGHT_LIGHT_ELEVATION, elevation))
		end
		return azimuth + SUN_SWING * d, low + (peak - low) * cos(d * pi / 2)
	end

	local function baseParams()
		local params = {
			brightness = 1,
			tint = { 1, 1, 1 },
			sunAzimuth = base.sunAzimuth,
			sunElevation = base.sunElevation,
			groundShadowDensity = base.groundShadowDensity,
			unitShadowDensity = base.unitShadowDensity,
		}
		for key in pairs(COLOR_FACTORS) do
			params[key] = base[key]
		end
		return params
	end

	local function blendParams(from, to, f)
		local blended = {} ---@type table
		for key, value in pairs(to) do
			local start = from[key]
			if type(value) == "table" then
				blended[key] = { mix(start[1], value[1], f), mix(start[2], value[2], f), mix(start[3], value[3], f) }
			elseif key == "sunAzimuth" then
				blended[key] = start + shortArc(start, value, 360) * f
			else
				blended[key] = mix(start, value, f)
			end
		end
		return blended
	end

	local function lightingAt(t)
		local elapsed = t - lighting.startFrame
		if lighting.frames <= 0 or elapsed >= lighting.frames then
			return lighting.to
		end
		return blendParams(lighting.from, lighting.to, ease(math.max(elapsed, 0) / lighting.frames))
	end

	local function hourAt(t)
		local elapsed = t - clock.startFrame
		local hour = clock.toHour
		if clock.frames > 0 and elapsed < clock.frames then
			local f = ease(math.max(elapsed, 0) / clock.frames)
			hour = clock.fromHour + shortArc(clock.fromHour, clock.toHour, 24) * f
		elseif clock.dayFrames > 0 then
			hour = hour + (elapsed - clock.frames) * 24 / clock.dayFrames
		end
		return hour % 24
	end

	local function takeSnapshot()
		local x, y, z = glGetSun("pos", "ground")
		if not (x and y and z) then
			return false
		end
		local length = sqrt(x * x + y * y + z * z)
		x, y, z = x / length, y / length, z / length
		local azimuth, elevation = anglesFromDirection(x, y, z)
		base = {
			groundAmbientColor = { glGetSun("ambient", "ground") },
			groundDiffuseColor = { glGetSun("diffuse", "ground") },
			groundSpecularColor = { glGetSun("specular", "ground") },
			unitAmbientColor = { glGetSun("ambient", "unit") },
			unitDiffuseColor = { glGetSun("diffuse", "unit") },
			unitSpecularColor = { glGetSun("specular", "unit") },
			groundShadowDensity = glGetSun("shadowDensity", "ground"),
			unitShadowDensity = glGetSun("shadowDensity", "unit"),
			sunDirection = { x, y, z },
			sunAzimuth = azimuth,
			sunElevation = elevation,
			skyColor = { glGetAtmosphere("skyColor") },
			sunColor = { glGetAtmosphere("sunColor") },
			cloudColor = { glGetAtmosphere("cloudColor") },
			fogColor = { glGetAtmosphere("fogColor") },
			skyAxisAngle = { glGetAtmosphere("skyAxisAngle") },
		}
		active = true
		lighting.from, lighting.to, lighting.frames = baseParams(), baseParams(), 0
		clock.fromHour, clock.toHour, clock.frames, clock.dayFrames = 12, 12, 0, 0
		GG.MapLightingActive = true -- map_atmosphere_cegs.lua stops changing the sun
		return true
	end

	local function sameValues(a, b)
		for key, value in pairs(a) do
			local other = b[key]
			if type(value) == "table" then
				if value[1] ~= other[1] or value[2] ~= other[2] or value[3] ~= other[3] then
					return false
				end
			elseif value ~= other then
				return false
			end
		end
		return true
	end

	local function setNightFactor(red, green, blue, shadow, altitude)
		local factor = GG.NightFactor
		local changed = factor.red ~= red
			or factor.green ~= green
			or factor.blue ~= blue
			or factor.shadow ~= shadow
			or factor.altitude ~= altitude
		factor.red, factor.green, factor.blue, factor.shadow, factor.altitude = red, green, blue, shadow, altitude
		if changed or notifySeconds >= NOTIFY_SECONDS then
			notifySeconds = 0
			if Script.LuaUI("NightFactorChanged") then
				Script.LuaUI.NightFactorChanged(red, green, blue, shadow, altitude)
			end
		end
	end

	local function apply(t, force)
		local params = lightingAt(t)
		local hour = hourAt(t)
		local factors = timeOfDayFactors(hour)
		local brightness, tint = params.brightness, params.tint
		---@type table<integer, number>
		local multiplier = { brightness * tint[1], brightness * tint[2], brightness * tint[3] }
		local groundLight = { 0, 0, 0 } ---@type table<integer, number> ambient + diffuse, for the night factor
		local baseGroundLight = { 0, 0, 0 } ---@type table<integer, number>

		---@type table
		local sunLighting = {
			groundShadowDensity = params.groundShadowDensity * factors.shadow,
			modelShadowDensity = params.unitShadowDensity * factors.shadow,
		}
		for key, factorKey in pairs(COLOR_FACTORS) do
			local color, factor = params[key], factors[factorKey]
			local isUnit = key:sub(1, 4) == "unit"
			local isGroundLight = key == "groundAmbientColor" or key == "groundDiffuseColor"
			local result = {}
			for i = 1, 3 do
				local f = multiplier[i] * factor
				result[i] = color[i] * (isUnit and mix(f, 1, UNIT_LIGHT_KEPT) or f)
				if isGroundLight then
					groundLight[i] = groundLight[i] + result[i]
					baseGroundLight[i] = baseGroundLight[i] + base[key][i]
				end
			end
			sunLighting[key] = result
		end

		---@type table
		local atmosphere = {
			skyColor = {},
			sunColor = {},
			cloudColor = {},
			fogColor = { 0, 0, 0, base.fogColor[4] },
			skyAxisAngle = skybox.rotation and { 0, 1, 0, rad(skybox.rotation) } or base.skyAxisAngle,
		}
		for i = 1, 3 do
			atmosphere.skyColor[i] = base.skyColor[i] * multiplier[i] * factors.sky
			atmosphere.cloudColor[i] = base.cloudColor[i] * multiplier[i] * factors.sky
			atmosphere.fogColor[i] = base.fogColor[i] * multiplier[i] * factors.sky
			atmosphere.sunColor[i] = base.sunColor[i] * multiplier[i] * factors.diffuse
		end

		local azimuth, elevation = sunPath(hour, params.sunAzimuth, params.sunElevation)
		local x, y, z = directionFromAngles(azimuth, elevation)

		-- SunChanged listeners such as cus_gl4.lua read GG.NightFactor, so it goes first
		setNightFactor(
			ratio(groundLight[1], baseGroundLight[1]),
			ratio(groundLight[2], baseGroundLight[2]),
			ratio(groundLight[3], baseGroundLight[3]),
			ratio(sunLighting.groundShadowDensity, base.groundShadowDensity),
			ratio(y, base.sunDirection[2])
		)

		spSetAtmosphere(atmosphere)
		local direction = { x, y, z }
		if force or not lastDirection or not sameValues(direction, lastDirection) then
			spSetSunDirection(x, y, z)
			lastDirection = direction
		end
		-- the last write, so the final SunChanged sees all of it
		if force or not lastSunLighting or not sameValues(sunLighting, lastSunLighting) then
			spSetSunLighting(sunLighting)
			lastSunLighting = sunLighting
		end
	end

	local function restoreBase()
		setNightFactor(1, 1, 1, 1, 1)
		spSetAtmosphere({
			skyColor = base.skyColor,
			sunColor = base.sunColor,
			cloudColor = base.cloudColor,
			fogColor = base.fogColor,
			skyAxisAngle = base.skyAxisAngle,
		})
		spSetSunDirection(base.sunDirection[1], base.sunDirection[2], base.sunDirection[3])
		---@type table
		local sunLighting = {
			groundShadowDensity = base.groundShadowDensity,
			modelShadowDensity = base.unitShadowDensity,
		}
		for key in pairs(COLOR_FACTORS) do
			sunLighting[key] = base[key]
		end
		spSetSunLighting(sunLighting)
		lastFrame, lastDirection, lastSunLighting = nil, nil, nil
		active, resetting, settled = false, false, false
		GG.MapLightingActive = nil
	end

	local function mapHasOwnSkybox()
		if mapSkybox == nil then
			mapSkybox = false
			local success, mapinfo = pcall(VFS.Include, "mapinfo.lua")
			local atmosphere = success and type(mapinfo) == "table" and mapinfo.atmosphere
			if type(atmosphere) == "table" then
				for key, value in pairs(atmosphere) do
					if type(key) == "string" and key:lower() == "skybox" then
						mapSkybox = type(value) == "string" and value ~= ""
					end
				end
			end
		end
		return mapSkybox
	end

	local commands = {}

	function commands.SetLighting(frame, frames, values)
		lighting.from = lightingAt(frame)
		local to = {}
		for key, value in pairs(lighting.to) do
			to[key] = value
		end
		for key, value in pairs(values) do
			to[key] = value
		end
		to.sunElevation = clamp(to.sunElevation, 1, 90) -- a sun at or below the horizon breaks the shadows
		lighting.to, lighting.startFrame, lighting.frames = to, frame, frames
	end

	function commands.SetTimeOfDay(frame, frames, hour, dayFrames)
		clock.fromHour = hourAt(frame)
		clock.toHour, clock.startFrame, clock.frames, clock.dayFrames = hour, frame, frames, dayFrames
	end

	function commands.SetSkybox(_, texture, rotation)
		skybox.pending = texture
		skybox.rotation = rotation or skybox.rotation
	end

	function commands.Reset(frame, frames)
		commands.SetLighting(frame, frames, baseParams())
		commands.SetTimeOfDay(frame, frames, 12, 0)
		skybox.rotation = nil
		if skybox.applied and mapHasOwnSkybox() then
			skybox.pending = "" -- back to the map's skybox; a procedural sky cannot come back
		end
	end

	local function onSyncAction(_, command, frame, ...)
		if not active and (command == "Reset" or not takeSnapshot()) then
			return
		end
		commands[command](frame, ...)
		resetting = command == "Reset"
		dirty = true
	end

	-- At most once per game frame: every apply fires SunChanged and rebuilds the map's shading texture
	function gadget:Update(deltaTime)
		if not active then
			return
		end
		notifySeconds = notifySeconds + deltaTime
		local frame = spGetGameFrame()
		if not dirty and (settled or frame == lastFrame) then
			if settled and resetting then
				restoreBase()
			elseif notifySeconds >= NOTIFY_SECONDS then
				local f = GG.NightFactor
				setNightFactor(f.red, f.green, f.blue, f.shadow, f.altitude)
			end
			return
		end
		local moving = frame < lighting.startFrame + lighting.frames or frame < clock.startFrame + clock.frames
		dirty, lastFrame = false, frame
		settled = not moving and clock.dayFrames == 0
		apply(frame)
	end

	-- gl.TextureInfo loads the texture, which SetSkyBoxTexture only looks up by name;
	-- a texture that does not load or is not a cubemap leaves the sky as it is
	function gadget:DrawGenesis()
		local texture = skybox.pending
		if texture == nil then
			return
		end
		skybox.pending = nil
		if texture ~= "" then
			local info = gl.TextureInfo(texture)
			if not info or info.target ~= GL.TEXTURE_CUBE_MAP then
				Spring.Log(gadget:GetInfo().name, LOG.WARNING, "Skybox missing or not a cubemap: " .. texture)
				return
			end
		end
		-- a new sky rereads fog, sun direction and sky colours from mapinfo
		local fogStart, fogEnd = glGetAtmosphere("fogStart"), glGetAtmosphere("fogEnd")
		Spring.SetSkyBoxTexture(texture)
		skybox.applied = texture ~= ""
		spSetAtmosphere({ fogStart = fogStart, fogEnd = fogEnd })
		if active then
			apply(lastFrame or spGetGameFrame(), true)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction(SYNCACTION, onSyncAction)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction(SYNCACTION)
		if active then
			restoreBase()
		end
	end
end
