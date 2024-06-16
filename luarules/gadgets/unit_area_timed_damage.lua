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

local areaImpulseRate = 0.25                   -- Multiplies the impulse of area weapons. Tbh should be 0 or 1.
local frameResolution = 3                      -- The bin size, in frames, to loop over groups of areas.
local loopDuration    = 0.5                    -- The time between area procs. Adjusts damage automagically.

local defaultWeaponName = "area_timed_damage"  -- Fallback when area_weaponName is not specified in the def.

---------------------------------------------------------------------------------------------------------------

-- Pull all the area params into tables.

local weaponAreaParams  = {}
local onDeathAreaParams = {}
local timedAreaParams   = {}

local function AddTimedAreaDef(defID, def, isUnitDef)
	local weaponName = def.customParams.area_weaponName or def.name.."_"..defaultWeaponName
	local areaWeaponDef = WeaponDefNames[weaponName]

	if not areaWeaponDef then
		Spring.Echo('[area_timed_damage] [warn] Did not find area weapon for ' .. def.name)
		return
	end

	-- We need both the input def's customParams and the dummy area weapon's weaponDef.
	def.area_weaponDef = areaWeaponDef
	if isUnitDef then
		onDeathAreaParams[defID] = def.customParams
	else
		weaponAreaParams[defID] = def.customParams
	end
	timedAreaParams[areaWeaponDef.id] = def.customParams

	-- Remove misconfigured area weapons.
	local remove = false
	if def.customParams.area_duration < 0 then
		Spring.Echo('[area_timed_damage] [warn] Invalid area_duration for ' .. def.name)
		remove = true
	end
	if def == areaWeaponDef then
		Spring.Echo('[area_timed_damage] [warn] Removed self-respawning area weapon from ' .. def.name)
		remove = true
	end
	if remove then
		if isUnitDef then onDeathAreaParams[defID] = nil else weaponAreaParams[defID] = nil end
	end
end

for weaponDefID, weaponDef in pairs(WeaponDefs) do
	if weaponDef.customParams and weaponDef.customParams.area_duration then
		AddTimedAreaDef(weaponDefID, weaponDef, false)
	end
end

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.area_duration then
		AddTimedAreaDef(unitDefID, unitDef, true)
	end
end

local explosionCache = {
	weaponDef         = 0, -- uses the ID from area_weaponDef.id
	edgeEffectiveness = 1,
	explosionSpeed    = 10000,
	damageGround      = false,
}

-- Setup for the update loop.

frameResolution = math.clamp(math.round(frameResolution), 1, Game.gameSpeed) -- ? complains about args
loopDuration    = math.clamp(loopDuration, 0.25, 1)

-- The discrete loop length can differ from the target update time, which we adjust against.
-- e.g. for a 1s period at 30fps with res=29, we end up looping a single group over 0.9667s.
local loopFrameCount = frameResolution * math.round(Game.gameSpeed * loopDuration / frameResolution)
loopDuration = loopFrameCount * (1 / Game.gameSpeed) -- note: may be outside the clamp range.
local loopRate = 1 / loopDuration

local groupCount = loopFrameCount / frameResolution
local groupDuration = groupCount * (1 / Game.gameSpeed)

local areas = {} -- Maintain a contiguous array of ongoing areas.
local freed = {} -- Supported by an array of pseudo-holes.
local nfree = {} -- Which are tracked by a running count.
local empty = {} -- And patched with an `empty` element.
                 -- ? idk if this works in 5.1; the goal is to keep #group[index] an O(1).

for ii = 1, groupCount do
	areas[ii] = {}
	freed[ii] = {}
	nfree[ii] = 0
end

-- Timekeeping uses cycling counts.
local ticks = 0
local frame = 0
local time  = 0

-- We also keep a queue of delayed areas.
local queue = {}

---------------------------------------------------------------------------------------------------------------

