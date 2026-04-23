local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Weather Brush",
		desc = "Place weather effects and CEG-based atmospheric conditions on the map",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Localized Spring API
local SendLuaRulesMsg = Spring.SendLuaRulesMsg
local GetMouseState = Spring.GetMouseState
local GetGroundHeight = Spring.GetGroundHeight
local TraceScreenRay = Spring.TraceScreenRay
local GetGameFrame = Spring.GetGameFrame
local Echo = Spring.Echo

local CEG_HEADER = "$weather_ceg$"

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local GL_LINE_LOOP = GL.LINE_LOOP

local floor = math.floor
local max = math.max
local min = math.min
local cos = math.cos
local sin = math.sin
local pi = math.pi
local sqrt = math.sqrt
local random = math.random

local WG = WG

-- ===========================================================================
-- Constants
-- ===========================================================================
local CIRCLE_SEGMENTS = 48
local DEFAULT_RADIUS = 200
local MIN_RADIUS = 8
local MAX_RADIUS = 2000
local DEFAULT_COUNT = 3
local DEFAULT_CADENCE = 50
local DEFAULT_LENGTH_SCALE = 1.0
local MIN_LENGTH_SCALE = 0.2
local MAX_LENGTH_SCALE = 5.0
local UPDATE_INTERVAL = 1 / 30 -- frame timing

-- Persistence: 0 = one-shot, slider 1..3600 seconds, 3601 = permanent
local PERSIST_MAX_SECONDS = 3600
local PERSIST_PERMANENT = PERSIST_MAX_SECONDS + 1

-- ===========================================================================
-- CEG Library (loaded from effects/ directories)
-- ===========================================================================
local cegNames = {} -- sorted list of all discovered CEG names
local cegNameSet = {} -- quick lookup set

