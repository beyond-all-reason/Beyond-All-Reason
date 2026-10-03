local TRAIL_SCALE = 3

local SCALED_KEYS =
	{ "size", "sizegrowth", "particlesize", "particlesizespread", "length", "particlespeed", "particlespeedspread" }

local function scaleValue(value, factor)
	if type(value) == "number" then
		return value * factor
	end
	if type(value) == "string" and value:match("^[%d%.%sr%-]+$") then
		return (value:gsub("%d+%.?%d*", function(n)
			return tostring(tonumber(n) * factor)
		end))
	end
	return value
end

local function scaled(def, factor)
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

local BLAST_SCALE = 2
local BLAST_KEYS = { "particlesize", "particlespeed", "particlespeedspread", "size", "sizegrowth" }

local function scaledBlast(def, factor)
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

local cannons = VFS.Include("effects/cannons.lua")
local nukes = VFS.Include("effects/nukes.lua")

return {
	["scavbossrail-trail"] = scaled(cannons["railgun-epic"], TRAIL_SCALE),
	scavbossblast = scaledBlast(nukes.newnukehuge, BLAST_SCALE),
}
