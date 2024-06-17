
if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name = 'Area Timed Damage Handler',
		desc = '',
		author = 'Damgam',
		version = '1.0',
		date = '2022',
		license = 'GNU GPL, v2 or later',
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

---------------------------------------------------------------------------------------------------------------
--
-- Unit setup guide -- ! todo: Do this for all the units with area timed damage
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
--    impulse*            -  Important. Set to 0 in most cases. -- todo: might change
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
--	(where area_type := acid | napalm | all | none)
--
---------------------------------------------------------------------------------------------------------------

-- Configuration

local areaImpulseRate   = 0.25                 -- Multiplies the impulse of area weapons. Tbh should be 0 or 1.
local frameResolution   = 3                    -- The bin size, in frames, to loop over groups of areas.
local loopDuration      = 0.5                  -- The time between area procs. Adjusts damage automagically.

local defaultWeaponName = "area_timed_damage"  -- Fallback when area_weaponName is not specified in the def.

---------------------------------------------------------------------------------------------------------------

local ceil                 = math.ceil
local max                  = math.max
local sqrt                 = math.sqrt
local remove               = table.remove
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetGameFrame       = Spring.GetGameFrame
local spGetGameSeconds     = Spring.GetGameSeconds
local spGetGroundHeight    = Spring.GetGroundHeight
local spGetUnitPosition    = Spring.GetUnitPosition
local spSpawnCEG           = Spring.SpawnCEG
local spSpawnExplosion     = Spring.SpawnExplosion
local gameSpeed            = Game.gameSpeed
local gravity              = Game.gravity

local info = '[area_timed_damage] [info] '
local warn = '[area_timed_damage] [warn] '
local test = '[area_timed_damage] [test] '

---------------------------------------------------------------------------------------------------------------

-- Pull all the area params into tables.

local weaponAreaParams  = {}
local onDeathAreaParams = {}
local timedAreaParams   = {}

local function AddTimedAreaDef(paramsTable, defID, def)
	local areaWeaponName = def.customParams.area_weaponName or def.name.."_"..defaultWeaponName
	local areaWeaponDef = WeaponDefNames[areaWeaponName]

	if not areaWeaponDef then
		Spring.Echo(warn..'Did not find area weapon for ' .. def.name)
		return
	end

	-- Set non-explicit damage to subs, vtol, shields, etc. to 0.
	-- todo: Are armor type damage reductions applied before or after *PreDamaged?
	-- todo: test if this even works:
	-- local explicitTypes = { Game.armorTypes.vtol, Game.armorTypes.subs, Game.armorTypes.shields }
	-- if areaWeaponDef.damages[0] then
	-- 	for _, armorType in ipairs(explicitTypes) do
	-- 		if not areaWeaponDef.damages[armorType] then
	-- 			Spring.Echo(
	-- 				warn..'Inexplicit damage to armorType '..armorType..
	-- 				' removed from weapon '..areaWeaponDef.name
	-- 			)
	-- 			areaWeaponDef.damages[armorType] = 0
	-- 		end
	-- 	end
	-- end

	-- Add two new entries, one for the area trigger and one for the area weapon.
	paramsTable[defID] = {
		area_duration    = tonumber(def.customParams.area_duration),
		area_ongoingCEG  = def.customParams.area_ongoingCEG,
		area_weaponDefID = areaWeaponDef.id,
		area_radius      = areaWeaponDef.damageAreaOfEffect,
		area_damages     = areaWeaponDef.damages,
	}

	timedAreaParams[areaWeaponDef.id] = {
		area_damagedCEG = def.customParams.area_damagedCEG,
		area_damageType = def.customParams.area_damageType,
	}

	-- Remove misconfigured area weapons.
	local misconfigured = false
	if tonumber(def.customParams.area_duration) < 0 then
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
		AddTimedAreaDef(weaponAreaParams, weaponDefID, weaponDef)
	end
end

for unitDefID, unitDef in pairs(UnitDefs) do
	if tonumber(unitDef.customParams.area_duration) then
		AddTimedAreaDef(onDeathAreaParams, unitDefID, unitDef)
	end
end

local explosionCache = {
	weaponDef          = 0, -- params.area_weaponDefID
	owner              = 0,
	projectileID       = 0,
	damages            = 1, -- params.area_damages
	hitUnit            = 1,
	hitFeature         = 1,
	craterAreaOfEffect = 0,
	damageAreaOfEffect = 0, -- params.area_radius
	edgeEffectiveness  = 1,
	explosionSpeed     = 10000,
	impactOnly         = false,
	ignoreOwner        = false,
	damageGround       = false,
}

-- Setup for the update loop.

frameResolution = math.clamp(math.round(frameResolution), 1, gameSpeed)
loopDuration    = math.clamp(loopDuration, 0.25, 1)

-- The discrete loop length can differ from the target update time, which we adjust against.
-- e.g. for a 1s period at 30fps with res=29, we end up looping a single group over 0.9667s.
local loopFrameCount = frameResolution * math.round(gameSpeed * loopDuration / frameResolution)
loopDuration = loopFrameCount * (1 / gameSpeed) -- note: may be outside the clamp range.

local groupCount = loopFrameCount / frameResolution
local groupDuration = groupCount * (1 / gameSpeed)

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
local ticks = 0 -- int within [0..frameResolution-1]
local frame = 1 -- int within [1..groupCount]
local time  = 0 -- start of frame in seconds

