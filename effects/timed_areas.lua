------ Timed Areas CEGs
------ This script produces two-ish types of CEGs, each following a naming convention:
--
-- explosion_generator := <damage_type>-area-<radius>-<lifetime>
--
-- where   damage_type := acid | fire | ...
--         radius      := <number : 000>
--         lifetime    := dur-<frames> | <repetition>
--         frames      := <number : 000>
--         repetition  := looped | brief
--
-- Ex: "acid-area-200-dur-300" is an ongoing acid pool and "fire-area-37-looped" is a recurring burn effect.
--
-- Our general purpose is to maintain standard areas with a preset radius and lifetime in frames.
--
-- This could be used to move all visual effects to the explosion generators on area weapons, which then means
-- areas can be suppressed (by whatever various effect) and properly terminate their CEGs early. Whether that
-- is ever a thing you need to do, though, is a different story.

-- local gameSpeed  = Game.gameSpeed -- lmao wrecked
local gameSpeed  = 30

-- From unit_area_timed_damage:
local loopSpeed  = math.round(gameSpeed * 1 / 3)
local resolution = 2 -- bin size of frame groups

--------------------------------------------------------------------------------------------------------------
------ Configuration

-- From unitDefs with timed area weapons:
local damageList = { "acid", "fire" }         -- plus "juno"?
local radiusList = { 37.5, 75, 150, 200, 250 }
local framesList = { 1, 2, 3, 5, 10, 15, 20 } -- in seconds

--------------------------------------------------------------------------------------------------------------
------ Functions

local function getNearestValue(table, value)
	if not next(table) then return end
	local keyname, nearest
	local lastdif = math.huge
	for key, nextValue in pairs(table) do
		local diff = math.abs(value - nextValue)
		if diff < lastdif then
			keyname = key
			nearest = nextValue
			lastdif = diff
		end
	end
	return nearest, keyname
end

------ CEG operator expressions

-- Timed areas are scripted to use a variable loop time, which means they create
-- variable amounts of CEGs without adjustments. So, we make adjustments:
local gfxPerSec = gameSpeed / loopSpeed

-- Provides a string in the format [[<const> r<rand>]] which evaluates to the given
-- per-second rate of an event over multiple attempts. Range size always == attempts.
local function getUniformRandomFrequency(rate, attempts)
	attempts = attempts or gfxPerSec
	if rate <= 0 then return [[0]] end
	local baseRate = math.floor(rate / attempts)
	local randRate = rate / attempts - baseRate
	return string.format("%.7f r1", baseRate + randRate)
end

-- Provides a string in the format [[<const> r<rand>]] that produces events pinned to
-- an integer range per second over multiple attempts. Not a perfect science*;
-- most combinations of min, max, freq have no discrete uniform solution. *However:
-- e.g. min=1, max=10, n=3 might give [[0.33 r4]], which has min=0, max=12, mean=5.5.
-- If we assume a mean = (min + max) / 2 is ideal, then this solution is kinda okay.
-- Otherwise, you need to use two explosion generators to produce a minimum + a range.
local function getUniformRandomRange(min, max, attempts)
	attempts = attempts or gfxPerSec
	if min > max then min, max = max, min end
	if max <= 0 then return [[0]] end
	local minRate = min / attempts
	local maxRate = max / attempts
	local epsilon = 1e-7
	return string.format("%.7f r%.7f", minRate, 1 + maxRate - minRate - epsilon)
end

-- Provides a CEG operator expression that generates normally distributed events
-- over multiple attempts. Doesn't account for round-down, atm.
-- Output expression is in the format: [[r1 r1 r1 r1 -2 x<half_range> <average>]].
-- Check your work:
-- wolframalpha input: irwin hall distribution, n = 3, min = 0, max = 4
-- wolframalpha input: probability that x>7, given that x~irwin hall distribution, n = 3, min = 0, max = 4
local function getRandomFrequency(mean, var, attempts, estimators)
	attempts = attempts or gfxPerSec
	estimators = math.min(math.max(estimators or 3, 1), 12) -- est=2 is also useful, triangular distribution
	local meanRate = mean / attempts
	local rangeRate = math.sqrt((var / attempts) * (12 / estimators))
	return string.rep("r1 ", estimators) .. string.format([[%.1f y0%.7fx0 %.7f]], -estimators / 2, rangeRate, meanRate)
end

-- These take a positive input and redistribute it radially within an area or volume set by a radius.
-- Preserve any values previously yanked by setting `bufferStart` to the last index to keep + 1.
-- These are intended to help with creating shells and such, for ex: `radius*([[30 r10]], 40)`.

local function radiusCircular(input, radius, bufferStart)
	input = tostring(input or "r1")
	radius = radius or 1
	if radius == 1 then
		return string.format("%s p0.5", input) -- simple as
	else
		bufferStart = bufferStart or 0
		return string.format("%s y%.0f %.7f x%.0f p0.5", input, bufferStart, radius, bufferStart)
	end
end

local function radiusSpherical(input, radius, bufferStart)
	radius = radius or 1
	input = tostring(input or "r"..radius)
	if radius == 1 then
		return string.format("%s p0.3333333", input)
	else
		bufferStart = bufferStart or 0
		return string.format("%s y%.0f %.7f x%.0f p0.3333333", input, bufferStart, radius, bufferStart)
	end
end

--------------------------------------------------------------------------------------------------------------
------ Setup

for ii = 1, #framesList do
	framesList[ii] = framesList[ii] * gameSpeed
end

local defaultRadius = getNearestValue(radiusList, 150)
local defaultFrames = getNearestValue(framesList, 10 * gameSpeed)

local lifetime = {
	none     = 0,
	minimum  = 1,
	-- Short lifetimes have variable meaning with different loop speeds.
	fleeting = math.max(1, math.round(loopSpeed / 2)),
	short    = loopSpeed,
	medshort = math.round((loopSpeed + gameSpeed) / 2),
	-- Whereas longer lifetimes are almost always the same value.
	medium   = loopSpeed * math.round(gameSpeed / loopSpeed * 1),
	medlong  = loopSpeed * math.round(gameSpeed / loopSpeed * 2),
	long     = loopSpeed * math.round(gameSpeed / loopSpeed * 3),
	longer   = loopSpeed * math.round(gameSpeed / loopSpeed * 5),
	longerr  = loopSpeed * math.round(gameSpeed / loopSpeed * 10),
	longest  = loopSpeed * math.round(gameSpeed / loopSpeed * 15),
	maximum  = loopSpeed * math.round(gameSpeed / loopSpeed * 20),
	eternity = loopSpeed * math.round(gameSpeed / loopSpeed * 120),
}