local function StartTimedArea(x, y, z, weaponParams)
	local elevation = math.max(0, Spring.GetGroundHeight(x, z))
	local radius = weaponParams.area_weaponDef.damageAreaOfEffect

	-- Create an area on ground -- immediately.
	if y <= elevation + radius * 0.5 then
		local group = areas[frame]
		local holes = freed[frame]
		local sizeh = nfree[frame]

		local index
		if sizeh > 0 then
			index = holes[sizeh]
			sizeh = sizeh - 1
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
			Spring.SpawnCEG(
				weaponParams.area_ongoingCEG,
				x, elevation, z,
				0, 0, 0,
				radius,                                -- Just used for scaling?
				weaponParams.area_weaponDef.damages[0] -- Just used for scaling?
			)
		end
	-- Create an area on ground -- eventually.
	elseif y < elevation + radius * 3 then
		local timeToStart = 0.9 * math.sqrt((y - elevation - radius * 0.5) * 2 / Game.gravity)
		local delayFrame = Spring.GetGameFrame()
		delayFrame = math.max(delayFrame + 1, delayFrame + math.round(timeToStart / Game.gameSpeed))
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

	for index = sizeg, 1, -1 do
		local timedArea = group[index]
		if timedArea ~= empty then
			if time <= timedArea.endTime then
				params.weaponDef = timedArea.params.area_weaponDef.id
				Spring.SpawnExplosion(timedArea.x, timedArea.y, timedArea.z, 0, 0, 0, params)
			elseif index == sizeg then
				group[index] = nil
				sizeg = sizeg - 1
			else
				group[index] = empty
				holes[sizeh] = index
				sizeh = sizeh + 1
			end
		elseif index == sizeg then
			group[index] = nil
			sizeg = sizeg - 1
			for ii, cursor in pairs(holes) do
				if cursor == index then
					table.remove(holes, ii)
					sizeh = sizeh - 1
				end
			end
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

function gadget:Explosion(weaponDefID, px, py, pz, attackerID, projectileID)
	local weaponParams = weaponAreaParams[weaponDefID]
	if weaponParams then StartTimedArea(px, py, pz, weaponParams) end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	local weaponParams = onDeathAreaParams[unitDefID]
	if weaponParams then
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
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
		time = Spring.GetGameSeconds() + groupDuration * 0.5

		-- Create explosions.
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
			if isInActiveShield then table.remove(delayedAreas, ii) end
		end
	end

	-- Activate delayed-start timed areas.
	if queue[gameFrame] then
		for _, args in ipairs(queue[gameFrame]) do
			StartTimedArea(args[1], args[2], args[3], args[4])
		end
		queue[gameFrame] = nil
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
	local weaponParams = timedAreaParams[weaponDefID]
	if weaponParams then
		local unitDef = UnitDefs[unitDefID]
		local immunity = unitDef.customParams.area_immunities
		if immunity and string.find(immunity, weaponParams.area_damageType, 1, true) then
			return 0, 0
		else
			local _,_,_, x,y,z = Spring.GetUnitPosition(unitID, true)
			if y > -8 then
				damage = damage * loopRate
				if weaponParams.area_damagedCEG then
					Spring.SpawnCEG(weaponParams.area_damagedCEG, x, y + 8, z, 0, 0, 0, 0, damage)
				end
				return damage, areaImpulseRate
			else
				return 0, 0
			end
		end
	end
	return damage, 1
end

function gadget:FeaturePreDamaged(featureID, featureTeam, damage, weaponDefID, projID, attackID, attackDefID, attackTeam)
	local weaponParams = timedAreaParams[weaponDefID]
	if weaponParams then
		damage = damage * loopRate
		if weaponParams.area_damagedCEG then
			local _,_,_, x,y,z = Spring.GetFeaturePosition(featureID, true)
			Spring.SpawnCEG(weaponParams.area_damagedCEG, x, y + 8, z, 0, 0, 0, 0, damage)
		end
		return damage, areaImpulseRate
	end
	return damage, 1
end

---------------------------------------------------------------------------------------------------------------

-- Tests

if true then
	-- Define a single test routine, for both weapons and units.
	-- This needs to be yelly and shouty and angry at least until this branch gets approvals.
	local warn = '[area_timed_damage] [warn] '
	local info = '[area_timed_damage] [info] '
	local function TestStuff(id, params, defTable)
		local name = defTable[id].name

		-- Check for durations that we do not support properly.
		local duration = params.area_duration
		if duration <= loopDuration then
			Spring.Echo(warn..'Duration shorter than loop duration: '..name)
		end
		if 0.1 < 1 - (math.floor(duration / loopDuration) * loopDuration) / duration then
			Spring.Echo(warn..'Duration cut off due to loop period: '..name)
		end

		-- Check for missing explosion generators.
		-- Prob too hard: Check for EGs that are too short/long for their effects' durations.
		local highDamage = 80
		if not params.area_damagedCEG then
			if not params.area_ongoingCEG then
				Spring.Echo(info..'Area weapon has no CEGs in customparams: '..name)
			else
				if params.area_weaponDef.damages[0] > highDamage then
					Spring.Echo(info..'High-damage area weapon without damagedCEG: '..name)
				end
			end
		elseif not params.area_ongoingCEG and params.area_weaponDef.damages[0] > highDamage then
			Spring.Echo(info..'High-damage area weapon without ongoingCEG: '..name)
		end
	end

	-- Run the tests.
	for id, params in pairs(weaponAreaParams) do TestStuff(id, params, WeaponDefs) end
	for id, params in pairs(onDeathAreaParams) do TestStuff(id, params, UnitDefs) end
end
