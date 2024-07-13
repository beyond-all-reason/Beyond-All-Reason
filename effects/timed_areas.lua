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
local loopSpeed  = math.round(gameSpeed * 1 / 3) -- note: keep in sync w/ unit_area_timed_damage -- todo
local resolution = 2 -- bin size of frame groups

--------------------------------------------------------------------------------------------------------------
------ Configuration

-- From unitDefs with timed area weapons:
local damageList = { "acid", "fire" }
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
local function randomUniform(rate, attempts)
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
local function randomUniformRange(min, max, attempts)
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
local function randomNormal(mean, var, attempts, estimators)
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
	input = tostring(input or "r" .. radius)
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

-- Roles give a consistent set of design choices for areas of effect:
-- Under. A highlight that sits in the background and fills the entire area of effect.
-- Low. An area-fill that animates the area while avoiding obscuring units with its low height.
-- Area. An area-fill that can draw over units so should be relatively translucent and steady.
-- High. An aura effect that is drawn very far back in the draw order. Translucent, broad, long-lived.

--------------------------------------------------------------------------------------------------------------
------ Basic explosion generators

RAD = defaultRadius
TTL = defaultFrames
SEC = gameSpeed
REP = loopSpeed

local definitions = {
	["debug-circle-" .. TTL] = {
		usedefaultexplosions = false,
		debugcircle = {
			class      = [[CBitmapMuzzleFlame]],
			count      = 1,
			air        = false,
			ground     = true,
			underwater = false,
			water      = false,
			properties = {
				colormap     = [[0 0 1 0.5   0 0 0.5 0.1   0 0 0 0]],
				dir          = [[0, 1, 0]],
				drawOrder    = layer.lower,
				frontoffset  = 0,
				fronttexture = [[blastwave]],
				length       = 0,
				pos          = [[0, 0, 0]],
				rotParams    = [[0, 0, 0]],
				sidetexture  = [[none]],
				size         = RAD,
				sizegrowth   = [[0]],
				ttl          = TTL,
			},
		}
	},

	["lowvision-circle-" .. TTL] = {
		usedefaultexplosions = false,
		accessibilitycircle = {
			class      = [[CBitmapMuzzleFlame]],
			count      = 1,
			air        = false,
			ground     = true,
			underwater = false,
			water      = false,
			properties = {
				colormap     = [[0.667 0 0 0.3   0.25 0 0 0.1   0.1 0 0 0.01]],
				dir          = [[0, 1, 0]],
				drawOrder    = layer.lower,
				frontoffset  = 0,
				fronttexture = [[blastwave]],
				length       = 0,
				pos          = [[0, 0, 0]],
				rotParams    = [[0, 0, 0]],
				sidetexture  = [[none]],
				size         = RAD,
				sizegrowth   = [[0]],
				ttl          = TTL,
			},
		}
	},

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
				numparticles        = randomUniform(0.54),
				particlelife        = SEC,
				particlelifespread  = SEC * 0.9,
				particlesize        = 80,
				particlesizespread  = 35,
				particlespeed       = 1,
				particlespeedspread = 1.3,
				pos                 = [[0, 0 r15, 0]],
				rotParams           = [[-5 r10, -5 r10, -180 r360]],
				sizegrowth          = [[2.2 r0.45]],
				sizemod             = 0.98,
				texture             = [[FireBall02-anim]],
			},
		},
	},

	["fire-repeat-high"] = {
		usedefaultexplosions = false,
		smokehaze            = {
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			air        = true,
			ground     = true,
			water      = true,
			underwater = true,
			unit       = false,
			properties = {
				airdrag             = 0.4,
				alwaysvisible       = true, -- !
				castShadow          = false,
				colormap            = [[0 0 0 0.01   0.02 0.02 0.02 0.08   0.01 0.01 0.01 0.05   0.001 0.001 0.001 0.001]],
				directional         = true,
				drawOrder           = layer.lowest, -- !
				emitrot             = 45,
				emitrotspread       = 30,
				emitvector          = [[0, 1, 0]],
				gravity             = [[0, 3, 0]],
				numparticles        = randomUniform(0.1),
				particlelife        = lifetime.long,
				particlelifespread  = lifetime.longer,
				particlesize        = 140,
				particlesizespread  = 80,
				particlespeed       = 20,
				particlespeedspread = 4,
				pos                 = [[-50 r100, 80 r120, -50 r100]],
				rotParams           = [[-2 r4, -1 r2, -90 r180]],
				sizegrowth          = [[0.8 r0.4]],
				sizemod             = 1,
				texture             = [[fogdirty]],
			},
		}
	},

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
				drawOrder           = layer.base,
				emitrot             = 90,
				emitrotspread       = 5,
				emitvector          = [[0.32, 0.7, 0.32]],
				gravity             = [[-0.025 r0.05, 0.03 r0.11, -0.025 r0.05]],
				numparticles        = randomUniform(0.36, 1),
				particlelife        = lifetime.medlong - lifetime.fleeting,
				particlelifespread  = lifetime.medshort - 2 * lifetime.fleeting,
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
				[[0.1 0.1 0 0.01   0.6 0.4 0.3 0.4  0.65 0.55 0.48 0.2   0.3 0.2 0.1 0.12   0.2 0.15 0.18 0.15   0.1 0.1 0 0.05]],
				directional         = false,
				drawOrder           = layer.high,
				emitrot             = 40,
				emitrotspread       = 30,
				emitvector          = [[0.2, -0.4, 0.2]],
				gravity             = [[0, 0.08 r0.1, 0]],
				numparticles        = randomUniform(0.20, 1),
				particlelife        = lifetime.long,
				particlelifespread  = lifetime.medlong,
				particlesize        = 30,
				particlesizespread  = 70,
				particlespeed       = 1,
				particlespeedspread = 1.3,
				pos                 = [[0, 8 r56, 0]],
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
				numparticles        = randomUniform(0.275, 1),
				particlelife        = lifetime.long,
				particlelifespread  = lifetime.medium,
				particlesize        = 150,
				particlesizespread  = 80,
				particlespeed       = 0.10,
				particlespeedspread = 0.16,
				pos                 = [[0, 12 r32, 0]],
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
				drawOrder           = layer.base,
				emitrot             = 90,
				emitrotspread       = 70,
				emitvector          = [[0.3, 1, 0.3]],
				gravity             = [[-0.03 r0.06, 0.24 r0.4, -0.03 r0.06]],
				numparticles        = randomUniform(0.2, 1),
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
				numparticles        = randomUniform(0.23, 1),
				particlelife        = 11,
				particlelifespread  = 11,
				particlesize        = -24,
				particlesizespread  = -8,
				particlespeed       = 9,
				particlespeedspread = 4,
				pos                 = [[-7 r12, 17 r20, -7 r14]],
				sizegrowth          = 0.04,
				sizemod             = 0.91,
				texture             = [[gunshotxl2]],
				useairlos           = false,
			},
		},
	},
}