local function loadCEGNames()
	cegNames = {}
	cegNameSet = {}
	local dirs = { "effects", "effects/lootboxes", "effects/raptors", "effects/scavengers" }
	for _, dir in ipairs(dirs) do
		local files = VFS.DirList(dir, "*.lua")
		for _, filepath in ipairs(files) do
			local ok, defs = pcall(VFS.Include, filepath)
			if ok and type(defs) == "table" then
				for defName, _ in pairs(defs) do
					if not cegNameSet[defName] then
						cegNameSet[defName] = true
						cegNames[#cegNames + 1] = defName
					end
				end
			end
		end
	end
	table.sort(cegNames)
end

-- ===========================================================================
-- Weather Conditions Library (curated presets)
-- ===========================================================================
local weatherLibrary = {
	-- ===================================================================
	-- PRECIPITATION — multi-layer altitude: sky rain, mid-air haze, ground
	-- ===================================================================
	{
		name = "Light Rain",
		description = "Thin streaks of rain drifting from 1200m altitude to earth with soft directional fall",
		icon = "rain_light",
		-- raindrop CEG: particles spawn at y+1250, emit downward (emitrot=180),
		-- directional=true elongates them into rain streaks. 2 particles each.
		cegs = { "raindrop" },
		spawnCount = 10,
		radius = 500,
		cadence = 5,
		-- raindrop falls ~900-1400 elmo over its 34-124 frame life (speed 11).
		-- Lift so end-of-life particles fade near ground, not underground.
		altitude = 900,
		persistence = 600,
		cegLifetimeS = 4,   -- particlelife 34 + spread 90 = ~124 frames
	},
	{
		name = "Heavy Downpour",
		description = "Dense rain curtain from sky with mid-air haze and ground-level splashes — three altitude layers",
		icon = "rain_heavy",
		-- HIGH: raindrop falls from 1250 above ground
		-- MID: weather_drizzle_mist fills 50-200 band with translucent haze
		-- LOW: watersplash_small at ground for impact feel
		cegs = { "raindrop", "raindrop", "raindrop", "weather_drizzle_mist", "watersplash_small" },
		spawnCount = 12,
		radius = 600,
		cadence = 8,
		-- Compromise: rain wants ~900 but watersplash is a ground hit.
		-- 400 keeps rain mostly visible without floating splashes too high.
		altitude = 400,
		persistence = 600,
		cegLifetimeS = 7,
	},
	{
		name = "Thunderstorm",
		description = "Dark cloud ceiling, rain falling through, lightning arcing from sky to ground — full 3D storm",
		icon = "storm",
		-- HIGH: fogdirty as dark cloud ceiling (particles at y -50..+75, size 100-400)
		-- MID-HIGH: lightningstorm spawns 14 bolts over 36s at y+128, length 1700
		-- FALLING: raindrop from y+1250 downward
		cegs = { "raindrop", "raindrop", "raindrop", "raindrop", "lightningstorm", "fogdirty" },
		spawnCount = 8,
		radius = 800,
		cadence = 5,
		-- rain wants ~900, fogdirty wants ~60; 400 is the visible compromise.
		altitude = 400,
		persistence = 300,
		cegLifetimeS = 26,  -- fogdirty dominates: 520+260 frames
	},
	{
		name = "Acid Rain",
		description = "Sickly green-tinted rain with toxic ground-level fog — two altitude bands of dread",
		icon = "rain_acid",
		-- FALLING: raindrop-acid green-tinted streaks from 1250
		-- LOW: fogdirty-green at ground for poisonous atmosphere
		cegs = { "raindrop-acid", "raindrop-acid", "raindrop-acid", "fogdirty-green" },
		spawnCount = 8,
		radius = 500,
		cadence = 5,
		-- rain wants ~900, fogdirty-green wants ~60; split the difference.
		altitude = 400,
		persistence = 600,
		cegLifetimeS = 26,
	},
	{
		name = "Snowfall",
		description = "Soft white flakes drifting from 300-600m altitude, wobbling on gentle air currents",
		icon = "snow_light",
		-- weather_snowflake: cloudpuff particles at 300-600 above ground,
		-- airdrag 0.97 bleeds speed, gravity -0.06 pulls down with lateral wobble
		cegs = { "weather_snowflake" },
		spawnCount = 12,
		radius = 500,
		cadence = 5,
		-- weather_snowflake pos y already at 300-600; fall ~440 fits above ground.
		altitude = 0,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 7,   -- particlelife 90 + spread 130 = ~220 frames
	},
	{
		name = "Blizzard",
		description = "Dense snowfall from 250-600m, wind-blown drifts at mid-level, and whiteout cloud banks at ground",
		icon = "blizzard",
		-- HIGH: weather_snowfall_heavy drops dense flakes from 250-600
		-- MID: drift sub-layer of snowfall_heavy at 20-80 for blowing snow
		-- LOW: mistycloud ground-hugging cloud banks for whiteout
		cegs = { "weather_snowfall_heavy", "weather_snowfall_heavy", "mistycloud" },
		spawnCount = 8,
		radius = 700,
		cadence = 5,
		-- main flakes pos y 250-600, drift 20-80; mistycloud -20..+130.
		altitude = 20,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 27,  -- mistycloud: 300+500 frames
	},
	{
		name = "Hailstorm",
		description = "Bright white streaks plummeting from 400-600m altitude with ground-impact splashes",
		icon = "hail",
		-- HIGH: weather_hailstone fast directional particles from 400-600,
		-- gravity -0.35 accelerates them, no airdrag, streak downward
		-- LOW: watersplash_extrasmall for ground-hit bursts
		cegs = { "weather_hailstone", "weather_hailstone", "watersplash_extrasmall" },
		spawnCount = 10,
		radius = 400,
		cadence = 8,
		-- hail pos y 400-600, gravity -0.35 accelerates to ~1100 fall over life.
		-- Lift so streaks stay visible; splash also reads OK slightly raised.
		altitude = 600,
		persistence = 300,
		cegLifetimeS = 2,   -- particlelife 22 + spread 30 = ~52 frames
	},
	-- ===================================================================
	-- WIND & SAND — lateral movement + overhead sand cloud layers
	-- ===================================================================
	{
		name = "Sandstorm",
		description = "Horizontal sand blasts at ground level under dense overhead sand cloud at 125m altitude",
		icon = "sandstorm",
		-- HIGH: sandclouddense spawns 75 sanddust sub-CEGs at y+125, big particles
		-- LOW: sandblast lateral streams with gravity x:0.5 = horizontal movement
		cegs = { "sandblast", "sandblast", "sandclouddense" },
		spawnCount = 6,
		radius = 600,
		cadence = 3,
		-- sandblast is horizontal ground-level; sandclouddense overhead at ~125.
		altitude = 0,
		persistence = 600,
		cegLifetimeS = 15,  -- sandclouddense: 190+250 frames
	},
	{
		name = "Dust Devil",
		description = "Concentrated swirling column of dust, debris, and dune clouds rising from a tight area",
		icon = "dust_devil",
		-- dunecloud: 5 dunedust spawners spread radially, barmist texture
		-- dunedust: upward emission (emitvector=[0,-1,0]) with wide rotspread = swirl
		-- dust_cloud: ground-level debris puffs
		cegs = { "dunecloud", "dust_cloud", "dunedust" },
		spawnCount = 5,
		radius = 120,
		cadence = 3,
		altitude = 0,
		persistence = 300,
		cegLifetimeS = 8,   -- dunedust: 120+120 frames
	},
	-- ===================================================================
	-- FOG & ATMOSPHERE — ground-hugging to mid-altitude
	-- ===================================================================
	{
		name = "Ground Fog",
		description = "Dense swirling fog banks at ground level using dirty fog texture — slow drift, massive particles",
		icon = "fog",
		-- fogdirty: pos y:-50..+75, size 100-400, life 520+260 frames,
		-- airdrag 0.94, rotating slowly, fogdirty texture for gritty look
		cegs = { "fogdirty" },
		spawnCount = 3,
		radius = 600,
		cadence = 2,
		-- fogdirty pos y -50..+25; lift so the low end is at ground.
		altitude = 60,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 26,
	},
	{
		name = "Morning Mist",
		description = "Translucent cloudpuff sheets lingering near the ground — ethereal and soft with gentle rotation",
		icon = "mist",
		-- mistycloud: cloudpuff 240-1200 size, pos y:-20..+130,
		-- life 300+500 frames, very slow drift, almost stationary billows
		cegs = { "mistycloud" },
		spawnCount = 2,
		radius = 500,
		cadence = 2,
		-- mistycloud pos y -20..+130; lift 30 so low end sits on ground.
		altitude = 30,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 27,
	},
	{
		name = "Overcast Sky",
		description = "Enormous grey cloud layer 300m above the battlefield — blocks out the sky with slow lateral drift",
		icon = "overcast",
		-- thickcloud: cloudpuff 1240-3820 elmo particles!, pos y:-20..+130,
		-- spawned with altitude offset 300 to push overhead
		-- life 500+400 frames, extremely slow drift
		cegs = { "thickcloud" },
		spawnCount = 2,
		radius = 800,
		cadence = 1,
		altitude = 300,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 30,
	},
	{
		name = "Toxic Haze",
		description = "Ominous green-tinted fog creeping at ground level — faint sickly glow of contamination",
		icon = "toxic",
		-- fogdirty-green: same mechanics as fogdirty but green colormap
		cegs = { "fogdirty-green" },
		spawnCount = 3,
		radius = 500,
		cadence = 2,
		-- same geometry as fogdirty.
		altitude = 60,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 26,
	},
	{
		name = "Purple Mist",
		description = "Dense banks of supernatural purple haze using barmist texture — wide, slow, otherworldly",
		icon = "mist_purple",
		-- mistycloudpurplemistxl: CBitmapMuzzleFlame with barmist texture,
		-- size 550-840, ttl 550 frames, purple colormap, ground-hugging
		cegs = { "mistycloudpurplemistxl" },
		spawnCount = 3,
		radius = 500,
		cadence = 2,
		-- mistycloudpurplemistxl pos y -5..+30; tiny lift keeps it clear of terrain.
		altitude = 10,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 18,
	},
	-- ===================================================================
	-- FIRE & VOLCANIC — ground fire + rising smoke/ash at altitude
	-- ===================================================================
	{
		name = "Volcanic Ash",
		description = "Dark ash descending from 200-500m while black smoke plumes rise from below — opposite altitude flows",
		icon = "volcanic",
		-- DESCENDING: weather_ashfall dirtpuff particles falling from 200-500 above
		-- RISING: smokeblack dark smoke at ground rising upward (gravity y:+0.06)
		-- Two opposed altitude flows create dramatic layered depth
		cegs = { "weather_ashfall", "weather_ashfall", "smokeblack" },
		spawnCount = 5,
		radius = 500,
		cadence = 3,
		-- ashfall pos y 200-500 falls slow; smokeblack y -50..+25 rises. Keep low.
		altitude = 60,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 33,  -- smokeblack: 600+400 frames
	},
	{
		name = "Rising Embers",
		description = "Glowing orange sparks drifting upward from scorched earth with flickering ground fire below",
		icon = "embers",
		-- RISING: weather_embers — flare1 particles with positive Y gravity,
		-- colormap fades orange→red→dark ember→invisible
		-- LOW: fire-burnground-small persistent ground flame glow
		cegs = { "weather_embers", "weather_embers", "fire-burnground-small" },
		spawnCount = 8,
		radius = 300,
		cadence = 5,
		altitude = 0,
		persistence = 600,
		cegLifetimeS = 4,   -- embers: 45+85 frames
	},
	{
		name = "Lava Field",
		description = "Molten rock splashes with rings, sparks, and smoke trails over persistent ground fire",
		icon = "lava",
		-- lavasplash: complex multi-layer — ring, waves, upward rush,
		-- orange sparks, smoke trails, lava chunks
		-- fire-burnground: persistent ground flames
		cegs = { "lavasplash", "fire-burnground" },
		spawnCount = 3,
		radius = 300,
		cadence = 2,
		altitude = 0,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 8,
	},
	{
		name = "Steam Vents",
		description = "Columns of white steam rising from geothermal fissures — 80 puffs per vent expanding upward",
		icon = "steam",
		-- ventairburst: 80 ventair-puff sub-CEGs spawned over time,
		-- each puff rises (gravity y:+0.02..+0.09) and grows (sizegrowth 0.45)
		cegs = { "ventairburst" },
		spawnCount = 2,
		radius = 100,
		cadence = 2,
		altitude = 0,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 3,
	},
	-- ===================================================================
	-- AMBIENT & MAGICAL — low-altitude living atmosphere
	-- ===================================================================
	{
		name = "Fireflies",
		description = "Warm yellow-orange pinpricks pulsing just above the ground — 60 sub-sprites per spawn, 25s cycle",
		icon = "fireflies",
		-- fireflies: CExpGenSpawner with 60 firefly sub-CEGs over 750 frames,
		-- each at y:5-30 above ground, flare1 texture, beautiful 6-step colormap
		cegs = { "fireflies" },
		spawnCount = 2,
		radius = 300,
		cadence = 1,
		altitude = 0,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 25,
	},
	{
		name = "Green Fireflies",
		description = "Luminescent green motes drifting in the dark — alien bioluminescence",
		icon = "fireflies_green",
		cegs = { "firefliesgreen" },
		spawnCount = 2,
		radius = 300,
		cadence = 1,
		altitude = 0,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 25,
	},
	{
		name = "Purple Fireflies",
		description = "Violet specks of light floating mysteriously — twilight or magical atmosphere",
		icon = "fireflies_purple",
		cegs = { "firefliespurple" },
		spawnCount = 2,
		radius = 300,
		cadence = 1,
		altitude = 0,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 25,
	},
	{
		name = "Pollen Drift",
		description = "Tiny yellow-green specks and dust motes floating on warm thermals at 5-45m above ground",
		icon = "pollen",
		-- weather_pollen: flare1 specks with random 3D emission + slight updraft,
		-- dustparticle: gray motes at 25-175m for background depth
		cegs = { "weather_pollen", "dustparticle" },
		spawnCount = 6,
		radius = 400,
		cadence = 2,
		altitude = 0,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 10,
	},
	{
		name = "Floating Dust",
		description = "Sunlit grey motes suspended at 25-175m — 200 sub-particles drifting on invisible thermals",
		icon = "dust_motes",
		-- dustparticles: CExpGenSpawner, 200 dustparticle sub-CEGs over 750 frames,
		-- each a tiny gray flare1 at various altitudes with long life (100-300 frames)
		cegs = { "dustparticles" },
		spawnCount = 2,
		radius = 500,
		cadence = 1,
		altitude = 0,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 25,
	},
	-- ===================================================================
	-- STORM & ENERGY — lightning at altitude + ground effects
	-- ===================================================================
	{
		name = "Lightning Storm",
		description = "Ground-strike bolts with electricity spikes and flashes plus mid-air bolts at 128m",
		icon = "lightning",
		-- lightningstrike: bolt length 2500, ground flash, electric spikes, upward particles
		-- lightninginair: bolt at 128m altitude, length 1700, random rotation
		cegs = { "lightningstrike", "lightninginair" },
		spawnCount = 3,
		radius = 500,
		cadence = 3,
		altitude = 0,
		persistence = 300,
		cegLifetimeS = 1,
	},
	{
		name = "Green Lightning",
		description = "Alien energy bolts in vivid green arcing from sky to ground",
		icon = "lightning_green",
		cegs = { "lightningstrikegreen", "lightninginairgreen" },
		spawnCount = 3,
		radius = 500,
		cadence = 3,
		altitude = 0,
		persistence = 300,
		cegLifetimeS = 1,
	},
	-- ===================================================================
	-- SMOKE & INDUSTRIAL — rising columns + settling debris
	-- ===================================================================
	{
		name = "Smoke Plumes",
		description = "Thick dark columns rising hundreds of metres — fogdirty texture, gravity-driven updraft",
		icon = "smoke",
		-- smokeblack: directional particles, gravity y:+0.06 = upward,
		-- fogdirty texture, size 200-400, life 600+400 frames, rises high
		cegs = { "smokeblack" },
		spawnCount = 3,
		radius = 300,
		cadence = 2,
		-- smokeblack pos y -50..+25; lift to clear ground.
		altitude = 60,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 33,
	},
	{
		name = "Nuke Fallout",
		description = "Ash descending from above, contaminated smoke rising from below, ground debris — three altitude zones",
		icon = "nuke",
		-- DESCENDING: weather_ashfall dark particles from 200-500m
		-- RISING: smokeblack plumes going up
		-- GROUND: dust_cloud_dirt debris at surface level
		cegs = { "weather_ashfall", "smokeblack", "dust_cloud_dirt" },
		spawnCount = 5,
		radius = 600,
		cadence = 3,
		-- ashfall floats high on its own; smokeblack needs ~60 lift; ground debris OK.
		altitude = 60,
		persistence = PERSIST_PERMANENT,
		cegLifetimeS = 33,
	},
	-- ===================================================================
	-- SPECIAL
	-- ===================================================================
	{
		name = "Meteor Shower",
		description = "Glowing fire trails and smoke arcing through the atmosphere from 200m altitude",
		icon = "meteor",
		-- meteortrail: glow2 fireglow + trailing smoke,
		-- spawned at altitude offset for overhead arcing
		cegs = { "meteortrail" },
		spawnCount = 2,
		radius = 500,
		cadence = 2,
		altitude = 200,
		persistence = 120,
		cegLifetimeS = 3,
	},
}

-- ===========================================================================
-- State
-- ===========================================================================
local wb = {
	active = false,
	mode = "scatter",       -- "scatter", "point", "remove"
	shape = "circle",       -- "circle", "square", "hexagon", "octagon"
	radius = DEFAULT_RADIUS,
	lengthScale = DEFAULT_LENGTH_SCALE,
	rotation = 0,
	rotRandom = 0,          -- 0-100
	spawnCount = DEFAULT_COUNT,
	cadence = DEFAULT_CADENCE,  -- 1-1000 logarithmic placement speed
	frequency = 1.0,            -- spawn interval in seconds (0.1-60.0)
	distribution = "random",
	altitude = 0,            -- Y offset above ground for spawn point

	selectedCegs = {},       -- ordered list of selected CEG names
	selectedCegSet = {},     -- quick lookup

	-- Persistence settings
	persistenceSeconds = 0,  -- 0 = one-shot, PERSIST_PERMANENT = forever
	persistentMode = false,  -- derived from persistenceSeconds > 0
	cegLifetimeS = nil,      -- per-preset particle lifetime override (nil = use default)

	-- Drag state
	dragging = false,
	dragAction = nil,        -- "place" or "remove"
	lockedWorldX = 0,
	lockedWorldZ = 0,
	placeTimer = 0,

	-- Active persistent spawner tracking
	-- Each entry: { cegs={}, x=, z=, radius=, count=, interval=, expireFrame=nil/number, nextFrame=0 }
	persistentSpawners = {},
	nextSpawnerId = 1,
}

-- ===========================================================================
-- Utility functions
-- ===========================================================================
local function getWorldMousePosition()
	local mx, my = GetMouseState()
	local _, coords = TraceScreenRay(mx, my, true)
	if coords then
		return coords[1], coords[2], coords[3]
	end
	return nil, nil, nil
end

local function getCadenceInterval()
	-- cadence 1-1000 (logarithmic slider): interval inversely proportional to rate
	return max(0.03, 2.0 / wb.cadence)
end

local function isInsideShape(px, pz, cx, cz, radius, shape, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	local dx = px - cx
	local dz = pz - cz

	if shape == "circle" then
		-- Normalize into ellipse space: X uses radius, Z uses radius * lengthScale
		local angleRad = -angleDeg * pi / 180
		local rx = dx * cos(angleRad) - dz * sin(angleRad)
		local rz = dx * sin(angleRad) + dz * cos(angleRad)
		local radiusZ = radius * lengthScale
		return (rx * rx) / (radius * radius) + (rz * rz) / (radiusZ * radiusZ) <= 1
	end

	-- Rotate point into shape-local coordinates
	local angleRad = -angleDeg * pi / 180
	local rx = dx * cos(angleRad) - dz * sin(angleRad)
	local rz = dx * sin(angleRad) + dz * cos(angleRad)
	local radiusZ = radius * lengthScale

	if shape == "square" then
		return math.abs(rx) <= radius and math.abs(rz) <= radiusZ
	elseif shape == "hexagon" then
		local ax = math.abs(rx)
		local az = math.abs(rz) / lengthScale
		return az <= radius and ax <= radius * 0.866 and (ax + az * 0.577) <= radius * 0.866
	elseif shape == "octagon" then
		local ax = math.abs(rx)
		local az = math.abs(rz) / lengthScale
		local cut = radius * 0.4142
		return ax <= radius and az <= radius and (ax + az) <= (radius + cut)
	end
	local dist = sqrt(dx * dx + dz * dz)
	return dist <= radius
end

local function getRandomPositionInShape(cx, cz, radius, shape, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	local radiusZ = radius * lengthScale
	local extentMax = max(radius, radiusZ)
	-- Simple rejection sampling
	for _ = 1, 100 do
		local rx = cx + (random() * 2 - 1) * extentMax
		local rz = cz + (random() * 2 - 1) * extentMax
		if isInsideShape(rx, rz, cx, cz, radius, shape, angleDeg, lengthScale) then
			return rx, rz
		end
	end
	return cx, cz
end

-- ===========================================================================
-- CEG Spawning (routed through gadget via SendLuaRulesMsg)
-- ===========================================================================
local function sendCegBatch(entries)
	if #entries == 0 then return end
	SendLuaRulesMsg(CEG_HEADER .. table.concat(entries, "|"))
end

local function spawnCegAtPosition(cegName, x, z, altitude)
	sendCegBatch({ cegName .. " " .. floor(x) .. " " .. floor(z) .. " " .. floor(altitude or 0) })
end

local function spawnWeatherAtArea(cegs, cx, cz, radius, count, shape, angleDeg, lengthScale, altitude)
	if not cegs or #cegs == 0 then return end
	local altStr = " " .. floor(altitude or 0)
	local batch = {}
	for i = 1, count do
		local px, pz = getRandomPositionInShape(cx, cz, radius, shape, angleDeg, lengthScale)
		local cegName = cegs[(i - 1) % #cegs + 1]
		batch[#batch + 1] = cegName .. " " .. floor(px) .. " " .. floor(pz) .. altStr
	end
	sendCegBatch(batch)
end

local function spawnSingleCeg(cegs, x, z, altitude)
	if not cegs or #cegs == 0 then return end
	local altStr = " " .. floor(altitude or 0)
	local batch = {}
	for _, cegName in ipairs(cegs) do
		batch[#batch + 1] = cegName .. " " .. floor(x) .. " " .. floor(z) .. altStr
	end
	sendCegBatch(batch)
end

-- ===========================================================================
-- Persistent Spawner System
-- ===========================================================================
-- Fade constants: ramp spawn count over the first/last portion of lifetime
local FADE_IN_SECONDS  = 5   -- seconds to ramp from 1 to full count
local FADE_OUT_SECONDS = 8   -- seconds to ramp from full count down to 0

-- Saturation: once enough cycles have run to reach steady-state particle
-- density, stop continuous spawning and switch to periodic refresh bursts
-- that fire once per particle lifetime so the area stays filled without
-- piling up additional particles on top of the existing ones.
local ESTIMATED_PARTICLE_LIFETIME_S = 10  -- conservative CEG lifetime guess

local function addPersistentSpawner(cegs, cx, cz, radius, count, shape, angleDeg, durationSeconds, cegLifetimeS)
	local frameRate = 30
	local startFrame = GetGameFrame()
	local expireFrame = nil
	if durationSeconds and durationSeconds ~= PERSIST_PERMANENT then
		expireFrame = startFrame + durationSeconds * frameRate
	end

	-- Respawn interval based on cadence
	local interval = max(1, floor(getCadenceInterval() * frameRate))

	local id = wb.nextSpawnerId
	wb.nextSpawnerId = wb.nextSpawnerId + 1

	-- How many cycles until the area is visually "full"
	local lifetimeS = cegLifetimeS or ESTIMATED_PARTICLE_LIFETIME_S
	local saturationCycles = max(1, floor(lifetimeS * frameRate / interval))
	-- After saturation, one refresh burst per particle lifetime
	local refreshInterval = max(interval, floor(lifetimeS * frameRate))

	wb.persistentSpawners[id] = {
		cegs = cegs,
		x = cx,
		z = cz,
		radius = radius,
		count = count,
		shape = shape or "circle",
		angleDeg = angleDeg or 0,
		lengthScale = wb.lengthScale or 1.0,
		altitude = wb.altitude or 0,
		interval = interval,
		refreshInterval = refreshInterval,
		startFrame = startFrame,
		expireFrame = expireFrame, -- nil = permanent
		nextFrame = startFrame,
		spawnCycles = 0,
		saturationCycles = saturationCycles,
	}
	return id
end

local function removePersistentSpawnersInArea(cx, cz, radius, shape, angleDeg, lengthScale)
	local toRemove = {}
	for id, spawner in pairs(wb.persistentSpawners) do
		if isInsideShape(spawner.x, spawner.z, cx, cz, radius, shape, angleDeg, lengthScale) then
			toRemove[#toRemove + 1] = id
		end
	end
	for _, id in ipairs(toRemove) do
		wb.persistentSpawners[id] = nil
	end
	return #toRemove
end

local function updatePersistentSpawners()
	local frame = GetGameFrame()
	local frameRate = 30
	local expired = {}
	for id, spawner in pairs(wb.persistentSpawners) do
		-- Check expiry (with fade-out grace period already baked into count)
		if spawner.expireFrame and frame >= spawner.expireFrame then
			expired[#expired + 1] = id
		elseif frame >= spawner.nextFrame then
			-- Calculate effective count with fade-in / fade-out
			local effectiveCount = spawner.count
			local elapsed = frame - spawner.startFrame

			-- Fade in: ramp from 1 to full over FADE_IN_SECONDS
			local fadeInFrames = FADE_IN_SECONDS * frameRate
			if elapsed < fadeInFrames then
				local t = elapsed / fadeInFrames
				effectiveCount = max(1, floor(spawner.count * t + 0.5))
			end

			-- Fade out: ramp from full to 0 over FADE_OUT_SECONDS before expiry
			if spawner.expireFrame then
				local remaining = spawner.expireFrame - frame
				local fadeOutFrames = FADE_OUT_SECONDS * frameRate
				if remaining < fadeOutFrames then
					local t = remaining / fadeOutFrames
					effectiveCount = max(0, floor(spawner.count * t + 0.5))
				end
			end

			-- Saturation: once enough cycles have run to fill the area,
			-- stop continuous spawning and switch to periodic refresh
			-- bursts — one full burst per particle lifetime keeps the
			-- density roughly constant without additive buildup.
			local isSaturated = spawner.spawnCycles >= spawner.saturationCycles

			if effectiveCount > 0 then
				spawnWeatherAtArea(spawner.cegs, spawner.x, spawner.z, spawner.radius, effectiveCount, spawner.shape, spawner.angleDeg, spawner.lengthScale, spawner.altitude)
				spawner.spawnCycles = spawner.spawnCycles + 1
			end

			if isSaturated then
				-- Jump ahead by a full particle lifetime before the next burst
				spawner.nextFrame = frame + spawner.refreshInterval
			else
				spawner.nextFrame = frame + spawner.interval
			end
		end
	end
	for _, id in ipairs(expired) do
		wb.persistentSpawners[id] = nil
	end
end

-- ===========================================================================
-- Placement Actions
-- ===========================================================================
local function doScatterPlace(cx, cz)
	if #wb.selectedCegs == 0 then return end

	spawnWeatherAtArea(wb.selectedCegs, cx, cz, wb.radius, wb.spawnCount, wb.shape, wb.rotation, wb.lengthScale, wb.altitude)

	-- Only create ONE persistent spawner per drag (not per tick)
	if wb.persistentMode and wb.persistenceSeconds > 0 and not wb.dragSpawnerCreated then
		addPersistentSpawner(wb.selectedCegs, cx, cz, wb.radius, wb.spawnCount, wb.shape, wb.rotation, wb.persistenceSeconds, wb.cegLifetimeS)
		wb.dragSpawnerCreated = true
	end
end

local function doPointPlace(cx, cz)
	if #wb.selectedCegs == 0 then return end

	spawnSingleCeg(wb.selectedCegs, cx, cz, wb.altitude)

	-- Only create ONE persistent spawner per drag (not per tick)
	if wb.persistentMode and wb.persistenceSeconds > 0 and not wb.dragSpawnerCreated then
		addPersistentSpawner(wb.selectedCegs, cx, cz, 10, 1, "circle", 0, wb.persistenceSeconds, wb.cegLifetimeS)
		wb.dragSpawnerCreated = true
	end
end

local function doRemove(cx, cz)
	local count = removePersistentSpawnersInArea(cx, cz, wb.radius, wb.shape, wb.rotation, wb.lengthScale)
	if count > 0 then
		Echo("[Weather Brush] Removed " .. count .. " persistent effect(s)")
	end
end

-- Apply TerraformBrush grid-snap + symmetric fan-out to a placement call.
local function placeSymmetric(fn, cx, cz)
	local tb = WG.TerraformBrush
	local rot = wb.rotation or 0
	if tb and tb.getState then
		local st = tb.getState()
		if st.angleSnap then rot = st.rotationDeg or rot end
		if st.gridSnap and tb.snapWorld then
			cx, cz = tb.snapWorld(cx, cz, rot)
		end
		if st.symmetryActive and tb.getSymmetricPositions then
			local positions = tb.getSymmetricPositions(cx, cz, rot)
			if positions and #positions > 0 then
				for _, p in ipairs(positions) do fn(p.x, p.z) end
				return
			end
		end
	end
	fn(cx, cz)
end

-- ===========================================================================
-- Mode Management
-- ===========================================================================
local function activate(mode)
	wb.active = true
	wb.mode = mode or "scatter"
	-- Deactivate terraform brush and feature placer
	if WG.TerraformBrush then WG.TerraformBrush.deactivate() end
	if WG.FeaturePlacer then WG.FeaturePlacer.deactivate() end
end

local function deactivate()
	wb.active = false
	wb.dragging = false
	wb.dragAction = nil
end

local function setMode(mode)
	if mode == "scatter" or mode == "point" or mode == "remove" then
		wb.mode = mode
	end
end

-- ===========================================================================
-- Parameter Setters
-- ===========================================================================
local function setShape(shape)
	if shape == "circle" or shape == "square" or shape == "hexagon" or shape == "octagon" then
		wb.shape = shape
	end
end

local function setRadius(val)
	wb.radius = max(MIN_RADIUS, min(MAX_RADIUS, floor(val)))
end

local function setLengthScale(val)
	wb.lengthScale = max(MIN_LENGTH_SCALE, min(MAX_LENGTH_SCALE, math.floor(val * 10 + 0.5) / 10))
end

local function setRotation(val)
	wb.rotation = val % 360
end

local function rotate(delta)
	setRotation(wb.rotation + delta)
end

local function setRotRandom(val)
	wb.rotRandom = max(0, min(100, floor(val)))
end

local function setSpawnCount(val)
	wb.spawnCount = max(1, min(500, floor(val)))
end

local function setCadence(val)
	wb.cadence = max(1, min(1000, floor(val)))
end

local function setAltitude(val)
	wb.altitude = max(0, min(2000, floor(val)))
end

local function setFrequency(val)
	wb.frequency = max(0.1, min(60.0, val))
end

local function setDistribution(dist)
	if dist == "random" or dist == "regular" then
		wb.distribution = dist
	end
end

local function setPersistenceSeconds(val)
	val = max(0, min(PERSIST_PERMANENT, floor(val)))
	wb.persistenceSeconds = val
	wb.persistentMode = val > 0
end

-- CEG selection
local function selectCeg(name)
	if not cegNameSet[name] then return end
	wb.selectedCegs = { name }
	wb.selectedCegSet = { [name] = true }
end

local function toggleCeg(name)
	if not cegNameSet[name] then return end
	if wb.selectedCegSet[name] then
		wb.selectedCegSet[name] = nil
		local newList = {}
		for _, v in ipairs(wb.selectedCegs) do
			if v ~= name then newList[#newList + 1] = v end
		end
		wb.selectedCegs = newList
	else
		wb.selectedCegSet[name] = true
		wb.selectedCegs[#wb.selectedCegs + 1] = name
	end
end

local function clearSelectedCegs()
	wb.selectedCegs = {}
	wb.selectedCegSet = {}
end

local function applyWeatherPreset(index)
	local preset = weatherLibrary[index]
	if not preset then return end

	wb.selectedCegs = {}
	wb.selectedCegSet = {}
	for _, cegName in ipairs(preset.cegs) do
		-- Accept CEG even if not in cegNameSet (library items are curated)
		wb.selectedCegs[#wb.selectedCegs + 1] = cegName
		wb.selectedCegSet[cegName] = true
	end
	wb.spawnCount = preset.spawnCount or DEFAULT_COUNT
	wb.radius = preset.radius or DEFAULT_RADIUS
	wb.cegLifetimeS = preset.cegLifetimeS or nil
	wb.altitude = preset.altitude or 0
	if preset.cadence then
		wb.cadence = preset.cadence
	end
	setPersistenceSeconds(preset.persistence or 0)
end

local function clearAllPersistent()
	local count = 0
	for _ in pairs(wb.persistentSpawners) do count = count + 1 end
	wb.persistentSpawners = {}
	wb.nextSpawnerId = 1
	if count > 0 then
		Echo("[Weather Brush] Cleared " .. count .. " persistent effect(s)")
	end
end

-- ===========================================================================
-- State Export (for UI)
-- ===========================================================================
local function getState()
	return {
		active = wb.active,
		mode = wb.mode,
		shape = wb.shape,
		radius = wb.radius,
		lengthScale = wb.lengthScale,
		rotation = wb.rotation,
		rotRandom = wb.rotRandom,
		spawnCount = wb.spawnCount,
		cadence = wb.cadence,
		frequency = wb.frequency,
		distribution = wb.distribution,
		altitude = wb.altitude,
		selectedCegs = wb.selectedCegs,
		persistenceSeconds = wb.persistenceSeconds,
		persistentMode = wb.persistentMode,
		persistentCount = 0, -- calculated below
	}
end

local function getStateWithCount()
	local state = getState()
	local count = 0
	for _ in pairs(wb.persistentSpawners) do count = count + 1 end
	state.persistentCount = count
	return state
end

local function getCegNames()
	return cegNames
end

local function getWeatherLibrary()
	return weatherLibrary
end

-- ===========================================================================
-- Drawing (Brush Outline in World)
-- ===========================================================================
local function rotatePoint(x, z, angleDeg)
	local rad = angleDeg * pi / 180
	local c, s = cos(rad), sin(rad)
	return x * c - z * s, x * s + z * c
end

local function drawRegularPolygon(cx, cy, cz, radius, sides, lengthScale)
	lengthScale = lengthScale or 1.0
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 0, sides - 1 do
			local angle = (2 * pi * i) / sides
			glVertex(cx + radius * cos(angle), cy, cz + radius * lengthScale * sin(angle))
		end
	end)
end

local function drawRotatedSquare(cx, cy, cz, radius, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	local radiusZ = radius * lengthScale
	glBeginEnd(GL_LINE_LOOP, function()
		local corners = {
			{ -radius, -radiusZ },
			{  radius, -radiusZ },
			{  radius,  radiusZ },
			{ -radius,  radiusZ },
		}
		for _, corner in ipairs(corners) do
			local rx, rz = rotatePoint(corner[1], corner[2], angleDeg)
			glVertex(cx + rx, cy, cz + rz)
		end
	end)
end

-- ===========================================================================
-- Input Handling
-- ===========================================================================
function widget:KeyPress(key, mods, isRepeat)
	if not wb.active then return false end

	-- Escape to deactivate
	if key == 27 then -- ESCAPE
		deactivate()
		return true
	end

	return false
end

function widget:IsAbove(x, y)
	return false
end

function widget:MousePress(mx, my, button)
	if not wb.active then return false end
	if button ~= 1 and button ~= 3 then return false end

	-- Defer to measure tool when active
	do
		local tb = WG.TerraformBrush
		local st = tb and tb.getState and tb.getState() or nil
		if st and st.measureActive then return false end
	end

	local wx, wy, wz = getWorldMousePosition()
	if not wx then return false end

	wb.dragging = true
	wb.lockedWorldX = wx
	wb.lockedWorldZ = wz
	wb.placeTimer = 0
	wb.dragSpawnerCreated = false

	if button == 3 then
		wb.dragAction = "remove"
		placeSymmetric(doRemove, wx, wz)
	elseif wb.mode == "scatter" then
		wb.dragAction = "place"
		placeSymmetric(doScatterPlace, wx, wz)
	elseif wb.mode == "point" then
		wb.dragAction = "place"
		placeSymmetric(doPointPlace, wx, wz)
	elseif wb.mode == "remove" then
		wb.dragAction = "remove"
		placeSymmetric(doRemove, wx, wz)
	end

	return true
end

function widget:MouseRelease(mx, my, button)
	if wb.dragging then
		wb.dragging = false
		wb.dragAction = nil
	end
end

function widget:MouseWheel(up, value)
	if not wb.active then return false end

	local alt, ctrl, meta, shift = Spring.GetModKeyState()

	if ctrl and alt then
		local delta = up and 0.1 or -0.1
		setLengthScale(wb.lengthScale + delta)
		return true
	end

	if alt then
		-- Alt+Scroll: rotate brush (snap to TB protractor step when angleSnap on)
		local step = 15
		local tb = WG.TerraformBrush
		local tbs = tb and tb.getState and tb.getState() or nil
		if tbs and tbs.angleSnap and (tbs.angleSnapStep or 0) > 0 then
			step = tbs.angleSnapStep
		end
		local newRot = (((wb.rotation or 0) + (up and step or -step)) % 360 + 360) % 360
		wb.rotation = newRot
		if tbs and tbs.angleSnap and tb and tb.setRotation then
			tb.setRotation(newRot)
		end
		return true
	end

	if ctrl then
		local delta = up and (8 * 4) or (-8 * 4)
		setRadius(wb.radius + delta)
		return true
	end

	return false
end

-- ===========================================================================
-- Update loop
-- ===========================================================================
local lastDt = 0

function widget:Update(dt)
	-- Update persistent spawners regardless of active state
	updatePersistentSpawners()

	if not wb.active then return end
	if not wb.dragging then return end

	lastDt = lastDt + dt
	if lastDt < getCadenceInterval() then return end
	lastDt = 0

	local lmb, _, rmb = GetMouseState()
	if not lmb and not rmb then
		wb.dragging = false
		wb.dragAction = nil
		return
	end

	local wx, _, wz = getWorldMousePosition()
	if not wx then return end

	wb.lockedWorldX = wx
	wb.lockedWorldZ = wz

	if wb.dragAction == "remove" then
		placeSymmetric(doRemove, wx, wz)
	elseif wb.mode == "scatter" then
		placeSymmetric(doScatterPlace, wx, wz)
	elseif wb.mode == "point" then
		placeSymmetric(doPointPlace, wx, wz)
	end
end

-- ===========================================================================
-- Drawing (World)
-- ===========================================================================
function widget:DrawWorld()
	if not wb.active then return end

	local wx, wy, wz = getWorldMousePosition()
	do
		local tb = WG.TerraformBrush
		if tb and tb.animateUnmouse then
			wx, wz = tb.animateUnmouse("weatherBrush", wx, wz, wb.radius, wb.lengthScale or 1.0)
			if wx then wy = (GetGroundHeight(wx, wz) or 0) + 4 end
		elseif tb and tb.getUnmouseTarget and not wx then
			wx, wz = tb.getUnmouseTarget(wb.radius, wb.lengthScale or 1.0)
			if wx then wy = (GetGroundHeight(wx, wz) or 0) + 4 end
		end
	end
	if not wx then return end

	local groundY = (GetGroundHeight(wx, wz) or 0) + 4

	if wb.mode == "remove" or wb.dragAction == "remove" then
		glColor(1, 0.3, 0.3, 0.8)
	elseif wb.mode == "scatter" then
		glColor(0.3, 0.8, 1, 0.8)
	elseif wb.mode == "point" then
		glColor(0.5, 0.5, 1, 0.8)
	end

	glLineWidth(2)

	if wb.mode == "point" and wb.dragAction ~= "remove" then
		-- Crosshair for point mode
		local s = 20
		glBeginEnd(GL.LINES, function()
			glVertex(wx - s, groundY, wz)
			glVertex(wx + s, groundY, wz)
			glVertex(wx, groundY, wz - s)
			glVertex(wx, groundY, wz + s)
		end)
	else
		-- Area brush outline
		if wb.shape == "circle" then
			drawRegularPolygon(wx, groundY, wz, wb.radius, CIRCLE_SEGMENTS, wb.lengthScale)
		elseif wb.shape == "square" then
			drawRotatedSquare(wx, groundY, wz, wb.radius, wb.rotation, wb.lengthScale)
		elseif wb.shape == "hexagon" then
			drawRotatedSquare(wx, groundY, wz, wb.radius, wb.rotation, wb.lengthScale) -- simplified
			drawRegularPolygon(wx, groundY, wz, wb.radius, 6, wb.lengthScale)
		elseif wb.shape == "octagon" then
			drawRegularPolygon(wx, groundY, wz, wb.radius, 8, wb.lengthScale)
		end
	end

	-- Draw persistent spawner markers
	glColor(0.2, 0.9, 0.9, 0.4)
	glLineWidth(1)
	for _, spawner in pairs(wb.persistentSpawners) do
		local sy = (GetGroundHeight(spawner.x, spawner.z) or 0) + 4
		drawRegularPolygon(spawner.x, sy, spawner.z, min(spawner.radius, 60), 12)
	end

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

-- ===========================================================================
-- Initialize / Shutdown
-- ===========================================================================
function widget:Initialize()
	loadCEGNames()

	-- Register slash commands
	widgetHandler:AddAction("weatherbrush", function(_, _, args)
		local mode = args and args[1]
		if mode == "off" then
			deactivate()
		else
			activate(mode or "scatter")
		end
	end, nil, "t")

	widgetHandler:AddAction("weatherbrushscatter", function()
		activate("scatter")
	end, nil, "t")

	widgetHandler:AddAction("weatherbrushpoint", function()
		activate("point")
	end, nil, "t")

	widgetHandler:AddAction("weatherbrushremove", function()
		activate("remove")
	end, nil, "t")

	widgetHandler:AddAction("weatherbrushoff",
		deactivate, nil, "t")

	-- Expose API for the RmlUI controller
	WG.WeatherBrush = {
		activate = activate,
		deactivate = deactivate,
		setMode = setMode,
		getState = getStateWithCount,
		setShape = setShape,
		setRadius = setRadius,
		setLengthScale = setLengthScale,
		setRotation = setRotation,
		rotate = rotate,
		setRotRandom = setRotRandom,
		setSpawnCount = setSpawnCount,
		setCadence = setCadence,
		setAltitude = setAltitude,
		setFrequency = setFrequency,
		setDistribution = setDistribution,
		setPersistenceSeconds = setPersistenceSeconds,
		selectCeg = selectCeg,
		toggleCeg = toggleCeg,
		clearSelectedCegs = clearSelectedCegs,
		getCegNames = getCegNames,
		getWeatherLibrary = getWeatherLibrary,
		applyWeatherPreset = applyWeatherPreset,
		clearAllPersistent = clearAllPersistent,
	}
end

function widget:Shutdown()
	WG.WeatherBrush = nil

	widgetHandler:RemoveAction("weatherbrush")
	widgetHandler:RemoveAction("weatherbrushscatter")
	widgetHandler:RemoveAction("weatherbrushpoint")
	widgetHandler:RemoveAction("weatherbrushremove")
	widgetHandler:RemoveAction("weatherbrushoff")
end
