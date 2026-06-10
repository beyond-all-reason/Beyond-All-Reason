local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "EMP Lightning",
		desc    = "Spawns environmental lightning at/around paralyzer (EMP) weapon impacts. Amount and size scale with weapon AoE and damage.",
		author  = "Floris",
		date    = "June 2026",
		license = "GNU GPL v2",
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- This is a purely visual, synced gadget: it watches paralyzer weapon explosions
-- and forwards them to the Environmental Lightning GL4 gadget via
-- GG.SpawnEnvironmentalLightning("empimpact", ...). The lightning look itself is
-- defined by the "empimpact" config in gfx_environmental_lightning_gl4.lua; this
-- gadget only decides how big and how many bursts each impact produces.
--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
	return false
end

--------------------------------------------------------------------------------
-- TWEAKABLES
--------------------------------------------------------------------------------
local config = {
	lightningConfig = "empimpact",

	-- A "reference" EMP that maps to sizeScale ~1 and the middle of the range.
	referenceAoE    = 128,     -- weapon AoE (elmos) considered an average EMP
	referenceDamage = 1500,    -- paralyze damage considered a big EMP

	-- SIZE/AMOUNT TIERS
	-- Tier selection is AoE-first to keep intuitive ordering (e.g. armemp always
	-- larger than tiny-beam EMPs). Damage can only bump a tier by +1 at most.
	sizeTiers = {
		{ sizeScale = 0.70, bursts = 1, scatterRadiusScale = 0.34, intensityMul = 0.94 }, -- tiny
		{ sizeScale = 1.05, bursts = 2, scatterRadiusScale = 0.50, intensityMul = 1.00 }, -- small
		{ sizeScale = 1.65, bursts = 4, scatterRadiusScale = 0.68, intensityMul = 1.10 }, -- medium
		{ sizeScale = 2.55, bursts = 7, scatterRadiusScale = 0.90, intensityMul = 1.22 }, -- large
	},
	sizeTierJitter = 0.14,
	aoeTier1Max = 16,
	aoeTier2Max = 96,
	aoeTier3Max = 320,
	highDamageTierBump = 0.92, -- damageNorm threshold to bump one tier (except top tier)

	-- INTENSITY (driven by damage). Brightness multiplier passed to the bursts.
	baseIntensity       = 1.0,
	intensityFromDamage = 0.5, -- up to +this fraction of brightness at reference damage

	-- NORMALISATION (damage only, for intensity / optional tier bump).
	-- AoE directly selects baseline tier.

	-- Where the extra (non-central) bursts are scattered around the impact.
	scatterSizeMin = 0.4,      -- extra bursts are smaller than the central one
	scatterSizeMax = 0.8,
	heightOffset = 10,         -- raise bursts slightly off the impact point
	heightJitter = 12,

	-- AFTERSHOCK TAIL (largest tier only)
	-- Big EMP impacts keep crackling for a short time with decaying scale/intensity,
	-- so they fade naturally instead of ending abruptly.
	tailEnabled = true,
	tailPulseCount = 5,
	tailStartDelayFrames = 6,
	tailIntervalFrames = 6,
	tailIntervalJitterFrames = 2,
	tailSizeDecay = 0.78,
	tailIntensityDecay = 0.72,
	tailBurstDecay = 0.70,
	tailScatterDecay = 0.86,
	tailMinSizeScale = 0.42,
	tailMinIntensityScale = 0.22,
	tailMinBursts = 1,
	maxPendingTailPulses = 512,
}

--------------------------------------------------------------------------------
-- Localized API
--------------------------------------------------------------------------------
local spGetGroundHeight = Spring.GetGroundHeight
local spGetGameFrame = Spring.GetGameFrame
local mathLog    = math.log
local mathMin    = math.min
local mathMax    = math.max
local mathFloor  = math.floor
local mathSqrt   = math.sqrt
local mathSin    = math.sin
local mathCos    = math.cos
local mathPi     = math.pi
local mathRandom = math.random

local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local empWeapons = {}      -- [weaponDefID] = { aoe, damage }
local watched = {}         -- [weaponDefID] = true
local pendingTailPulses = {} -- [{frame, x,y,z, aoe, sizeScale, intensityScale, burstCount, scatterRadiusScale}]

--------------------------------------------------------------------------------
-- Weapon scanning
--------------------------------------------------------------------------------
local function buildEmpWeaponTable()
	for wdid, wd in pairs(WeaponDefs) do
		local dmgs = wd.damages
		local paralyzeTime = (dmgs and dmgs.paralyzeDamageTime) or 0
		local isParalyzer = (wd.paralyzer == true) or (paralyzeTime > 0)
		if isParalyzer then
			local aoe = wd.damageAreaOfEffect or wd.areaOfEffect or 96
			local damage = (dmgs and dmgs[0]) or 0
			empWeapons[wdid] = { aoe = aoe, damage = damage }
			Script.SetWatchExplosion(wdid, true)
			watched[wdid] = true
		end
	end
end

-- Normalise paralyze damage to roughly 0..1 on a log scale.
local function damageNorm(damage)
	if damage <= 0 then return 0.4 end
	local ref = mathMax(config.referenceDamage, 1)
	return mathMin(1.0, mathLog(1 + damage) / mathLog(1 + ref))
end