--------------------------------------------------------------------------------------------------------------
------ Timed area explosion generators

for _, RAD in ipairs(radiusList) do
	for _, TTL in ipairs(framesList) do
		local countEffects = TTL / gameSpeed
		definitions["fire-area-" .. math.floor(RAD) .. "-dur-" .. TTL] = {
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
					size         = randomNormal(RAD, RAD / 7.5, 1, 2),
					sizegrowth   = [[-0.4 r0.4]],
					ttl          = TTL * 1.3,
				},
			},
			firelow = {
				class      = [[CExpGenSpawner]],
				count      = countEffects,
				air        = true,
				ground     = true,
				underwater = true,
				water      = true,
				properties = {
					delay              = [[0 r]] .. TTL - lifetime.medlong,
					explosiongenerator = [[custom:fire-ongoing-low]],
					pos                = string.format(
						[[%.0f r%.0f, 0 r16, %.0f r%.0f]],
						-0.4 * RAD, 0.8 * RAD,
						-0.4 * RAD, 0.8 * RAD
					),
				},
			},
			firearea = {
				class      = [[CExpGenSpawner]],
				count      = countEffects,
				air        = true,
				ground     = true,
				water      = true,
				underwater = true,
				properties = {
					delay              = string.format(
						[[r%.0f i%.0f]],
						lifetime.fleeting,
						(300 - lifetime.long - lifetime.fleeting / 2) / countEffects
					),
					explosiongenerator = [[custom:fire-ongoing-area]],
					pos                = string.format(
						[[%.0f r%.0f, 16 r16, %.0f r%.0f]],
						-0.4 * RAD, 0.8 * RAD,
						-0.4 * RAD, 0.8 * RAD
					),
				},
			},
		}
	end
end

--------------------------------------------------------------------------------------------------------------
------ Repeating area explosion generators

local RATE = gameSpeed / loopSpeed
local FREQ = 1 / RATE

definitions["fire-repeat-high"] = {
	usedefaultexplosions = false,
	smokehaze = {
		class      = [[CSimpleParticleSystem]],
		count      = 1,
		air        = true,
		ground     = true,
		water      = true,
		underwater = true,
		unit       = false,
		properties = {
			airdrag             = 0.4,
			alwaysvisible       = true, -- !
			castShadow          = false,
			colormap            = [[0 0 0 0.01   0.01 0.01 0.01 0.08   0.01 0.01 0.01 0.05   0 0 0 0.001]],
			directional         = true,
			drawOrder           = layer.lowest,
			emitrot             = 45,
			emitrotspread       = 30,
			emitvector          = [[0, 1, 0]],
			gravity             = [[0, 3, 0]],
			numparticles        = randomUniform(0.1),
			particlelife        = lifetime.long,
			particlelifespread  = lifetime.longer,
			particlesize        = 140,
			particlesizespread  = 80,
			particlespeed       = 20,
			particlespeedspread = 4,
			pos                 = [[-75 r150, 80 r120, -75 r150]],
			rotParams           = [[-2 r4, -1 r2, -90 r180]],
			sizegrowth          = [[0.8 r0.4]],
			sizemod             = 1,
			texture             = [[fogdirty]],
		},
	}
}

------

