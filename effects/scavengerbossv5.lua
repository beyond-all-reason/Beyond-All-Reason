local TRAIL_SCALE = 3

local SCALED_KEYS =
	{ "size", "sizegrowth", "particlesize", "particlesizespread", "length", "particlespeed", "particlespeedspread" }

local function scaleValue(value, factor)
	if type(value) == "number" then
		return value * factor
	end
	if type(value) == "string" and value:match("^[%d%.%sr%-]+$") then
		return (value:gsub("%d+%.?%d*", function(n)
			return tostring((tonumber(n) or 0) * factor)
		end))
	end
	return value
end

local function scaled(def, factor)
	---@type table
	local copy = table.copy(def)
	for _, emitter in pairs(copy) do
		local props = type(emitter) == "table" and emitter.properties
		if props then
			for _, key in ipairs(SCALED_KEYS) do
				if props[key] ~= nil then
					props[key] = scaleValue(props[key], factor)
				end
			end
			if props.ttl ~= nil then
				props.ttl = scaleValue(props.ttl, 1 + (factor - 1) * 0.5)
			end
		end
	end
	return copy
end

local BLAST_SCALE = 0.85
local BLAST_KEYS = { "particlesize", "particlespeed", "particlespeedspread", "size", "sizegrowth" }

local function scaledBlast(def, factor)
	---@type table
	local copy = table.copy(def)
	for _, emitter in pairs(copy) do
		local props = type(emitter) == "table" and emitter.properties
		if props then
			for _, key in ipairs(BLAST_KEYS) do
				if type(props[key]) == "number" then
					props[key] = props[key] * factor
				end
			end
			if type(props.ttl) == "number" then
				props.ttl = math.floor(props.ttl * (1 + (factor - 1) * 0.5))
			end
		end
	end
	return copy
end

local RAIL_FLASH = {
	brightflare = 0.35,
	brightflareslow = 0.6,
	brightflareslowair = 0.6,
	airflash_anim = 0.6,
	groundflash_white = 0.5,
	groundflash_large = 0.6,
}

local function dimmed(def, factors)
	---@type table
	local copy = table.copy(def)
	for name, factor in pairs(factors) do
		local props = copy[name] and copy[name].properties
		if props and type(props.size) == "number" then
			props.size = math.floor(props.size * factor)
		end
	end
	return copy
end

local cannons = VFS.Include("effects/cannons.lua")
local nukes = VFS.Include("effects/nukes.lua")
local shells = VFS.Include("effects/genericshellexplosion.lua")
local STREAM_HIT_SCALE, STREAM_TURBO_HIT_SCALE = 1.5, 2.25
local RAIN_HIT_SCALE = 1.5
local BLAST_LOOK_STEP = 10
local FIRE_ZONE_SIZE, FIRE_ZONE_SECONDS = 1330, 13.5
local FIRE_ZONE_GLOW = "0.6 0.15 1 0.3"
local FIRE_ZONE_PULSE_SECONDS, FIRE_ZONE_PULSE_START = 2, 0.05
local STAR_MARKS, STAR_MARK_SIZE, STAR_MARK_TAPER = 8, 80, 0.5

local effects = {
	["scavbossrail-trail"] = scaled(cannons["railgun-epic"], TRAIL_SCALE),
	scavbossrailhit = dimmed(nukes.newnukecor, RAIL_FLASH),
	scavbossstreamhit = scaledBlast(shells["genericshellexplosion-huge"], STREAM_HIT_SCALE),
	scavbossstreamhitturbo = scaledBlast(shells["genericshellexplosion-huge-bomb"], STREAM_TURBO_HIT_SCALE),
	scavbossrainhit = scaledBlast(shells["genericshellexplosion-large-bomb"], RAIN_HIT_SCALE),
}

for look = BLAST_LOOK_STEP, 100, BLAST_LOOK_STEP do
	local scale = BLAST_SCALE * look / 100
	local blast = scaledBlast(nukes.newnukehuge, scale)
	blast.nukefloor.properties.explosiongenerator = "custom:scavbossblastfloor" .. look
	effects["scavbossblast" .. look] = blast
	effects["scavbossblastfloor" .. look] = scaledBlast(nukes["newnukehuge-floor"], scale)
end

for i = 1, STAR_MARKS do
	effects["scavbossdgunmark" .. i] = {
		mark = {
			class = [[CSimpleGroundFlash]],
			count = 1,
			air = true,
			ground = true,
			water = true,
			properties = {
				alwaysvisible = true,
				colormap = [[0.8 0.3 1 0.8   0.8 0.3 1 0.6   0.8 0.3 1 0.01]],
				rotParams = [[0, 0, 0 d1]],
				size = STAR_MARK_SIZE * (1 - STAR_MARK_TAPER * (i - 1) / (STAR_MARKS - 1)),
				sizegrowth = 0,
				ttl = 24,
				texture = [[circlefx3]],
			},
		},
	}
end

local fireZoneColors = { "0.6 0.15 1 0.01" }
for _ = 1, FIRE_ZONE_SECONDS * 2 - 1 do
	fireZoneColors[#fireZoneColors + 1] = FIRE_ZONE_GLOW
end
fireZoneColors[#fireZoneColors + 1] = "0.6 0.15 1 0.01"

effects.scavbossfirezone = {
	zone = {
		class = [[CSimpleGroundFlash]],
		count = 1,
		air = true,
		ground = true,
		water = true,
		properties = {
			alwaysvisible = true,
			colormap = table.concat(fireZoneColors, "   "),
			rotParams = [[0, 0, 0 d1]],
			size = FIRE_ZONE_SIZE,
			sizegrowth = 0,
			ttl = FIRE_ZONE_SECONDS * 30,
			texture = [[scavbossfirezone]],
		},
	},
}

effects.scavbossfirezonepulse = {
	pulse = {
		class = [[CSimpleGroundFlash]],
		count = 1,
		air = true,
		ground = true,
		water = true,
		properties = {
			alwaysvisible = true,
			colormap = [[0.6 0.15 1 0.7   0.6 0.15 1 0.6   0.6 0.15 1 0.45   0.6 0.15 1 0.01]],
			rotParams = [[0, 0, 0 d1]],
			size = FIRE_ZONE_SIZE * FIRE_ZONE_PULSE_START,
			sizegrowth = FIRE_ZONE_SIZE * (1 - FIRE_ZONE_PULSE_START) / (FIRE_ZONE_PULSE_SECONDS * 30),
			ttl = FIRE_ZONE_PULSE_SECONDS * 30,
			texture = [[scavbossfirezone]],
		},
	},
}

return effects
