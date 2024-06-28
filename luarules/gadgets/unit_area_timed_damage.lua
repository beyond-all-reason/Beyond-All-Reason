function gadget:GetInfo()
	return {
		name    = 'Area Timed Damage Handler',
		desc    = '',
		author  = 'efrec',
		version = '2.0',
		date    = '2024-06-27',
		license = 'GNU GPL, v2 or later',
		layer   = -10, -- Sim logic within gadget:Explosion _must_ run before layer 0.
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

---------------------------------------------------------------------------------------------------------------
---- Unit setup guide
--
-- (1) CustomParams. Add these properties to the unit (for ondeath) and/or weapon (for onhit).
--
--	area_duration    -  <number>        -  Required. The duration of the effect in seconds.
--	area_ongoingCEG  -  <string> | nil  -  Name of the CEG that appears continuously for the duration.
--	area_damagedCEG  -  <string> | nil  -  Name of the CEG that appears on anything damaged by the effect.
--	area_damageType  -  <string> | nil  -  The 'type' of the damage, which can be resisted. Be uncreative.
--	area_weaponName  -  <string> | nil  -  The full unit name + weapon name of the dummy area weapon.
--
-- (2) WeaponDefs. Add a new weapondef with its name set to the one specified in the area_weaponName.
--
--	Only a few properties of this weaponDef are used – those that modify explosions:
--    areaofeffect        -  Important.
--    explosiongenerator  -  Important.
--    impulse*            -  Important. Set to 0 in most cases.
--    weapontype          -  Important. Set to "Cannon" (or leave blank?) in most cases.
--    damage              -  Important.
--
--	Any other properties that control projectile behaviors are ignored, in addition to:
--    crater*             -  No effect.
--    edgeeffectiveness   -  No effect. Set to 1.
--    explosionspeed      -  No effect. Set to 10000.
--
-- (3) Damage Immunities. Units can be made immune to area damage via their customParams.
--
--	area_immunities  -  <area_type[]> | nil  -  The list of damage types to which the unit is immune.
--	                                            The base immunities are "acid", "napalm", and "all".
--
---------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------
---- Configuration

local areaImpulseRate   = 0.25                 -- Multiplies the impulse of area weapons. Tbh should be 0 or 1.
local frameResolution   = 5                    -- The bin size, in frames, to loop over groups of areas.
local loopDuration      = 0.5                  -- The time between area procs. Adjusts damage automagically.
local shieldSuppression = false                -- Whether or not shields suppress timed areas.

local defaultWeaponName = "area_timed_damage"  -- Fallback when area_weaponName is not specified in the def.

---------------------------------------------------------------------------------------------------------------
---- Locals

local ceil                 = math.ceil
local max                  = math.max
local sqrt                 = math.sqrt
local remove               = table.remove

local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetGameFrame       = Spring.GetGameFrame
local spGetGameSeconds     = Spring.GetGameSeconds
local spGetGroundHeight    = Spring.GetGroundHeight
local spGetUnitIsStunned   = Spring.GetUnitIsStunned
local spGetUnitPosition    = Spring.GetUnitPosition
local spGetUnitShieldState = Spring.GetUnitShieldState
local spSpawnCEG           = Spring.SpawnCEG
local spSpawnExplosion     = Spring.SpawnExplosion

local gameSpeed            = Game.gameSpeed
local gravity              = Game.gravity

local info = '[area_timed_damage] [info] '
local warn = '[area_timed_damage] [warn] '
local test = '[area_timed_damage] [test] '

---------------------------------------------------------------------------------------------------------------
---- Initialization

-- Pull all the area params into tables.

local weaponTriggerParams = {}
local destroyTriggerParams = {}
local timedAreaParams = {}
local shieldUnitParams = {}

do
	local function AddTimedAreaDef(paramsTable, defID, def)
		local areaWeaponName = def.customParams.area_weaponName or def.name.."_"..defaultWeaponName
		local areaWeaponDef = WeaponDefNames[areaWeaponName]

		if not areaWeaponDef then
			Spring.Echo(warn..'Did not find area weapon for ' .. def.name)
			return
		end

		-- Add two new entries, one for the area trigger and one for the area weapon.
		paramsTable[defID] = {
			area_duration    = tonumber(def.customParams.area_duration or 0),
			area_ongoingCEG  = def.customParams.area_ongoingCEG,
			area_weaponDefID = areaWeaponDef.id,
			area_radius      = areaWeaponDef.damageAreaOfEffect / 2, -- diameter => radius
			area_damages     = areaWeaponDef.damages,
			area_damagedCEG = def.customParams.area_damagedCEG,
			area_damageType = string.lower(def.customParams.area_damageType or "any"),
		}

		timedAreaParams[areaWeaponDef.id] = paramsTable[defID] -- the other id?

		-- Remove misconfigured area weapons.
		local misconfigured = false
		if tonumber(def.customParams.area_duration) <= 0 then
			Spring.Echo(warn..'Invalid area_duration for ' .. def.name)
			misconfigured = true
		end
		if def == areaWeaponDef then
			Spring.Echo(warn..'Removed self-respawning area weapon from ' .. def.name)
			misconfigured = true
		end
		if misconfigured then
			paramsTable[defID] = nil
		end
	end

	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		if weaponDef.customParams and tonumber(weaponDef.customParams.area_duration) then
			AddTimedAreaDef(weaponTriggerParams, weaponDefID, weaponDef)
		end
	end

	for unitDefID, unitDef in pairs(UnitDefs) do
		if tonumber(unitDef.customParams.area_duration) then
			AddTimedAreaDef(destroyTriggerParams, unitDefID, unitDef)
		end
	end
end

-- Timed explosions use the values below, unless noted otherwise:
local explosionCache = {
	weaponDef          = 0, -- params.area_weaponDefID
	owner              = 0,
	projectileID       = 0,
	damages            = 1, -- params.area_damages
	hitUnit            = 1,
	hitFeature         = 1,
	craterAreaOfEffect = 0,
	damageAreaOfEffect = 0, -- params.area_radius * 2
	edgeEffectiveness  = 1,
	explosionSpeed     = 10000,
	impactOnly         = false,
	ignoreOwner        = false,
	damageGround       = false,
}

if shieldSuppression then
	local suppressionCharge = 200 -- or whatever
	local suppressionRadius = 200 -- or whatever
	local suppressionFudger = 8   -- or whatever

	for unitDefID, unitDef in ipairs(UnitDefs) do
		if unitDef.customParams.shield_radius then
			local charge = tonumber(unitDef.customParams.shield_power)  or 0
			local radius = tonumber(unitDef.customParams.shield_radius) or 0
			if charge >= suppressionCharge and
			   radius >= suppressionRadius then
				-- Just straight up ignoring emitter height, offset:
				shieldUnitParams[unitDefID] = radius ^ 2 + suppressionFudger
			end
		end
	end
end

-- Setup for the update loop.

frameResolution = math.clamp(math.round(frameResolution), 1, gameSpeed)
loopDuration    = math.clamp(loopDuration, 0.25, 1)

-- The discrete loop length can differ from the target update time, which we adjust against.
-- e.g. for a 1s period at 30fps with res=29, we end up looping a single group over 0.9667s.
local loopFrameCount = frameResolution * math.round(gameSpeed * loopDuration / frameResolution)
loopDuration = loopFrameCount * (1 / gameSpeed) -- note: may be outside the clamp range.

local groupCount = loopFrameCount / frameResolution
local groupDuration = groupCount * (1 / gameSpeed)

-- Units like the Legion Incinerator and Bastion invert the standard expectation of this script:
-- They create short-duration areas (worse amortization) very quickly (every 30th of a second).
local shortDuration = frameResolution * max(1, math.round(3 * gameSpeed / frameResolution))

-- You don't think you're going to miss that data structure.
-- Lua will prove you wrong. Nevertheless, this isn't so bad:
local areas = {} -- Maintain a contiguous array of ongoing areas.
local freed = {} -- Supported by an array of pseudo-holes.
local nfree = {} -- Which are tracked by a running count.

for ii = 1, groupCount do
	areas[ii] = {}
	freed[ii] = {}
	nfree[ii] = 0
end

-- Timekeeping uses cycling counts.
local ticks = 1 -- int within [1, frameResolution]
local frame = 1 -- int within [1, groupCount]
local time  = 0 -- start of frame in seconds -- todo: => int cumulative group frames

-- We also keep a queue of delayed areas.
-- This also must be a contiguous array.
local delayQueue = {}

-- And a table of units with shields.
local shieldUnits = {}
local shieldFrame = math.clamp(math.round(frameResolution / 2), 1, math.round(gameSpeed / 2))

---------------------------------------------------------------------------------------------------------------
---- Functions

local function startTimedArea(x, y, z, weaponParams)
	local elevation = max(0, spGetGroundHeight(x, z))
	local lowCeiling = elevation + 0.75 * weaponParams.area_radius

	-- Create an area on surface -- immediately.
	if y <= lowCeiling then
		local group = areas[frame]
		local holes = freed[frame]
		local sizeh = nfree[frame]

		local index
		if sizeh > 0 then
			index = holes[sizeh]
			nfree[frame] = sizeh - 1
		else
			index = #group + 1
		end

		-- Groups are looped periodically in GameFrame to spawn explosions.
		group[index] = {
			weaponParams = weaponParams,
			endTime      = weaponParams.area_duration + time,
			x            = x,
			y            = elevation,
			z            = z,
		}

		-- Ideally, area timed weapons are represented by a continuous vfx.
		-- But another option is to use an explosiongenerator on the area weapon.
		if weaponParams.area_ongoingCEG then
			spSpawnCEG(
				weaponParams.area_ongoingCEG,
				x, elevation, z,
				0, 0, 0,
				weaponParams.area_radius,
				weaponParams.area_damages[0]
			)
		end
	-- Create an area on surface -- eventually.
	elseif shortDuration < weaponParams.area_duration -- Brief effects cannot be delayed.
	   and y <= lowCeiling + gravity / 8              -- Up to half a second spent in free-fall.
	then
		local timeToLand = sqrt((y - elevation) * 2 / gravity)
		local frameStart = spGetGameFrame()
		frameStart = frameStart + ceil(timeToLand / gameSpeed) -- at least +1 frame
		if delayQueue[frameStart] then
			delayQueue[frameStart][#delayQueue[frameStart]+1] = { x, elevation, z, weaponParams }
		else
			delayQueue[frameStart] = {}
			delayQueue[frameStart][1] = { x, elevation, z, weaponParams }
		end
	end
end

local function updateTimedAreas()
	local params = explosionCache
	local group = areas[frame]
	local holes = freed[frame]
	local sizeg = #group
	local sizeh = nfree[frame]

	for index = sizeg, 1, -1 do
		local timedArea = group[index]
		if timedArea then
			if time <= timedArea.endTime then
				params.weaponDef          = timedArea.weaponParams.area_weaponDefID
				params.damages            = timedArea.weaponParams.area_damages
				params.damageAreaOfEffect = timedArea.weaponParams.area_radius * 2 -- radius => diameter
				spSpawnExplosion(timedArea.x, timedArea.y, timedArea.z, 0, 0, 0, params)
			elseif index == sizeg then
				group[index] = nil
				sizeg = sizeg - 1
			else
				group[index] = false
				sizeh = sizeh + 1
				holes[sizeh] = index
			end
		-- We try to shrink `group` from within the loop.
		elseif index == sizeg then
			group[index] = nil -- Delete the tombstone.
			sizeg = sizeg - 1  -- Decrement the cursor.
			-- This invalidates a freed index, requiring a linear scan to remove.
			for ii = 1, sizeh do -- Anything past the cursor is junk.
				if index == holes[ii] then
					remove(holes, ii) -- Slow.
					sizeh = sizeh - 1
					break
				end
			end
		end
	end
	nfree[frame] = sizeh
end

local function cancelDelayedAreas(maxGameFrame)
	-- We probably have more shields than delayed areas, which are short-lived and circumstantial.
	local radiusSq, sx, sy, sz, radiusTest, dx, dy, dz
	for shieldUnitID, shieldParams in pairs(shieldUnits) do
		shieldParams[1], shieldParams[2] = spGetUnitShieldState(shieldUnitID)
		shieldParams[1] = shieldParams[1] and not spGetUnitIsStunned(shieldUnitID)
		if shieldParams[1] and shieldParams[2] > 8 then
			radiusSq = shieldParams[3]
			sx, sy, sz = spGetUnitPosition(shieldUnitID)

			-- We don't care about the correctness of a short-lived, single-purpose array.
			-- So when suppressing, we just replace a suppressed area with `false`.
			for frame, delayFrames in pairs(delayQueue) do
				if frame <= maxGameFrame then
					for ii, delayedArea in ipairs(delayQueue) do
						if delayedArea then
							radiusTest = radiusSq + delayQueue[4].area_radius -- close enough
							dx = delayQueue[1] - sx
							dy = delayQueue[2] - sy
							dz = delayQueue[3] - sz
							-- Cylindrical check is occasionally magical:
							if dx*dx + dz*dz < radiusTest and dy*dy < radiusTest then
								delayFrames[ii] = false
							end
						end
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------
---- Gadget call-ins

-- todo: there's also a Toggle, I think

function gadget:Initialize()
	for weaponDefID, _ in pairs(weaponTriggerParams) do
		Script.SetWatchExplosion(weaponDefID, true)
	end

	-- Start/restart timekeeping.

	ticks = 1 + (Spring.GetGameFrame() % frameResolution)
	frame = 1 + (time % groupCount)
	time  = spGetGameSeconds() + groupDuration * 0.5

	-- Build/rebuild info tables.

	for ii = 1, groupCount do
		areas[ii] = {}
		freed[ii] = {}
		nfree[ii] = 0
	end

	if shieldSuppression then
		for _, unitID in pairs(Spring.GetAllUnits()) do
			local unitDefID = Spring.GetUnitDefID(unitID)
			if unitDefID and shieldUnitParams[unitDefID] then
				-- Initialize values: { active, capacity, search radius }
				shieldUnits[unitID] = { false, 0, shieldUnitParams[unitDefID] }
			end
		end
	end
end

function gadget:Shutdown()
	areas = {}
	freed = {}
	nfree = {}
	shieldUnits = {}
end

function gadget:Explosion(weaponDefID, px, py, pz, attackID, projID)
	local weaponParams = weaponTriggerParams[weaponDefID]
	if weaponParams then
		startTimedArea(px, py, pz, weaponParams)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackID, attackDefID, attackTeam)
	local weaponParams = destroyTriggerParams[unitDefID]
	if weaponParams then
		local ux, uy, uz = spGetUnitPosition(unitID)
		startTimedArea(ux, uy, uz, weaponParams)
	end
	shieldUnits[unitID] = nil
end

if shieldSuppression then
	function gadget:UnitFinished(unitID, unitDefID, teamID)
		if shieldUnitParams[unitDefID] then
			shieldUnits[unitID] = { false, 0, shieldUnitParams[unitDefID] }
		end
	end
end

function gadget:GameFrame(gameFrame)
	-- Skip some frames between demanding work.
	ticks = ticks + 1
	if ticks > frameResolution then
		ticks = 1
		frame = frame == groupCount and 1 or frame + 1
		time  = spGetGameSeconds() + groupDuration * 0.5 -- todo: => int cumulative group frames

		updateTimedAreas()
	end

	if shieldSuppression and ticks == shieldFrame then
		cancelDelayedAreas(gameFrame + frameResolution - 1)
	end

	-- Start any areas delayed until this frame.
	if delayQueue[gameFrame] then
		for _, args in ipairs(delayQueue[gameFrame]) do
			if args then
				startTimedArea(args[1], args[2], args[3], args[4])
			end
		end
		delayQueue[gameFrame] = nil
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
	local weaponParams = timedAreaParams[weaponDefID]
	if weaponParams then
		local immunity = UnitDefs[unitDefID].customParams.area_immunities
		if immunity then
			local damageType = weaponParams.area_damageType
			if damageType == "any" then return 0, 0 end
			for _, immunityTo in ipairs(string.split(immunity, " ")) do -- todo: unitdef preprocessing step, instead of this
				if immunityTo == damageType or immunityTo == "all" then return 0, 0 end
			end
		end
		local _,_,_, x,y,z = spGetUnitPosition(unitID, true)
		if y > -8 then
			damage = damage * loopDuration
			if weaponParams.area_damagedCEG then
				spSpawnCEG(weaponParams.area_damagedCEG, x, y + 8, z, 0, 0, 0, 0, damage)
			end
			return damage, areaImpulseRate
		else
			return 0, 0
		end
	end
	return damage, 1
end

function gadget:FeaturePreDamaged(featureID, featureTeam, damage, weaponDefID, projID, attackID, attackDefID, attackTeam)
	local weaponParams = timedAreaParams[weaponDefID]
	if weaponParams then
		damage = damage * loopDuration
		if weaponParams.area_damagedCEG then
			local _,_,_, x,y,z = spGetFeaturePosition(featureID, true)
			spSpawnCEG(weaponParams.area_damagedCEG, x, y + 8, z, 0, 0, 0, 0, damage)
		end
		return damage, areaImpulseRate
	end
	return damage, 1
end

---------------------------------------------------------------------------------------------------------------
---- Tests

-- if true then
-- 	-- Define a single test routine, for both weapons and units.
-- 	-- This needs to be yelly and shouty and angry at least until this branch gets approvals.
-- 	local function TestStuff(id, params, defTable)
-- 		local name = WeaponDefs[defTable[id].area_weaponDefID].name

-- 		-- Check for durations that we do not support properly.
-- 		local duration = params.area_duration
-- 		if duration <= loopDuration then
-- 			Spring.Echo(test..'Duration shorter than loop duration: '..name)
-- 		end
-- 		if 0.1 < 1 - (math.floor(duration / loopDuration) * loopDuration) / duration then
-- 			Spring.Echo(test..'Duration cut off due to loop period: '..name)
-- 		end

-- 		-- Check for missing explosion generators.
-- 		-- Prob too hard: Check for EGs that are too short/long for their effects' durations.
-- 		local highDamage = 80
-- 		if not params.area_damagedCEG then
-- 			if not params.area_ongoingCEG then
-- 				Spring.Echo(test..'Area weapon has no CEGs in customparams: '..name)
-- 			else
-- 				if params.area_damages[0] > highDamage then
-- 					Spring.Echo(test..'High-damage area weapon without damagedCEG: '..name)
-- 				end
-- 			end
-- 		elseif not params.area_ongoingCEG and params.area_damages[0] > highDamage then
-- 			Spring.Echo(test..'High-damage area weapon without ongoingCEG: '..name)
-- 		end
-- 	end

-- 	-- Run the tests.
-- 	for id, params in pairs(weaponAreaParams) do TestStuff(id, params, WeaponDefs) end
-- 	for id, params in pairs(onDeathAreaParams) do TestStuff(id, params, UnitDefs) end
-- end