-- Maybe offset layers by damage type to keep them looking nice together? idk
-- acid    = -1,
-- fire    = 1,
local layer = {
	lowest  = -9999,
	lowerr  = -200,
	lower   = -20,
	low     = -2,
	base    = 0,
	high    = 2,
	higher  = 20,
	higherr = 200,
	highest = 9999,
}

--------------------------------------------------------------------------------------------------------------
------ Basic components
------ These are sub-components meant to be composed together into new CEGs.
------ Use them like so: ["new-ceg"] = { component_name = { <base_component_params> }, ... }

-- base_name   := <type>-<role>[-<description>][-<duration>]
-- role        := under | low | area | high
-- description := name | p<frequency> | n<particles>
-- duration    := f<frames> | t<seconds> | <lifetime>

-- Roles give a consistent set of design choices for areas of effect:
-- Under. A highlight that sits in the background and fills the entire area of effect.
-- Low. An area-fill that animates the area while avoiding obscuring units with its low height.
-- Area. An area-fill that can draw over units so should be relatively translucent and steady.
-- High. An aura effect that is drawn very far back in the draw order. Translucent, broad, long-lived.

-- fire components: fire, smoke, charring, illumination, less shadow, heat haze
-- under: fireball underglow | low: animated fire | area: bursty fire and smoke | high: dark haze

-- acid components: liquid, bubbles, sputter, sizzling, heavy vapors
-- under: liquid pool swirl | low: sputtering bubbles | area: heavy vapors, acid spittle | high: yellow haze

-- local basicComponents = {
-- 	["fire-under"] = {
-- 		class = [[CBitmapMuzzleFlame]],
-- 		count = 1,
-- 		air = false,
-- 		ground = true,
-- 		underwater = false,
-- 		water = false,
-- 		properties = {
-- 			animParams = [[8,8,50 r70]],
-- 			colormap =
-- 			[[0.60 0.60 0.48 0.05   0.60 0.60 0.48 0.38   0.66 0.69 0.9 0.3   0.64 0.67 0.79 0.25   0.68 0.78 0.88 0.4   0.02 0.02 0.03 0.24   0.026 0.026 0.026 0.18   0.02 0.02 0.02 0.20   0.023 0.023 0.023 0.18   0 0 0 0.03   0 0 0 0.01]],
-- 			dir = [[0, 1, 0]],
-- 			drawOrder = layer.lower,
-- 			frontoffset = 0,
-- 			fronttexture = [[FireBall02-anim]],
-- 			length = 0,
-- 			pos = [[0, 0, 0]],
-- 			rotParams = [[-2 r4, -2 r4, -90 r100]],
-- 			sidetexture = [[none]],
-- 			size = function(damage, radius, frames) return getUniformRandomRange(radius * 0.9, radius * 0.2, 1) end,
-- 			sizegrowth = [[-0.4 r0.3]],
-- 			ttl = function(damage, radius, frames) return isstring(frames) and loopSpeed or frames end,
-- 		},
-- 	},
-- 	["fire-low"] = {
-- 		class      = [[CSimpleParticleSystem]],
-- 		air        = true,
-- 		count      = 1,
-- 		ground     = true,
-- 		properties = {
-- 			airdrag             = 0.88,
-- 			animParams          = [[8,8,120 r50]],
-- 			castShadow          = false,
-- 			colormap            =
-- 			[[0 0 0 0.01   0.95 0.95 1 0.4   0.65 0.65 0.68 0.2   0.1 0.1 0.1 0.18   0.08 0.07 0.06 0.12   0 0 0 0.01]],
-- 			directional         = false,
-- 			drawOrder           = layer.base,
-- 			emitrot             = 40,
-- 			emitrotspread       = 30,
-- 			emitvector          = [[0.2, -0.4, 0.2]],
-- 			gravity             = [[0, 0.01 r0.04, 0]],
-- 			numparticles        = getUniformRandomFrequency(0.20),
-- 			particlelife        = function(damage, radius, frames)
-- 				return isstring(frames) and loopSpeed or
-- 					lifetime.medium
-- 			end,
-- 			particlelifespread  = function(damage, radius, frames)
-- 				return (isstring(frames) and loopSpeed or lifetime.medium) *
-- 					0.9
-- 			end,
-- 			particlesize        = function(damage, radius, frames) return 2 + math.sqrt(radius) end, -- 11,
-- 			particlesizespread  = function(damage, radius, frames) return 3 * math.sqrt(radius) end, -- 35,
-- 			particlespeed       = 1,
-- 			particlespeedspread = 1.3,
-- 			pos                 = function(damage, radius, frames)
-- 				local scale = 1.15 * math.log(radius) - 1
-- 				return string.format(
-- 					"%.2f r%.2f, %.2f r%.2f, %.2f r%.2f",
-- 					-scale, 2 * scale, 0, 4 * scale, -scale, 2 * scale
-- 				)
-- 			end, -- [[-3 r8, 0 r15, -3 r8]],
-- 			rotParams           = [[-5 r10, -5 r10, -180 r360]],
-- 			sizegrowth          = [[1.2 r0.45]],
-- 			sizemod             = 0.98,
-- 			texture             = [[FireBall02-anim]],
-- 		},
-- 	},
-- 	["fire-high"] = {
-- 		class = [[CSimpleParticleSystem]],
-- 		air = true,
-- 		count = 1,
-- 		ground = true,
-- 		water = true,
-- 		underwater = true,
-- 		unit = false,
-- 		properties = {
-- 			airdrag = 0.6,
-- 			alwaysvisible = false,
-- 			castShadow = false,
-- 			colormap = [[0 0 0 0.01   0.01 0.01 0.01 0.08   0.01 0.01 0.01 0.02   0 0 0 0.001]],
-- 			directional = true,
-- 			drawOrder = -9999, -- da back
-- 			emitrot = 45,
-- 			emitrotspread = 30,
-- 			emitvector = [[0, 1, 0]],
-- 			gravity = [[0, 3, 0]],
-- 			numparticles = function(damage, radius, frames)
-- 				local freq
-- 				if frames == "looped" then
-- 					freq = 1 / loopSpeed / (lifetime.long / gameSpeed) * 2
-- 				elseif frames == "brief" then
-- 					freq = 1 / loopSpeed / (lifetime.long / gameSpeed) / gameSpeed
-- 				else
-- 					freq = 1
-- 				end
-- 				local attempts = isstring(frames) and gfxPerSec or 1
-- 				return getUniformRandomFrequency(freq, attempts)
-- 			end, -- 50%
-- 			particlelife = lifetime.long,
-- 			particlelifespread = lifetime.longer,
-- 			particlesize = function(damage, radius, frames) return radius + 65 end, -- 140,
-- 			particlesizespread = function(damage, radius, frames) return radius + 5 end, -- 80,
-- 			particlespeed = 20,
-- 			particlespeedspread = 4,
-- 			pos = function(damage, radius, frames)
-- 				local scale = radius + 25
-- 				return string.format(
-- 					"%.2f r%.2f, %.2f r%.2f, %.2f r%.2f",
-- 					-scale, 2 * scale, scale / 2, 1.5 * scale, -scale, 2 * scale
-- 				)
-- 			end, -- [[-100 r200, 50 r150, -100 r200]],
-- 			rotParams = [[-2 r4, -1 r2, -90 r180]],
-- 			sizegrowth = [[0.4 r0.4]],
-- 			sizemod = 1,
-- 			texture = [[fogdirty]],
-- 		},
-- 	},
-- }