-- We also keep a queue of delayed areas.
-- This also must be a contiguous array.
local queue = {}

---------------------------------------------------------------------------------------------------------------

local function StartTimedArea(x, y, z, weaponParams)
	local elevation = max(0, spGetGroundHeight(x, z))

	-- Create an area on ground -- immediately.
	if y <= elevation + weaponParams.area_radius * 0.5 then
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
	-- Create an area on ground -- eventually.
	elseif y <= elevation + weaponParams.area_radius * 3 then
		local timeToStart = 0.9 * sqrt((y - elevation - weaponParams.area_radius * 0.5) * 2 / gravity)
		local delayFrame = spGetGameFrame()
		delayFrame = delayFrame + ceil(timeToStart / gameSpeed) -- at least +1 frame
		if not queue[delayFrame] then queue[delayFrame] = {} end
		local delayedAreas = queue[delayFrame]
		delayedAreas[#delayedAreas+1] = { x, elevation, z, weaponParams }
	end
end

local function UpdateTimedAreas()
	local params = explosionCache
	local group = areas[frame]
	local holes = freed[frame]
	local sizeg = #group
	local sizeh = nfree[frame]
	local check = false

	for index = sizeg, 1, -1 do
		local timedArea = group[index]
		if timedArea then
			if time <= timedArea.endTime then
				params.weaponDef          = timedArea.weaponParams.area_weaponDefID
				params.damages            = WeaponDefs[params.weaponDef].damages
				params.damageAreaOfEffect = timedArea.weaponParams.area_radius
				spSpawnExplosion(timedArea.x, timedArea.y, timedArea.z, 0, 0, 0, params)
			elseif index == sizeg then
				group[index] = nil
				sizeg = sizeg - 1
				check = true
			else
				group[index] = false
				sizeh = sizeh + 1
				holes[sizeh] = index
				check = true
			end
		-- We try to shrink `group` from within the loop.
		-- This has a pretty bad worst-case outlook.
		elseif index == sizeg then
			group[index] = nil
			sizeg = sizeg - 1
			-- Because, when we pop from `group` more than once,
			-- we invalidate a freed index, which we find and remove.
			if check then
				for ii, cursor in pairs(holes) do
					if ii > sizeh then break end -- Anything past the cursor is junk.
					if cursor == index then
						remove(holes, ii) -- Slow.
						sizeh = sizeh - 1
						break
					end
				end
			end
			check = true
		end
	end
	nfree[frame] = sizeh
end

---------------------------------------------------------------------------------------------------------------

function gadget:Initialize()
	for weaponDefID, _ in pairs(weaponAreaParams) do
		Script.SetWatchExplosion(weaponDefID, true)
	end
end

function gadget:Explosion(weaponDefID, px, py, pz, attackID, projID)
	local weaponParams = weaponAreaParams[weaponDefID]
	if weaponParams then
		StartTimedArea(px, py, pz, weaponParams)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackID, attackDefID, attackTeam)
	local weaponParams = onDeathAreaParams[unitDefID]
	if weaponParams then
		local ux, uy, uz = spGetUnitPosition(unitID)
		StartTimedArea(ux, uy, uz, weaponParams)
	end
end

function gadget:GameFrame(gameFrame)
	-- Manage ongoing timed areas.
	ticks = ticks + 1
	if ticks == frameResolution then
		ticks = 0

		if frame == groupCount
		then frame = 1
		else frame = frame + 1 end

		time = spGetGameSeconds() + groupDuration * 0.5

		UpdateTimedAreas()
	end

	-- Manage delayed-start timed areas.
	-- These should be uncommon enough that the shield check isn't so bad.
	for _, delayedAreas in pairs(queue) do
		for ii = #delayedAreas,-1,1 do
			-- todo: Exclude areas covered by active shields.
			-- todo: How much overlap is too much? To center? More, less? I feel like "less"?
			-- todo: Like wouldn't you be mad if a fire spread through your shield? You'd be mad.
			local isInActiveShield = false
			if isInActiveShield then
				delayedAreas[ii] = false
			end
		end
	end

	-- Activate delayed-start timed areas.
	if queue[gameFrame] then
		for _, args in ipairs(queue[gameFrame]) do
			if args then
				StartTimedArea(args[1], args[2], args[3], args[4])
			end
		end
		queue[gameFrame] = nil
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
	local weaponParams = timedAreaParams[weaponDefID]
	if weaponParams then
		local immunity = UnitDefs[unitDefID].customParams.area_immunities
		if immunity and string.find(immunity, weaponParams.area_damageType, 1, true) then
			return 0, 0
		end
		local _,_,_, x,y,z = spGetUnitPosition(unitID, true)
		if y > -8 then
			damage = damage * loopDuration
			if weaponParams.area_damagedCEG then
				spSpawnCEG(weaponParams.area_damagedCEG, x, y + 8, z, 0, 0, 0, 0, damage)
			end
			Spring.Echo(
				info..'Damaging a unit with an area weapon for: '..damage..
				' out of '..WeaponDefs[weaponDefID].damages[0]
			)
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
		Spring.Echo(info..'Damaging a feature with an area weapon.')
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

-- Tests

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
