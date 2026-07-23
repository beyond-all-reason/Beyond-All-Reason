local COOKOFF_VOLUME_SCALE = 0.67

local SIZE_PROFILES = {
	tiny = { spreadRadius = 12, heightSpread = 10, popCount = 1 },
	small = { spreadRadius = 20, heightSpread = 14, popCount = 2 },
	medium = { spreadRadius = 32, heightSpread = 20, popCount = 3 },
	large = { spreadRadius = 48, heightSpread = 28, popCount = 4 },
	huge = { spreadRadius = 68, heightSpread = 36, popCount = 5 },
}

local SIZE_SCALES = {
	tiny = 8 / 46,
	small = 13 / 46,
	medium = 21 / 46,
	large = 32 / 46,
	huge = 1,
}

local ORANGE_ARC_COLORMAP = [[0 0 0 0.01   1 0.90 0.34 0.09   0.98 0.72 0.18 0.075   0.92 0.38 0.07 0.06   0.06 0.30 0.28 0.015   0 0 0 0.01]]
local ORANGE_GLOW_COLORMAP = [[0 0 0 0.01   1 0.72 0.28 0.06   0.98 0.56 0.11 0.07   0.52 0.24 0.08 0.03   0 0 0 0.01]]
local ORANGE_SPECULAR_COLORMAP = [[0 0 0 0.01   1 0.90 0.34 0.06   0.96 0.56 0.11 0.045   0.05 0.24 0.22 0.01   0 0 0 0.01]]
local TEAL_ARC_COLORMAP = [[0 0 0 0.01   0.35 0.92 0.84 0.07   0.14 0.70 0.64 0.09   0.06 0.40 0.38 0.06   0.02 0.14 0.13 0.02   0 0 0 0.01]]
local TEAL_GLOW_COLORMAP = [[0 0 0 0.01   0.30 0.82 0.72 0.04   0.14 0.60 0.54 0.06   0.05 0.26 0.24 0.03   0 0 0 0.01]]
local WISP_WARM_COLORMAP = [[0 0 0 0.01   1 0.82 0.42 0.08   1 0.66 0.24 0.09   0.70 0.36 0.12 0.06   0.20 0.09 0.03 0.02   0 0 0 0.01]]

local function scaledValue(value, scale)
	return math.max(1, math.floor(value * scale + 0.5))
end

local function scaledRange(base, spread, scale)
	return string.format("%d r%d", scaledValue(base, scale), scaledValue(spread, scale))
end

local function scatterPos(spreadRadius, heightSpread)
	return string.format("-%d r%d, 2 r%d, -%d r%d", spreadRadius, spreadRadius * 2, heightSpread, spreadRadius, spreadRadius * 2)
end