--------------------------------------------------------------------------------------------------------------
------ Basic explosion generators

-- for _, damage in ipairs(damageList) do
-- for _, radius in ipairs(radiusList) do
-- for _, frames in ipairs(framesList) do
-- 	local area = string.format("-area-%03.0f", math.floor(radius))
-- 	local time = string.format("-dur-%03.0f", math.floor(frames))
-- 	local name = string.format("%s%s%s", damage, area, time)

-- 	ongoingCEG[name] = table.copy({
-- 		under = basicComponents[damage .. "-under"], -- A cohesive area under-light.
-- 		low   = basicComponents[damage .. "-low"], -- Animated low-volume particle effects.
-- 		area  = basicComponents[damage .. "-area"], -- Large volumetric particle effects.
-- 		high  = basicComponents[damage .. "-high"], -- A stacking large-area highlight.
-- 	})

-- 	for role, component in pairs(ongoingCEG[name]) do
-- 		for key, value in component do
-- 			if type(value) == "function" then
-- 				component[key] = value(damage, radius, frames)
-- 			elseif type(value) == "table" then
-- 				for k, v in value do
-- 					if type(v) == "function" then
-- 						value[k] = v(damage, radius, frames)
-- 					end
-- 				end
-- 			end
-- 		end
-- 		if not next(component) then ongoingCEG[name][role] = nil end
-- 	end
-- end
-- end
-- end
-- usingBasicCEG = {}

--------------------------------------------------------------------------------------------------------------
------ Composed explosion generators
------ CEGs are made of one or more components: cegname = { compname = compparams }

--------------------------------------------------------------------------------------------------------------
------ Spawners
------ The CExpGenSpawner class reuses composed CEGs to spawn them multiple times.
------ It can also add variable delays and offset positioning.

--------------------------------------------------------------------------------------------------------------
------ Explosion generators
------ This didn't end up quite so organized. Here's your CEGs.

