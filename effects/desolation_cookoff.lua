local STANDARD_EXPLOSION = "genericshellexplosion-small"
local LARGE_EXPLOSION = "genericshellexplosion-medium"
local COOKOFF_DELAY_WINDOW = 30
local LARGE_EXPLOSION_FRACTION = 0.2

local SIZE_PROFILES = {
	tiny = { spreadRadius = 12, heightSpread = 10, popCount = 1 },
	small = { spreadRadius = 20, heightSpread = 14, popCount = 2 },
	medium = { spreadRadius = 32, heightSpread = 20, popCount = 3 },
	large = { spreadRadius = 48, heightSpread = 28, popCount = 4 },
	huge = { spreadRadius = 68, heightSpread = 36, popCount = 5 },
}

local function scatterPos(spreadRadius, heightSpread)
	return string.format("-%d r%d, 2 r%d, -%d r%d", spreadRadius, spreadRadius * 2, heightSpread, spreadRadius, spreadRadius * 2)
end

local function cookoffSpawner(popCount, spreadRadius, heightSpread, delaySpread, explosionName)
	return {
		air = true,
		class = [[CExpGenSpawner]],
		count = popCount,
		ground = true,
		underwater = true,
		water = true,
		properties = {
			delay = string.format("0 r%d", delaySpread),
			explosiongenerator = [[custom:]] .. explosionName,
			pos = scatterPos(spreadRadius, heightSpread),
		},
	}
end

local function cookoffSpawners(popCount, spreadRadius, heightSpread, delaySpread)
	local largeExplosionCount = math.floor(popCount * LARGE_EXPLOSION_FRACTION + 0.5)
	local standardExplosionCount = math.max(0, popCount - largeExplosionCount)
	local generators = {}

	if standardExplosionCount > 0 then
		generators.cookoff = cookoffSpawner(standardExplosionCount, spreadRadius, heightSpread, delaySpread, STANDARD_EXPLOSION)
	end
	if largeExplosionCount > 0 then
		generators.largeCookoff = cookoffSpawner(largeExplosionCount, spreadRadius, heightSpread, delaySpread, LARGE_EXPLOSION)
	end

	return generators
end

local effects = {}

for sizeName, profile in pairs(SIZE_PROFILES) do
	local generators = { usedefaultexplosions = false }
	local spawners = cookoffSpawners(profile.popCount, profile.spreadRadius, profile.heightSpread, COOKOFF_DELAY_WINDOW)

	for generatorName, generator in pairs(spawners) do
		generators[generatorName] = generator
	end

	effects["desolation_cookoff_" .. sizeName] = generators
end

return effects