local function buildScaledHeapBurst(scale)
	local arcPos = scaledRange(19, 22, scale)
	local tealArcPos = scaledRange(25, 28, scale)
	local glowPos = scaledRange(16, 19, scale)
	local tealGlowPos = scaledRange(31, 34, scale)

	return {
		ribbonWarm = {
			air = true,
			class = [[CBitmapMuzzleFlame]],
			count = scaledValue(3, scale),
			ground = true,
			underwater = true,
			water = true,
			properties = {
				alwaysvisible = true,
				animParams = [[4,4,520 r240]],
				colormap = ORANGE_ARC_COLORMAP,
				dir = [[-1.0 r2.0, 0.05 r0.3, -1.0 r2.0]],
				drawOrder = 2,
				frontoffset = 0.1,
				fronttexture = [[none]],
				length = scaledRange(99, 88, scale),
				pos = arcPos,
				rotParams = [[-3 r6, -1 r3, -180 r360]],
				sidetexture = [[tenebrium_arcs]],
				size = scaledRange(10, 15, scale),
				sizegrowth = 0.375,
				ttl = scaledRange(16, 14, scale),
			},
		},
		ribbonTeal = {
			air = true,
			class = [[CBitmapMuzzleFlame]],
			count = math.max(1, scaledValue(1, scale)),
			ground = true,
			underwater = true,
			water = true,
			properties = {
				alwaysvisible = true,
				animParams = [[4,4,560 r260]],
				colormap = TEAL_ARC_COLORMAP,
				dir = [[-1.0 r2.0, 0.04 r0.2, -1.0 r2.0]],
				drawOrder = 1,
				frontoffset = 0.08,
				fronttexture = [[none]],
				length = scaledRange(143, 121, scale),
				pos = tealArcPos,
				rotParams = [[-3 r6, -2 r3, -180 r360]],
				sidetexture = [[tenebrium_arcs]],
				size = scaledRange(11, 16, scale),
				sizegrowth = 0.275,
				ttl = scaledRange(18, 16, scale),
			},
		},
		coreGlow = {
			air = true,
			class = [[CSimpleParticleSystem]],
			count = 1,
			ground = true,
			underwater = true,
			water = true,
			properties = {
				airdrag = 0.94,
				alwaysvisible = true,
				colormap = ORANGE_GLOW_COLORMAP,
				directional = false,
				drawOrder = 0,
				emitrot = 60,
				emitrotspread = 150,
				emitvector = [[1, 1, 1]],
				gravity = [[0, 0, 0]],
				numparticles = math.max(1, scaledValue(2, scale)),
				particlelife = scaledValue(18, scale),
				particlelifespread = scaledValue(10, scale),
				particlesize = scaledValue(52, scale),
				particlesizespread = scaledValue(38, scale),
				particlespeed = 0.05,
				particlespeedspread = 0.1,
				pos = glowPos,
				rotParams = [[-2 r4, -1 r2, -180 r360]],
				sizegrowth = 0.5625,
				sizemod = 0.97,
				texture = [[tenebrium_glow]],
			},
		},
		tealGlow = {
			air = true,
			class = [[CSimpleParticleSystem]],
			count = 1,
			ground = true,
			underwater = true,
			water = true,
			properties = {
				airdrag = 0.97,
				alwaysvisible = true,
				colormap = TEAL_GLOW_COLORMAP,
				directional = false,
				drawOrder = 0,
				emitrot = 60,
				emitrotspread = 150,
				emitvector = [[1, 1, 1]],
				gravity = [[0, 0, 0]],
				numparticles = 1,
				particlelife = scaledValue(16, scale),
				particlelifespread = scaledValue(8, scale),
				particlesize = scaledValue(62, scale),
				particlesizespread = scaledValue(35, scale),
				particlespeed = 0.02,
				particlespeedspread = 0.06,
				pos = tealGlowPos,
				sizegrowth = 0.275,
				sizemod = 0.995,
				texture = [[tenebrium_glow]],
			},
		},
		wispWarm = {
			air = true,
			class = [[CSimpleParticleSystem]],
			count = 1,
			ground = true,
			underwater = true,
			water = true,
			properties = {
				airdrag = 0.968,
				alwaysvisible = true,
				animParams = [[4,4,660 r320]],
				colormap = WISP_WARM_COLORMAP,
				directional = false,
				drawOrder = 2,
				emitrot = 60,
				emitrotspread = 142,
				emitvector = [[1, 1, 1]],
				gravity = [[0, 0, 0]],
				numparticles = math.max(1, scaledValue(3, scale)),
				particlelife = scaledValue(14, scale),
				particlelifespread = scaledValue(8, scale),
				particlesize = scaledValue(35, scale),
				particlesizespread = scaledValue(24, scale),
				particlespeed = 0.025,
				particlespeedspread = 0.08,
				pos = arcPos,
				rotParams = [[-2 r4, -1 r2, -180 r360]],
				sizegrowth = 0.225,
				sizemod = 0.994,
				texture = [[tenebrium_wisp]],
			},
		},
		specularGlints = {
			air = true,
			class = [[CSimpleParticleSystem]],
			count = 1,
			ground = true,
			underwater = true,
			water = true,
			properties = {
				airdrag = 0.92,
				alwaysvisible = true,
				animParams = [[4,4,460 r220]],
				colormap = ORANGE_SPECULAR_COLORMAP,
				directional = false,
				drawOrder = 3,
				emitrot = 90,
				emitrotspread = 180,
				emitvector = [[1, 1, 1]],
				gravity = [[0, 0.005, 0]],
				numparticles = math.max(1, scaledValue(2, scale)),
				particlelife = scaledValue(12, scale),
				particlelifespread = scaledValue(8, scale),
				particlesize = scaledValue(25, scale),
				particlesizespread = scaledValue(19, scale),
				particlespeed = 0.2,
				particlespeedspread = 0.4,
				pos = [[0, 0, 0]],
				rotParams = [[-2 r4, -1 r2, -180 r360]],
				sizegrowth = 0.5625,
				sizemod = 0.97,
				texture = [[tenebrium_specular]],
			},
		},
		groundLight = {
			air = true,
			class = [[CStandardGroundFlash]],
			count = 1,
			ground = true,
			underwater = true,
			water = true,
			properties = {
				flashSize = scaledValue(140, scale),
				flashAlpha = 0.34,
				circleGrowth = 1.25,
				circleAlpha = 0.18,
				color = [[1, 0.74, 0.36]],
				ttl = scaledValue(20, scale),
			},
		},
	}
end

local function heapExplosionSpawner(popCount, spreadRadius, heightSpread, explosionName)
	return {
		air = true,
		class = [[CExpGenSpawner]],
		count = popCount,
		ground = true,
		underwater = true,
		water = true,
		properties = {
			delay = [[0]],
			explosiongenerator = [[custom:]] .. explosionName,
			pos = scatterPos(spreadRadius, heightSpread),
		},
	}
end

local effects = {}

for sizeName, profile in pairs(SIZE_PROFILES) do
	local popCount = math.max(1, math.floor(profile.popCount * COOKOFF_VOLUME_SCALE + 0.5))
	local spreadRadius = math.max(1, math.floor(profile.spreadRadius * COOKOFF_VOLUME_SCALE + 0.5))
	local heightSpread = math.max(1, math.floor(profile.heightSpread * COOKOFF_VOLUME_SCALE + 0.5))
	local burstName = "desolation_heap_burst_" .. sizeName

	effects[burstName] = buildScaledHeapBurst(SIZE_SCALES[sizeName])
	effects["desolation_heap_explosion_" .. sizeName] = {
		usedefaultexplosions = false,
		heapBurst = heapExplosionSpawner(popCount, spreadRadius, heightSpread, burstName),
	}
end

return effects