return {
	------ Circles for inspecting stuff

	-- ["debug-37-brief"] = {
	-- 	usedefaultexplosions = false,
	-- 	debugcircle = {
	-- 		class      = [[CBitmapMuzzleFlame]],
	-- 		count      = 1,
	-- 		air        = false,
	-- 		ground     = true,
	-- 		underwater = false,
	-- 		water      = false,
	-- 		properties = {
	-- 			colormap     = [[0 0 1 0.5   0 0 0.5 0.1   0 0 0 0]],
	-- 			dir          = [[0, 1, 0]],
	-- 			drawOrder    = layer.lower,
	-- 			frontoffset  = 0,
	-- 			fronttexture = [[blastwave]],
	-- 			length       = 0,
	-- 			pos          = [[0, 0, 0]],
	-- 			rotParams    = [[0, 0, 0]],
	-- 			sidetexture  = [[none]],
	-- 			size         = 37.5,
	-- 			sizegrowth   = [[0]],
	-- 			ttl          = loopSpeed,
	-- 		},
	-- 	}
	-- },
	-- ["debug-150-300"] = {
	-- 	usedefaultexplosions = false,
	-- 	debugcircle = {
	-- 		class      = [[CBitmapMuzzleFlame]],
	-- 		count      = 1,
	-- 		air        = false,
	-- 		ground     = true,
	-- 		underwater = false,
	-- 		water      = false,
	-- 		properties = {
	-- 			colormap     = [[0 0 1 0.5   0 0 0.5 0.1   0 0 0 0]],
	-- 			dir          = [[0, 1, 0]],
	-- 			drawOrder    = layer.lower,
	-- 			frontoffset  = 0,
	-- 			fronttexture = [[blastwave]],
	-- 			length       = 0,
	-- 			pos          = [[0, 0, 0]],
	-- 			rotParams    = [[0, 0, 0]],
	-- 			sidetexture  = [[none]],
	-- 			size         = 150,
	-- 			sizegrowth   = [[0]],
	-- 			ttl          = 300,
	-- 		},
	-- 	}
	-- },

	------ Brief areas
	------ These have a shallow mechanical role. They're juiced-up "special fx", so name them like fx.

	["fire-brief"] = {
		usedefaultexplosions = false,
		flamelow = {
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			air        = true,
			ground     = true,
			properties = {
				airdrag             = 0.88,
				animParams          = [[8,8,120 r50]],
				castShadow          = false,
				colormap            =
				[[0 0 0 0.01   0.95 0.95 0.7 0.28  0.65 0.65 0.48 0.18   0.1 0.1 0.1 0.12   0.08 0.07 0.06 0.08   0 0 0 0.01]],
				directional         = false,
				drawOrder           = layer.base,
				emitrot             = 40,
				emitrotspread       = 30,
				emitvector          = [[0.2, -0.4, 0.2]],
				gravity             = [[0, 0.04, 0]],
				numparticles        = getUniformRandomFrequency(1 / gameSpeed),
				particlelife        = lifetime.medlong - lifetime.fleeting,
				particlelifespread  = lifetime.medlong / 4,
				particlesize        = 11,
				particlesizespread  = 20,
				particlespeed       = 1,
				particlespeedspread = 1.3,
				pos                 = [[-3 r8, 0 r15, -3 r8]],
				rotParams           = [[-5 r10, -5 r10, -180 r360]],
				sizegrowth          = [[1.2 r0.45]],
				sizemod             = 0.98,
				texture             = [[FireBall02-anim]],
			},
		},
	},
	["fire-brief-sparks"] = {
		usedefaultexplosions = false,
		flamelow = {
			air        = true,
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			ground     = true,
			properties = {
				airdrag             = 0.88,
				animParams          = [[8,8,120 r50]],
				castShadow          = false,
				colormap            =
				[[0 0 0 0.01   0.95 0.95 0.7 0.28  0.65 0.65 0.48 0.18   0.1 0.1 0.1 0.12   0.08 0.07 0.06 0.08   0 0 0 0.01]],
				directional         = false,
				drawOrder           = layer.base,
				emitrot             = 40,
				emitrotspread       = 30,
				emitvector          = [[0.2, -0.4, 0.2]],
				gravity             = [[0, 0.04, 0]],
				numparticles        = getUniformRandomFrequency(1 / gameSpeed),
				particlelife        = lifetime.medlong - lifetime.fleeting,
				particlelifespread  = lifetime.medlong / 4,
				particlesize        = 11,
				particlesizespread  = 20,
				particlespeed       = 1,
				particlespeedspread = 1.3,
				pos                 = [[-3 r8, 0 r15, -3 r8]],
				rotParams           = [[-5 r10, -5 r10, -180 r360]],
				sizegrowth          = [[1.2 r0.45]],
				sizemod             = 0.98,
				texture             = [[FireBall02-anim]],
			},
		},
		fxsparks = {
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			air        = true,
			ground     = true,
			water      = true,
			underwater = true,
			properties = {
				airdrag             = 0.92,
				colormap            = [[0 0 0 0.01   0 0 0 0.01  1 0.88 0.77 0.030   0.8 0.55 0.3 0.015   0 0 0 0]],
				directional         = true,
				drawOrder           = layer.high,
				emitrot             = 35,
				emitrotspread       = 22,
				emitvector          = [[0, 1, 0]],
				gravity             = [[-0.4 r0.8, -0.1 r0.3, -0.4 r0.8]],
				numparticles        = getUniformRandomFrequency(2 / gameSpeed),
				particlelife        = 11,
				particlelifespread  = 11,
				particlesize        = -24,
				particlesizespread  = -8,
				particlespeed       = 9,
				particlespeedspread = 4,
				pos                 = [[-7 r14, 10 r20, -7 r14]],
				sizegrowth          = 0.04,
				sizemod             = 0.91,
				texture             = [[gunshotxl2]],
				useairlos           = false,
			},
		},
	},
	------
	["brief-heatray-scald"] = {
		usedefaultexplosions = false,
		flameground = {
			class = [[CExpGenSpawner]],
			count = math.round((10 / gameSpeed) / 0.23),
			air = false,
			ground = true,
			underwater = false,
			water = true,
			properties = {
				delay = [[0 r]] .. lifetime.fleeting,
				explosiongenerator = [[fire-brief]],
				pos = [[-37.5 r75, 0 r8, -37.5 r75]]
			}
		}
	},
	["brief-heatray-weld"] = {
		usedefaultexplosions = false,
		flameground = {
			class = [[CExpGenSpawner]],
			count = 1,
			air = false,
			ground = true,
			underwater = false,
			water = true,
			properties = {
				delay = [[0 r]] .. lifetime.fleeting,
				explosiongenerator = [[fire-brief-sparks]],
				pos = [[-37.5 r75, 0 r8, -37.5 r75]]
			}
		},
	},

	------ Repeating areas
	------ Timing is controlled by the loop, so names only need the radius.

	["fire-repeat-low"] = {
		usedefaultexplosions = false,
		firelow = {
			air        = true,
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			ground     = true,
			properties = {
				airdrag             = 0.88,
				animParams          = [[8,8,120 r50]],
				colormap            =
				[[0 0 0 0.01   0.95 0.95 1 0.4  0.65 0.65 0.68 0.2   0.1 0.1 0.1 0.18   0.08 0.07 0.06 0.12   0 0 0 0.01]],
				directional         = false,
				drawOrder           = 0,
				emitrot             = 40,
				emitrotspread       = 30,
				emitvector          = [[0.2, -0.4, 0.2]],
				gravity             = [[0, 0.01 r0.04, 0]],
				numparticles        = getUniformRandomFrequency(0.54),
				particlelife        = 30,
				particlelifespread  = 27,
				particlesize        = 80,
				particlesizespread  = 35,
				particlespeed       = 1,
				particlespeedspread = 1.3,
				pos                 = [[-3 r8, 0 r15, -3 r8]],
				rotParams           = [[-5 r10, -5 r10, -180 r360]],
				sizegrowth          = [[2.2 r0.45]],
				sizemod             = 0.98,
				texture             = [[FireBall02-anim]],
			},
		},
	},
	["fire-repeat-high"] = {
		usedefaultexplosions = false,
		smokehaze = {
			class = [[CSimpleParticleSystem]],
			count = 1,
			air = true,
			ground = true,
			water = true,
			underwater = true,
			unit = false,
			properties = {
				airdrag = 0.4,
				alwaysvisible = true, -- !
				castShadow = false,
				colormap = [[0 0 0 0.01   0.01 0.01 0.01 0.08   0.01 0.01 0.01 0.05   0 0 0 0.001]],
				directional = true,
				drawOrder = layer.lowest,
				emitrot = 45,
				emitrotspread = 30,
				emitvector = [[0, 1, 0]],
				gravity = [[0, 3, 0]],
				numparticles = getUniformRandomFrequency(0.1),
				particlelife = lifetime.long,
				particlelifespread = lifetime.longer,
				particlesize = 140,
				particlesizespread = 80,
				particlespeed = 20,
				particlespeedspread = 4,
				pos = [[-100 r200, 80 r120, -100 r200]],
				rotParams = [[-2 r4, -1 r2, -90 r180]],
				sizegrowth = [[0.8 r0.4]],
				sizemod = 1,
				texture = [[fogdirty]],
				useairlos = true, -- !
			},
		}
	},
	------
	["fire-repeat-37"] = {
		usedefaultexplosions = false,
		firehighgen = {
			class = [[CExpGenSpawner]],
			count = math.round(0.1 / 0.1),
			air = false,
			ground = true,
			water = true,
			underwater = false,
			properties = {
				delay = [[0 r]] .. lifetime.fleeting,
				explosiongenerator = [[fire-repeat-high]],
				pos = [[-30 r60, 0 r5, -30 r60]]
			},
		},
	},
	["fire-repeat-75"] = {
		usedefaultexplosions = false,
		firehighgen = {
			class = [[CExpGenSpawner]],
			count = math.round(0.137 / 0.1),
			air = false,
			ground = true,
			water = true,
			underwater = false,
			properties = {
				delay = [[0 r]] .. lifetime.fleeting,
				explosiongenerator = [[custom:fire-repeat-high]],
				pos = [[-60 r120, 0 r5, -60 r120]]
			},
		},
	},
	["fire-repeat-150"] = {
		usedefaultexplosions = false,
		firehighgen = {
			class = [[CExpGenSpawner]],
			count = math.round(0.2 / 0.1),
			air = false,
			ground = true,
			water = true,
			underwater = false,
			properties = {
				delay = [[0 r]] .. lifetime.fleeting,
				explosiongenerator = [[custom:fire-repeat-high]],
				pos = [[-120 r240, 80 r100, -120 r240]]
			},
		},
	},

	------ Ongoing areas
	------ Names need both the area (radius) and duration (frames).

	["fire-ongoing-low"] = {
		usedefaultexplosions = false,
		firelow = {
			class      = [[CSimpleParticleSystem]],
			count      = 2,
			air        = true,
			ground     = true,
			water      = true,
			properties = {
				airdrag             = 0.92,
				animParams          = [[8,8,40 r55]],
				castShadow          = false,
				colormap            =
				[[0.32 0.22 0.18 0.65   0.75 0.6 0.51 0.65   0.72 0.55 0.39 0.75    0.67 0.5 0.34 0.55   0.60 0.5 0.29 0.5   0.50 0.37 0.39 0.5   0.48 0.31 0.36 0.4    0.11 0.11 0.12 0.32   0.016 0.011 0.07 0.2   0 0 0 0.01]],
				directional         = false,
				drawOrder           = layer.high,
				emitrot             = 90,
				emitrotspread       = 5,
				emitvector          = [[0.32, 0.7, 0.32]],
				gravity             = [[-0.025 r0.05, 0.03 r0.11, -0.025 r0.05]],
				numparticles        = getUniformRandomFrequency(0.36, 1),
				-- long-term area effect with a small delay in the spawner:
				particlelife        = lifetime.medlong - lifetime.fleeting,
				particlelifespread  = lifetime.medshort,
				particlesize        = 20,
				particlesizespread  = 20,
				particlespeed       = 3.20,
				particlespeedspread = 5.20,
				pos                 = [[-3 r6, -25 r10, -3 r6]],
				rotParams           = [[-5 r10, -20 r40, -180 r360]],
				sizegrowth          = [[1.10 r1.05]],
				sizemod             = 0.98,
				texture             = [[FireBall02-anim-fade]],
			},
		},
	},
	["fire-ongoing-area"] = {
		usedefaultexplosions = false,
		firearea = {
			air        = true,
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			ground     = true,
			properties = {
				airdrag             = 0.88,
				animParams          = [[8,8,90 r50]],
				castShadow          = false,
				colormap            =
				[[0 0 0 0.01   0.7 0.5 0.4 0.4  0.65 0.55 0.48 0.2   0.3 0.2 0.1 0.12   0.2 0.15 0.18 0.15   0.1 0.1 0 0.05]],
				directional         = false,
				drawOrder           = layer.high,
				emitrot             = 40,
				emitrotspread       = 30,
				emitvector          = [[0.2, -0.4, 0.2]],
				gravity             = [[0, 0.03 r0.04, 0]],
				numparticles        = getUniformRandomFrequency(0.20, 1),
				particlelife        = lifetime.long,
				particlelifespread  = lifetime.medlong,
				particlesize        = 30,
				particlesizespread  = 70,
				particlespeed       = 1,
				particlespeedspread = 1.3,
				pos                 = [[-4 r8, 8 r56, -4 r8]],
				rotParams           = [[-3 r6, -3 r6, -180 r360]],
				sizegrowth          = [[1 r0.6]],
				sizemod             = 0.98,
				texture             = [[FireBall02-anim]],
			},
		},
		fireareadark = {
			air        = true,
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			ground     = true,
			properties = {
				airdrag             = 0.9,
				animParams          = [[16,6,100 r20]],
				castShadow          = false,
				colormap            =
				[[0.19 0.17 0.11 0.1   0.36 0.27 0.32 0.26   0.4 0.34 0.38 0.1   0.33 0.20 0.20 0.35    0.2 0.20 0.2 0.6   0.29 0.22 0.14 0.3   0.1 0.1 0.1 0.45   0.1 0.1 0.1 0.2    0.05 0.06 0.05 0.15   0.02 0.02 0.02 0.1   0 0 0 0.01]],
				directional         = false,
				drawOrder           = layer.high,
				emitrot             = 55,
				emitrotspread       = 25,
				emitvector          = [[0.28, 0.9, 0.28]],
				gravity             = [[-0.02 r0.04, 0 r0.3, -0.02 r0.04]],
				numparticles        = getUniformRandomFrequency(0.25, 1),
				particlelife        = lifetime.long,
				particlelifespread  = lifetime.medium,
				particlesize        = 160,
				particlesizespread  = 70,
				particlespeed       = 0.10,
				particlespeedspread = 0.16,
				pos                 = [[0, -20 r20, 0]],
				rotParams           = [[-5 r10, 0, -180 r360]],
				sizegrowth          = [[1.6 r1.1]],
				sizemod             = 0.98,
				texture             = [[BARFlame02]],
			},
		},
		fxsmoke = {
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			air        = true,
			ground     = true,
			water      = true,
			properties = {
				airdrag             = 0.70,
				alwaysvisible       = true,
				animParams          = [[8,8,80 r80]],
				castShadow          = true,
				colormap            =
				[[0.01 0.01 0.01 0.01   0.02 0.02 0.01 0.2   0.1 0.1 0.1 0.48   0.11 0.10 0.09 0.65    0.075 0.07 0.07 0.3   0.01 0.01 0.01 0.01]],
				directional         = false,
				drawOrder           = 0,
				emitrot             = 90,
				emitrotspread       = 70,
				emitvector          = [[0.3, 1, 0.3]],
				gravity             = [[-0.03 r0.06, 0.24 r0.4, -0.03 r0.06]],
				numparticles        = getUniformRandomFrequency(0.2, 1),
				particlelife        = lifetime.medlong * 2,
				particlelifespread  = lifetime.medlong,
				particlesize        = 30,
				particlesizespread  = 50,
				particlespeed       = 3,
				particlespeedspread = 2,
				pos                 = [[0.0, 24, 0.0]],
				rotParams           = [[-15 r30, -2 r4, -180 r360]],
				sizegrowth          = [[0.8 r0.55]],
				sizemod             = 1,
				texture             = [[smoke-ice-anim]],
				useairlos           = true,
			},
		},
		fxsparks = {
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			air        = true,
			ground     = true,
			water      = true,
			underwater = true,
			properties = {
				airdrag             = 0.92,
				castShadow          = false,
				colormap            = [[0 0 0 0.01   0 0 0 0.01  1 0.88 0.71 0.030   0.8 0.55 0.3 0.015   0 0 0 0]],
				directional         = true,
				drawOrder           = layer.high,
				emitrot             = 35,
				emitrotspread       = 22,
				emitvector          = [[0, 1, 0]],
				gravity             = [[-0.4 r0.8, -0.1 r0.3, -0.4 r0.8]],
				numparticles        = getUniformRandomFrequency(0.23, 1),
				particlelife        = 11,
				particlelifespread  = 11,
				particlesize        = -24,
				particlesizespread  = -8,
				particlespeed       = 9,
				particlespeedspread = 4,
				pos                 = [[-7 r14, 17 r15, -7 r14]],
				sizegrowth          = 0.04,
				sizemod             = 0.91,
				texture             = [[gunshotxl2]],
				useairlos           = false,
			},
		},
	},
	["fire-ongoing-area-small"] = {
		usedefaultexplosions = false,
		fireareasmall = {
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			air        = true,
			ground     = true,
			properties = {
				airdrag             = 0.88,
				animParams          = [[8,8,120 r50]],
				colormap            =
				[[0 0 0 0.01   0.95 0.95 0.4 0.3  0.65 0.65 0.48 0.2   0.1 0.1 0.1 0.18   0.08 0.07 0.06 0.12   0 0 0 0.01]],
				directional         = false,
				drawOrder           = layer.base,
				emitrot             = 40,
				emitrotspread       = 30,
				emitvector          = [[0.2, -0.4, 0.2]],
				gravity             = [[0, 0.01 r0.04, 0]],
				numparticles        = getUniformRandomFrequency(0.23, 1),
				particlelife        = lifetime.medium,
				particlelifespread  = lifetime.medshort,
				particlesize        = 20,
				particlesizespread  = 35,
				particlespeed       = 1,
				particlespeedspread = 1.3,
				pos                 = [[-3 r8, 0 r15, -3 r8]],
				rotParams           = [[-5 r10, -5 r10, -180 r360]],
				sizegrowth          = [[1.2 r0.45]],
				sizemod             = 0.98,
				texture             = [[FireBall02-anim]],
			},
		},
		fxsmoke = {
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			air        = true,
			ground     = true,
			water      = true,
			properties = {
				airdrag             = 0.70,
				alwaysvisible       = true,
				animParams          = [[8,8,80 r80]],
				castShadow          = true,
				colormap            =
				[[0.01 0.01 0.01 0.01   0.02 0.02 0.01 0.2   0.15 0.14 0.12 0.48   0.11 0.10 0.09 0.65    0.075 0.07 0.07 0.3   0.01 0.01 0.01 0.01]],
				directional         = false,
				drawOrder           = 0,
				emitrot             = 90,
				emitrotspread       = 70,
				emitvector          = [[0.3, 1, 0.3]],
				gravity             = [[-0.03 r0.06, 0.3 r0.3, -0.03 r0.06]],
				numparticles        = getUniformRandomFrequency(0.1, 1),
				particlelife        = lifetime.medlong * 2,
				particlelifespread  = lifetime.medlong,
				particlesize        = 10,
				particlesizespread  = 20,
				particlespeed       = 3,
				particlespeedspread = 2,
				pos                 = [[0.0, 24, 0.0]],
				rotParams           = [[-15 r30, -2 r4, -180 r360]],
				sizegrowth          = [[0.8 r0.55]],
				sizemod             = 1,
				texture             = [[smoke-ice-anim]],
				useairlos           = true,
			},
		},
		fxsparks = {
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			air        = true,
			ground     = true,
			water      = true,
			underwater = true,
			properties = {
				airdrag             = 0.92,
				castShadow          = false,
				colormap            = [[0 0 0 0.01   0 0 0 0.01  1 0.88 0.71 0.030   0.8 0.55 0.3 0.015   0 0 0 0]],
				directional         = true,
				drawOrder           = layer.high,
				emitrot             = 35,
				emitrotspread       = 22,
				emitvector          = [[0, 1, 0]],
				gravity             = [[-0.4 r0.8, -0.1 r0.3, -0.4 r0.8]],
				numparticles        = getUniformRandomFrequency(0.1, 1),
				particlelife        = 11,
				particlelifespread  = 11,
				particlesize        = -24,
				particlesizespread  = -8,
				particlespeed       = 9,
				particlespeedspread = 4,
				pos                 = [[-7 r14, 17 r15, -7 r14]],
				sizegrowth          = 0.04,
				sizemod             = 0.91,
				texture             = [[gunshotxl2]],
				useairlos           = false,
			},
		},
	},
	------
	["fire-area-75-dur-300"] = {
		usedefaultexplosions = false,
		-- debugcircle = {
		-- 	class      = [[CBitmapMuzzleFlame]],
		-- 	count      = 1,
		-- 	air        = false,
		-- 	ground     = true,
		-- 	underwater = false,
		-- 	water      = false,
		-- 	properties = {
		-- 		colormap     = [[0 0 1 0.1   0 0 0.5 0.001]],
		-- 		dir          = [[0, 1, 0]],
		-- 		drawOrder    = layer.lowest,
		-- 		frontoffset  = 0,
		-- 		fronttexture = [[blastwave]],
		-- 		length       = 0,
		-- 		pos          = [[0, 10, 0]],
		-- 		rotParams    = [[0, 0, 0]],
		-- 		sidetexture  = [[none]],
		-- 		size         = 75,
		-- 		sizegrowth   = [[0]],
		-- 		ttl          = 300,
		-- 	},
		-- },
		fireunder = {
			class      = [[CBitmapMuzzleFlame]],
			count      = 1,
			air        = false,
			ground     = true,
			underwater = false,
			water      = false,
			properties = {
				animParams   = [[8,8,60 r80]],
				castShadow   = false,
				colormap     =
				[[0.60 0.50 0.38 0.07   0.7 0.57 0.38 0.36   0.74 0.72 0.5 0.28   0.7 0.72 0.4 0.25   0.68 0.78 0.68 0.34   0.68 0.78 0.68 0.3   0.68 0.78 0.68 0.12   0.023 0.02 0.023 0.26   0.023 0.02 0.023 0.18   0.023 0.018 0.023 0.1   0 0 0 0.05]],
				dir          = [[0, 1, 0]],
				drawOrder    = layer.lower,
				frontoffset  = 0,
				fronttexture = [[FireBall02-anim-fade]],
				length       = 0,
				pos          = [[0, r8, 0]],
				rotParams    = [[-4 r8, -4 r8, -90 r180]],
				sidetexture  = [[none]],
				size         = getRandomFrequency(75, 10, 1, 2),
				sizegrowth   = [[-0.4 r0.4]],
				ttl          = 300 + 100,
			},
		},
		firelow = {
			class      = [[CExpGenSpawner]],
			count      = 10,
			air        = true,
			ground     = true,
			underwater = true,
			water      = true,
			properties = {
				delay              = [[0 r]]..300-lifetime.medlong,
				explosiongenerator = [[custom:fire-ongoing-low]],
				pos                = [[-30 r60, 0 r16, -30 r6s0]],
			},
		},
		firearea = {
			class      = [[CExpGenSpawner]],
			count      = 10,
			air        = true,
			ground     = true,
			water      = true,
			underwater = true,
			properties = {
				-- Correcting for _everything_ adds up:
				delay              = [[r]]..lifetime.fleeting..[[ i]]..((300-lifetime.long-lifetime.fleeting) / 10),
				explosiongenerator = [[custom:fire-ongoing-area]],
				pos                = [[-30 r60, 16 r16, -30 r6s0]],
			},
		},
		-- firehigh is in the repeater, which also has its own firelow
	},
	["fire-area-150-dur-300"] = {
		usedefaultexplosions = false,
		-- debugcircle = {
		-- 	class      = [[CBitmapMuzzleFlame]],
		-- 	count      = 1,
		-- 	air        = false,
		-- 	ground     = true,
		-- 	underwater = false,
		-- 	water      = false,
		-- 	properties = {
		-- 		colormap     = [[0 0 1 0.1   0 0 1 0.01]],
		-- 		dir          = [[0, 1, 0]],
		-- 		drawOrder    = layer.lowest,
		-- 		frontoffset  = 0,
		-- 		fronttexture = [[blastwave]],
		-- 		length       = 0,
		-- 		pos          = [[0, 10, 0]],
		-- 		rotParams    = [[0, 0, 0]],
		-- 		sidetexture  = [[none]],
		-- 		size         = 150,
		-- 		sizegrowth   = [[0]],
		-- 		ttl          = 300,
		-- 	},
		-- },
		fireunder = {
			class      = [[CBitmapMuzzleFlame]],
			count      = 1,
			air        = false,
			ground     = true,
			underwater = false,
			water      = false,
			properties = {
				animParams   = [[8,8,40 r100]],
				colormap     =
				[[0.60 0.50 0.38 0.07   0.7 0.57 0.38 0.36   0.74 0.72 0.5 0.28   0.7 0.72 0.4 0.25   0.68 0.78 0.68 0.34   0.68 0.78 0.68 0.3   0.68 0.78 0.68 0.12   0.023 0.02 0.023 0.26   0.023 0.02 0.023 0.18   0.023 0.018 0.023 0.1   0 0 0 0.05]],
				dir          = [[0, 1, 0]],
				drawOrder    = layer.lower,
				frontoffset  = 0,
				fronttexture = [[FireBall02-anim-fade]],
				length       = 0,
				pos          = [[0, r8, 0]],
				rotParams    = [[-2 r4, -2 r4, -90 r180]],
				sidetexture  = [[none]],
				size         = getRandomFrequency(150, 20, 1, 2),
				sizegrowth   = [[-0.4 r0.4]],
				ttl          = 300 + 100,
			},
		},
		firelow = {
			class      = [[CExpGenSpawner]],
			count      = 16,
			air        = true,
			ground     = true,
			underwater = true,
			water      = true,
			properties = {
				delay              = [[0 r]]..300-lifetime.medlong,
				explosiongenerator = [[custom:fire-ongoing-low]],
				pos                = [[-70 r140, 0 r10, -70 r140]],
			},
		},
		firearea = {
			class      = [[CExpGenSpawner]],
			count      = 16,
			air        = true,
			ground     = true,
			water      = true,
			underwater = true,
			properties = {
				delay              = [[r]]..lifetime.fleeting..[[ i]]..((300-lifetime.long-lifetime.fleeting) / 16),
				explosiongenerator = [[custom:fire-ongoing-area]],
				pos                = [[-80 r160, 20 r32, -80 r160]],
			},
		},
		-- firehigh is in the repeater, which also has its own firelow
	},
	["fire-area-150-dur-450"] = {
		usedefaultexplosions = false,
		fireunder = {
			class      = [[CBitmapMuzzleFlame]],
			count      = 1,
			air        = false,
			ground     = true,
			underwater = false,
			water      = false,
			properties = {
				animParams   = [[8,8,60 r80]],
				castShadow   = false,
				colormap     =
				[[0.60 0.50 0.38 0.07   0.7 0.57 0.38 0.36   0.74 0.72 0.5 0.28   0.7 0.72 0.4 0.25   0.68 0.78 0.68 0.34   0.68 0.78 0.68 0.3   0.68 0.78 0.68 0.12   0.023 0.02 0.023 0.26   0.023 0.02 0.023 0.18   0.023 0.018 0.023 0.1   0 0 0 0.05]],
				dir          = [[0, 1, 0]],
				drawOrder    = layer.lower,
				frontoffset  = 0,
				fronttexture = [[FireBall02-anim-fade]],
				length       = 0,
				pos          = [[0, r8, 0]],
				rotParams    = [[-4 r8, -4 r8, -90 r180]],
				sidetexture  = [[none]],
				size         = getRandomFrequency(150, 20, 1, 2),
				sizegrowth   = [[-0.4 r0.4]],
				ttl          = 450 + 100,
			},
		},
		firelow = {
			class      = [[CExpGenSpawner]],
			count      = 20,
			air        = true,
			ground     = true,
			underwater = true,
			water      = true,
			properties = {
				delay              = [[0 r450]],
				explosiongenerator = [[custom:fire-ongoing-low]],
				pos                = [[-60 r120, 0 r20, -60 r120]],
			},
		},
		firearea = {
			class      = [[CExpGenSpawner]],
			count      = 20, --60
			air        = true,
			ground     = true,
			water      = true,
			underwater = true,
			properties = {
				delay              = [[i]] .. (450 / 20),
				explosiongenerator = [[custom:fire-ongoing-area]],
				pos                = [[-100 r200, 32 r24, -100 r200]],
			},
		},
		-- firehigh is in the repeater, which also has its own firelow
	},

	------ Specific units
	["fire-area-75-dur-300-cluster"] = {
		usedefaultexplosions = false,
		-- debugcircle = {
		-- 	class      = [[CBitmapMuzzleFlame]],
		-- 	count      = 1,
		-- 	air        = false,
		-- 	ground     = true,
		-- 	underwater = false,
		-- 	water      = false,
		-- 	properties = {
		-- 		colormap     = [[0 0 1 0.1   0 0 0.5 0.001]],
		-- 		dir          = [[0, 1, 0]],
		-- 		drawOrder    = layer.lowest,
		-- 		frontoffset  = 0,
		-- 		fronttexture = [[blastwave]],
		-- 		length       = 0,
		-- 		pos          = [[0, 10, 0]],
		-- 		rotParams    = [[0, 0, 0]],
		-- 		sidetexture  = [[none]],
		-- 		size         = 75,
		-- 		sizegrowth   = [[0]],
		-- 		ttl          = 300,
		-- 	},
		-- },
		fireunder = {
			class      = [[CBitmapMuzzleFlame]],
			count      = 1,
			air        = false,
			ground     = true,
			underwater = false,
			water      = false,
			properties = {
				animParams   = [[8,8,60 r80]],
				castShadow   = false,
				colormap     =
				[[0.60 0.50 0.38 0.07   0.7 0.57 0.38 0.36   0.74 0.72 0.5 0.28   0.7 0.72 0.4 0.25   0.68 0.78 0.68 0.34   0.68 0.78 0.68 0.3   0.68 0.78 0.68 0.12   0.023 0.02 0.023 0.26   0.023 0.02 0.023 0.18   0.023 0.018 0.023 0.1   0 0 0 0.05]],
				dir          = [[0, 1, 0]],
				drawOrder    = layer.lower,
				frontoffset  = 0,
				fronttexture = [[FireBall02-anim-fade]],
				length       = 0,
				pos          = [[0, r8, 0]],
				rotParams    = [[-4 r8, -4 r8, -90 r180]],
				sidetexture  = [[none]],
				size         = getRandomFrequency(75, 10, 1, 2),
				sizegrowth   = [[-0.4 r0.4]],
				ttl          = 300 + 100,
			},
		},
		firelow = {
			class      = [[CExpGenSpawner]],
			count      = 5,
			air        = true,
			ground     = true,
			underwater = true,
			water      = true,
			properties = {
				delay              = [[0 r]]..300-lifetime.medlong,
				explosiongenerator = [[custom:fire-ongoing-low]],
				pos                = [[-30 r60, 0 r16, -30 r6s0]],
			},
		},
		firearea = {
			class      = [[CExpGenSpawner]],
			count      = 5,
			air        = true,
			ground     = true,
			water      = true,
			underwater = true,
			properties = {
				-- Correcting for _everything_ adds up:
				delay              = [[r]]..lifetime.fleeting..[[ i]]..((300-lifetime.long-lifetime.fleeting) / 7),
				explosiongenerator = [[custom:fire-ongoing-area]],
				pos                = [[-30 r60, 16 r16, -30 r6s0]],
			},
		},
		-- firehigh is in the repeater, which also has its own firelow
	},
}