for _, RAD in ipairs(radiusList) do
	-- So that 1 smoke cloud is produced per second for radius = 75,
	-- and increasing areas create more smoke but not _tons_ more:
	local countEffects = math.round(FREQ * math.sqrt(math.round(RAD / 37.5) / 2) / 0.1)

	-- Here, spawners are just used to add delays and influence numparticles.
	definitions["fire-repeat-" .. math.floor(RAD)] = {
		usedefaultexplosions = false,
		firehighgen = {
			class = [[CExpGenSpawner]],
			count = countEffects,
			air = false,
			ground = true,
			water = true,
			underwater = false,
			properties = {
				delay              = [[0 r]] .. lifetime.fleeting,
				explosiongenerator = [[fire-repeat-high]],
				pos                = string.format(
					[[%.0f r%.0f, 2 r6, %.0f r%.0f]],
					-0.5 * RAD, RAD, -0.5 * RAD, RAD
				),
			},
		}
	}
end

--------------------------------------------------------------------------------------------------------------
------ Brief (kinda-repeating) area explosion generators

local RATE = gameSpeed
local FREQ = 1 / RATE

definitions["fire-brief"] = {
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
			numparticles        = randomUniform(FREQ),
			particlelife        = lifetime.medlong - lifetime.fleeting,
			particlelifespread  = lifetime.medlong / 4,
			particlesize        = 11,
			particlesizespread  = 20,
			particlespeed       = 1,
			particlespeedspread = 1.3,
			pos                 = [[0, 2 r14, 0]],
			rotParams           = [[-5 r10, -5 r10, -180 r360]],
			sizegrowth          = [[1.2 r0.45]],
			sizemod             = 0.98,
			texture             = [[FireBall02-anim]],
		},
	},
}

------

definitions["brief-heatray-scald"] = {
	usedefaultexplosions = false,
	flameground = {
		class      = [[CExpGenSpawner]],
		count      = 6, -- or something
		air        = false,
		ground     = true,
		underwater = false,
		water      = true,
		properties = {
			delay = [[0 r]] .. lifetime.fleeting,
			explosiongenerator = [[fire-brief]],
			pos = [[-37.5 r75, 0, -37.5 r75]]
		}
	}
}

--------------------------------------------------------------------------------------------------------------
------ Specific area explosion generators

-- Cluster-fire weapons that overlap their areas can look too concentrated
-- legbar, legbart
if definitions["fire-area-75-dur-300"] then
	definitions["fire-area-75-dur-300-cluster"] = table.copy(definitions["fire-area-75-dur-300"])
	for key, value in pairs(definitions["fire-area-75-dur-300-cluster"]) do
		if key ~= "usedefaultexplosions" and type(value) == "table" then
			if value.count then value.count = math.round(value.count * 5/9) end
		end
	end
end
if definitions["fire-repeat-75"] then
	definitions["fire-repeat-75-cluster"] = table.copy(definitions["fire-repeat-75"])
	for key, value in pairs(definitions["fire-area-75-dur-300-cluster"]) do
		if key ~= "usedefaultexplosions" and type(value) == "table" then
			if value.count then value.count = math.round(value.count * 3/4) end
		end
	end
end

-- Heatray that hits a static target for a long duration, builds up fire/smoke, adds sparks
-- legbastion
local RATE = gameSpeed
local FREQ = 1 / RATE
definitions["fire-brief-sparks"] = {
	usedefaultexplosions = false,
	flamelow = {
		class      = [[CSimpleParticleSystem]],
		count      = 1,
		air        = true,
		ground     = true,
		water      = true,
		underwater = true,
		unit       = true,
		properties = {
			airdrag             = 0.88,
			animParams          = [[8,8,120 r50]],
			castShadow          = false,
			colormap            =
			[[0 0 0 0.01   0.5 0.5 0.3 0.28  0.5 0.5 0.35 0.18   0.1 0.1 0.1 0.12   0.08 0.07 0.06 0.08   0 0 0 0.01]],
			directional         = false,
			drawOrder           = layer.base,
			emitrot             = 40,
			emitrotspread       = 30,
			emitvector          = [[0.2, -0.4, 0.2]],
			gravity             = [[0, 0.04, 0]],
			numparticles        = randomUniform(FREQ),
			particlelife        = lifetime.medlong - lifetime.fleeting,
			particlelifespread  = lifetime.medlong / 4,
			particlesize        = 11,
			particlesizespread  = 20,
			particlespeed       = 1,
			particlespeedspread = 1.3,
			pos                 = [[0, 2 r14, 0]],
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
			numparticles        = randomUniform(2 * FREQ),
			particlelife        = 11,
			particlelifespread  = 11,
			particlesize        = -24,
			particlesizespread  = -8,
			particlespeed       = 9,
			particlespeedspread = 4,
			pos                 = [[-4 r8, 4 r24, -4 r8]],
			sizegrowth          = 0.04,
			sizemod             = 0.91,
			texture             = [[gunshotxl2]],
			useairlos           = false,
		},
	},
}
definitions["brief-heatray-weld"] = {
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
			pos = [[-37.5 r75, 0, -37.5 r75]]
		}
	},
}

return definitions