local function resolveTier(aoe, damage)
	local tierIndex
	if aoe <= config.aoeTier1Max then
		tierIndex = 1
	elseif aoe <= config.aoeTier2Max then
		tierIndex = 2
	elseif aoe <= config.aoeTier3Max then
		tierIndex = 3
	else
		tierIndex = 4
	end

	local dn = damageNorm(damage)
	if dn >= config.highDamageTierBump and tierIndex < #config.sizeTiers then
		tierIndex = tierIndex + 1
	end

	return config.sizeTiers[tierIndex], tierIndex, dn
end

local function spawnImpactCluster(spawn, px, py, pz, aoe, sizeScale, intensityScale, burstCount, scatterRadiusScale)
	spawn(config.lightningConfig, px, py + config.heightOffset, pz, sizeScale, intensityScale)

	if burstCount <= 1 then return end

	local scatterRadius = aoe * scatterRadiusScale
	local sizeRange = config.scatterSizeMax - config.scatterSizeMin
	for _ = 2, burstCount do
		local ang = mathRandom() * 2.0 * mathPi
		local rad = mathSqrt(mathRandom()) * scatterRadius   -- uniform over the disc
		local sx = px + mathCos(ang) * rad
		local sz = pz + mathSin(ang) * rad
		local sy = mathMax(spGetGroundHeight(sx, sz), py) + config.heightOffset + mathRandom() * config.heightJitter
		local ss = sizeScale * (config.scatterSizeMin + mathRandom() * sizeRange)
		spawn(config.lightningConfig, sx, sy, sz, ss, intensityScale)
	end
end

local function scheduleTailPulses(nowFrame, px, py, pz, aoe, sizeScale, intensityScale, burstCount, scatterRadiusScale)
	if not config.tailEnabled then return end

	for i = 1, config.tailPulseCount do
		if #pendingTailPulses >= config.maxPendingTailPulses then
			table.remove(pendingTailPulses, 1)
		end

		local decayPow = i
		local pulseSize = mathMax(config.tailMinSizeScale, sizeScale * (config.tailSizeDecay ^ decayPow))
		local pulseIntensity = mathMax(config.tailMinIntensityScale, intensityScale * (config.tailIntensityDecay ^ decayPow))
		local pulseBursts = mathMax(config.tailMinBursts, mathFloor(burstCount * (config.tailBurstDecay ^ decayPow) + 0.5))
		local pulseScatter = scatterRadiusScale * (config.tailScatterDecay ^ decayPow)

		local interval = config.tailIntervalFrames + mathFloor((mathRandom() * 2.0 - 1.0) * config.tailIntervalJitterFrames)
		if interval < 1 then interval = 1 end
		local delay = config.tailStartDelayFrames + i * interval

		pendingTailPulses[#pendingTailPulses + 1] = {
			frame = nowFrame + delay,
			x = px, y = py, z = pz,
			aoe = aoe,
			sizeScale = pulseSize,
			intensityScale = pulseIntensity,
			burstCount = pulseBursts,
			scatterRadiusScale = pulseScatter,
		}
	end
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------
function gadget:Explosion(weaponDefID, px, py, pz, attackerID, projectileID)
	local info = empWeapons[weaponDefID]
	if not info then return end

	local spawn = GG.SpawnEnvironmentalLightning
	if not spawn then return end

	local aoe = info.aoe
	local tier, tierIndex, dn = resolveTier(aoe, info.damage)

	-- Tiny randomization to keep repeated hits from feeling stamped.
	local sizeScale = tier.sizeScale * (1.0 - config.sizeTierJitter * 0.5 + mathRandom() * config.sizeTierJitter)
	local intensityScale = config.baseIntensity * (1.0 + config.intensityFromDamage * dn) * tier.intensityMul
	local burstCount = tier.bursts
	if dn >= config.highDamageTierBump and tierIndex >= 2 then
		burstCount = burstCount + 1
	end
	local scatterRadiusScale = tier.scatterRadiusScale

	spawnImpactCluster(spawn, px, py, pz, aoe, sizeScale, intensityScale, burstCount, scatterRadiusScale)

	-- Add a decaying tail only for the largest visual tier.
	if tierIndex == #config.sizeTiers then
		scheduleTailPulses(spGetGameFrame(), px, py, pz, aoe, sizeScale, intensityScale, burstCount, scatterRadiusScale)
	end
end

function gadget:GameFrame(frame)
	if #pendingTailPulses == 0 then return end

	local spawn = GG.SpawnEnvironmentalLightning
	if not spawn then return end

	local write = 1
	for read = 1, #pendingTailPulses do
		local p = pendingTailPulses[read]
		if p.frame <= frame then
			spawnImpactCluster(spawn, p.x, p.y, p.z, p.aoe, p.sizeScale, p.intensityScale, p.burstCount, p.scatterRadiusScale)
		else
			pendingTailPulses[write] = p
			write = write + 1
		end
	end

	for i = write, #pendingTailPulses do
		pendingTailPulses[i] = nil
	end
end

function gadget:Initialize()
	buildEmpWeaponTable()
	if next(empWeapons) == nil then
		gadgetHandler:RemoveGadget()
	end
end

function gadget:Shutdown()
	for wdid in pairs(watched) do
		Script.SetWatchExplosion(wdid, false)
	end
	pendingTailPulses = {}
end
