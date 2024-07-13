function gadget:GetInfo()
	return {
		name    = 'Area Timed Damage Handler',
		desc    = '',
		author  = 'efrec',
		version = '2.0',
		date    = '2024-06-27',
		license = 'GNU GPL, v2 or later',
		layer   = 10,
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
local frameResolution   = 1                    -- The bin size, in frames, to loop over groups of areas.
local loopDuration      = 1/2                  -- The time between area procs. Adjusts damage automagically.

local briefTimedAreas   = false                -- Whether or not short-lived areas are spawned. Can reduce FPS.
local shieldSuppression = true                 -- Whether or not shields suppress timed areas. Can reduce FPS.
local suppressionCharge = 100                  -- Minimum total capacity for a shield to suppress timed areas.
local suppressionRadius = 100                  -- Minimum shield radius for a shield to suppress timed areas.

local defaultWeaponName = "area_timed_damage"  -- Fallback when area_weaponName is not specified in the def.

---------------------------------------------------------------------------------------------------------------
---- Locals

local ceil                 = math.ceil
local max                  = math.max
local sqrt                 = math.sqrt

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

local info = '[unit_area_timed_damage] [info] '
local warn = '[unit_area_timed_damage] [warn] '
local test = '[unit_area_timed_damage] [test] '

---------------------------------------------------------------------------------------------------------------
---- Initialization

-- Setup for the update loop.

frameResolution = math.clamp(math.round(frameResolution), 1, gameSpeed)
loopDuration    = math.clamp(loopDuration, 0.2, 1)

-- The discrete loop length can differ from the target update time, which we adjust against.
-- e.g. for a 1s period at 30fps with res=29, we end up looping a single group over 0.9667s.
local loopFrameCount = frameResolution * math.round(gameSpeed * loopDuration / frameResolution)
loopDuration = loopFrameCount * (1 / gameSpeed) -- note: may be outside the clamp range.

local groupCount = loopFrameCount / frameResolution
local groupDuration = frameResolution * (1 / gameSpeed)

-- Maintain a contiguous array of ongoing areas.
local timedAreas = {}
for ii = 1, groupCount do
	timedAreas[ii] = {}
end

-- Timekeeping uses cycling counts.
local ticks = 1 -- int within [1, frameResolution]
local frame = 1 -- int within [1, groupCount]
local time  = 1 -- int cumulative group frames

-- Some values to adjust based on the loop duration:
-- Some weapons, eg BeamLasers, create many timed areas (too many) very quickly (too quick).
-- Generally, these are toggled off with `briefTimedAreas = false` to save on FPS.
local shortDuration = 3 -- in seconds
shortDuration = math.round(shortDuration / groupDuration) -- in frame groups
-- Assuming area impulse is enabled (>0) at all, scale it by the loop duration.
areaImpulseRate = areaImpulseRate * math.min(2, math.sqrt(1 / loopDuration))

-- Pull all the area params into tables.

local weaponTriggerParams = {}
local destroyTriggerParams = {}
local timedAreaParams = {}
local shieldUnitParams = {}

do
	local function addTimedAreaDef(paramsTable, defID, def)
		local areaWeaponName = def.customParams.area_weaponname or def.name.."_"..defaultWeaponName
		local areaWeaponDef = WeaponDefNames[areaWeaponName]

		if not areaWeaponDef then
			Spring.Echo(warn..'Did not find area weapon for ' .. def.name)
		end

		-- Add two new entries, one for the area trigger and one for the area weapon.
		paramsTable[defID] = {
			area_duration    = math.round(tonumber(def.customParams.area_duration or 0) / groupDuration),
			area_weapondefid = areaWeaponDef.id,
			area_weaponname  = areaWeaponDef.name,
			area_damages     = areaWeaponDef.damages,
			area_radius      = areaWeaponDef.damageAreaOfEffect / 2, -- diameter => radius
			area_damagetype  = string.lower(def.customParams.area_damagetype or "any"),
			area_ongoingceg  = def.customParams.area_ongoingceg and tostring(def.customParams.area_ongoingceg) or nil,
			area_damagedceg  = def.customParams.area_damagedceg and tostring(def.customParams.area_damagedceg) or nil,
		}
		timedAreaParams[areaWeaponDef.id] = paramsTable[defID]
		return true
	end

	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		if tonumber(weaponDef.customParams.area_duration) then
			if addTimedAreaDef(weaponTriggerParams, weaponDefID, weaponDef)
				and not briefTimedAreas
				and weaponTriggerParams[weaponDefID].area_duration <= shortDuration then
				weaponTriggerParams[weaponDefID] = nil
			end
		end
	end

	for unitDefID, unitDef in pairs(UnitDefs) do
		if tonumber(unitDef.customParams.area_duration) then
			addTimedAreaDef(destroyTriggerParams, unitDefID, unitDef)
		end
	end
end

-- Timed explosions use the values below, unless noted otherwise:

local explosionCaches = {}
do
	local explosionCache = {
		weaponDef          = 0, -- params.area_weapondefid
		owner              = 0, -- -1 for destroy triggers, unitID otherwise
		projectileID       = 0,
		damages            = {}, -- params.area_damages
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

	for weaponDefID, params in pairs(weaponTriggerParams) do
		local cache = table.copy(explosionCache)
		cache.weaponDef          = params.area_weapondefid
		cache.damages            = params.area_damages
		cache.damageAreaOfEffect = params.area_radius * 2

		explosionCaches[params] = cache
	end

	for unitDefID, params in pairs(destroyTriggerParams) do
		local cache = table.copy(explosionCache)
		cache.weaponDef          = params.area_weapondefid
		cache.damages            = params.area_damages
		cache.damageAreaOfEffect = params.area_radius * 2

		explosionCaches[params] = cache
	end
end

if shieldSuppression then
	for unitDefID, unitDef in ipairs(UnitDefs) do
		if unitDef.customParams.shield_radius then
			local charge = tonumber(unitDef.customParams.shield_power)  or 0
			local radius = tonumber(unitDef.customParams.shield_radius) or 0
			if charge >= suppressionCharge and radius >= suppressionRadius then
				shieldUnitParams[unitDefID] = radius ^ 2
			end
		end
	end
end

-- We also keep a queue of delayed areas.
local delayQueue = {}

-- And a table of units with shields.
local shieldUnits = {}
local shieldFrame = shieldSuppression and math.clamp(math.round(frameResolution / 2), 1, math.round(gameSpeed / 2))

---------------------------------------------------------------------------------------------------------------
---- Functions

local function startTimedArea(x, y, z, weaponParams, ownerID)
	local duration = weaponParams.area_duration
	local radius = weaponParams.area_radius
	local elevation = max(0, spGetGroundHeight(x, z))

	-- Create an area on surface -- immediately.
	if y <= elevation + radius then
		local group = timedAreas[frame]
		group[#group+1] = {
			duration + time,
			weaponParams,
			ownerID,
			x, elevation, z,
		}

		-- Ideally, area timed weapons are represented by a continuous vfx.
		-- But another option is to use an explosiongenerator on the area weapon.
		if weaponParams.area_ongoingceg then
			local dx, dy, dz = Spring.GetGroundNormal(x, z)
			spSpawnCEG(
				weaponParams.area_ongoingceg,
				x, elevation, z,
				dx, dy, dz -- todo: make this do anything
			)
		end

	-- Create an area on surface -- eventually.
	elseif shortDuration < duration then
		local timeToLand = sqrt((y - elevation - radius) * 2 / gravity)
		-- This check considers two different limits on the fall time:
		-- (1) The max latency players associate a cause (impact) to an effect (area on ground); ~1 sec.
		-- (2) The max time that the falling area effect might remain cohesive; just a heuristic formula.
		if timeToLand < 1 and timeToLand <= 0.25 + (duration - shortDuration) * 0.1 then
			local frameStart = spGetGameFrame() + ceil(timeToLand / gameSpeed) -- at least +1 frame
			if not delayQueue[frameStart] then
				delayQueue[frameStart] = { x, elevation, z, weaponParams, ownerID }
			else
				local queue = delayQueue[frameStart]
				local sizeq = #queue
				queue[sizeq + 1] = x
				queue[sizeq + 2] = elevation
				queue[sizeq + 3] = z
				queue[sizeq + 4] = weaponParams
				queue[sizeq + 5] = ownerID
			end

		-- Spawn a single explosion in-place with no recurring area.
		-- This is useless except possibly to trigger the callins for other effects.
		else
			local explosion = explosionCaches[weaponParams]
			explosion.owner              = ownerID
			spSpawnExplosion(x, y, z, 0, 0, 0, explosion)
		end
	end
end

local function updateTimedAreas()
	local group = timedAreas[frame]
	local sizeg = #group

	local index = 1
	while index <= sizeg do
		local timedArea = group[index]
		if time <= timedArea[1] then
			local explosion = explosionCaches[timedArea[2]]
			explosion.owner = timedArea[3]
			spSpawnExplosion(timedArea[4], timedArea[5], timedArea[6], 0, 0, 0, explosion)
		elseif index == sizeg then
			group[index] = nil
		else
			group[index] = group[sizeg]
			group[sizeg] = nil
			index = index - 1
			sizeg = sizeg - 1
		end
		index = index + 1
	end
end

local function cancelDelayedAreas(maxGameFrame)
	-- We probably have more shields than delayed areas, which are short-lived and circumstantial.
	-- And anyway, we don't want to repeat all this work updating our info on them:
	local enabled, capacity, sx, sy, sz, dx, dy, dz, radiusTest
	for shieldUnitID, radiusSq in pairs(shieldUnits) do
		enabled, capacity = spGetUnitShieldState(shieldUnitID)
		enabled = enabled and not spGetUnitIsStunned(shieldUnitID)
		if enabled and capacity > 8 then
			sx, sy, sz = spGetUnitPosition(shieldUnitID)
			-- We don't care about the correctness of a short-lived, single-purpose array.
			-- So when suppressing, we just replace a suppressed area's xpos with `false`.
			for frame, delayedAreas in pairs(delayQueue) do
				if frame <= maxGameFrame then
					for ii = 1, #delayedAreas, 5 do
						if delayedAreas[ii] then
							dx = delayedAreas[ii  ] - sx
							dy = delayedAreas[ii+1] - sy
							dz = delayedAreas[ii+2] - sz
							radiusTest = delayedAreas[ii+3].area_radius + radiusSq
							if dx*dx + dz*dz < radiusTest and dy*dy < radiusTest then
								-- Fairly uncommon to reach this point in testing.
								delayedAreas[ii] = false
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

function gadget:Initialize()
	if not next(weaponTriggerParams) and not next(destroyTriggerParams) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "No timed area defs found. Removing gadget.")
		gadgetHandler:RemoveGadget(self)
	end

	for weaponDefID, _ in pairs(weaponTriggerParams) do
		Script.SetWatchExplosion(weaponDefID, true)
	end

	-- Start/restart timekeeping.

	time  = 1 + (math.floor(Spring.GetGameFrame() / frameResolution))
	frame = 1 + (math.floor(Spring.GetGameFrame() / frameResolution) % groupCount)
	ticks = 1 + (Spring.GetGameFrame() % frameResolution)

	for ii = 1, groupCount do
		timedAreas[ii] = {}
	end

	-- Build/rebuild info tables.

	if shieldSuppression then
		for _, unitID in pairs(Spring.GetAllUnits()) do
			local unitDefID = Spring.GetUnitDefID(unitID)
			if unitDefID and shieldUnitParams[unitDefID] then
				shieldUnits[unitID] = shieldUnitParams[unitDefID]
			end
		end
	end
end

function gadget:Shutdown()
	timedAreas = {}
	delayQueue = {}
	shieldUnits = {}
end

function gadget:GameFrame(gameFrame)
	-- Skip some frames between demanding work.
	ticks = ticks + 1
	if ticks > frameResolution then
		ticks = 1
		frame = frame == groupCount and 1 or frame + 1
		time  = time + 1
		updateTimedAreas()
	end

	if ticks == shieldFrame then
		cancelDelayedAreas(gameFrame + frameResolution - 1)
	end

	-- Start any areas delayed until this frame.
	if delayQueue[gameFrame] then
		local queue = delayQueue[gameFrame]
		for ii = 1, #queue, 5 do
			if queue[ii] then
				startTimedArea(queue[ii], queue[ii+1], queue[ii+2], queue[ii+3], queue[ii+4])
			end
		end
		delayQueue[gameFrame] = nil
	end
end

function gadget:Explosion(weaponDefID, px, py, pz, attackID, projID)
	if weaponTriggerParams[weaponDefID] then
		startTimedArea(px, py, pz, weaponTriggerParams[weaponDefID], (attackID or -1))
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackID, attackDefID, attackTeam)
	if destroyTriggerParams[unitDefID] then
		local ux, uy, uz = spGetUnitPosition(unitID)
		startTimedArea(ux, uy, uz, destroyTriggerParams[unitDefID], -1)
	end
	shieldUnits[unitID] = nil
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
	if timedAreaParams[weaponDefID] then
		local weaponParams = timedAreaParams[weaponDefID]
		local immunity = UnitDefs[unitDefID].customParams.area_immunities
		if immunity then
			local damageType = weaponParams.area_damagetype
			if damageType == "any" then return 0, 0 end
			for _, immunityTo in ipairs(string.split(immunity, " ")) do -- todo: unitdef preprocessing step, instead of this
				if immunityTo == damageType or immunityTo == "all" then return 0, 0 end
			end
		end
		return damage * loopDuration, areaImpulseRate
	end
	return damage
end

function gadget:FeaturePreDamaged(featureID, featureDefID, featureTeam, damage, weaponDefID, projID, attackID, attackDefID, attackTeam)
	if timedAreaParams[weaponDefID] then
		local weaponParams = timedAreaParams[weaponDefID]
		damage = damage * loopDuration
		if weaponParams.area_damagedceg then
			local _,_,_, x,y,z = spGetFeaturePosition(featureID, true)
			spSpawnCEG(weaponParams.area_damagedceg, x, y + 12, z, 0, 0, 0, 0, damage)
		end
		return damage, areaImpulseRate
	end
	return damage
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
	if timedAreaParams[weaponDefID] then
		local damagedCEG = timedAreaParams[weaponDefID].area_damagedceg
		if damagedCEG then
			local _,_,_, x,y,z = spGetUnitPosition(unitID, true)
			spSpawnCEG(damagedCEG, x, y + 18, z, 0, 0, 0, 0, damage)
		end
	end
end

if shieldSuppression then
	function gadget:UnitFinished(unitID, unitDefID, teamID)
		if shieldUnitParams[unitDefID] then
			shieldUnits[unitID] = shieldUnitParams[unitDefID]
		end
	end
end

---------------------------------------------------------------------------------------------------------------
---- Tests

do
	local messages = {}
	local function testmsg(text, name)
		table.insert(messages, test..text..' : '..name)
	end
	local function warnmsg(text, name)
		table.insert(messages, warn..text..' : '..name)
	end

	local function TestStuff(paramsTable, defID, params)
		local isWeaponDef = paramsTable[defID] == weaponTriggerParams[defID]
		local areaDef = WeaponDefs[paramsTable[defID].area_weapondefid]

		-- Check for durations that we do not support properly.
		local duration = params.area_duration * groupDuration
		if duration < loopDuration then
			testmsg('Duration shorter than loop duration', areaDef.name)
		end
		if 0.10 < 1.00 - (math.floor(duration / loopDuration) * loopDuration) / duration then
			testmsg('Duration cut off due to loop period', areaDef.name)
		end

		-- Check for missing explosion generators.
		local highDamageTimesArea = 30 * 80 -- or whatever
		local damage = areaDef.damages[0]
		local radius = areaDef.damageAreaOfEffect / 2
		if not params.area_damagedceg then
			if not params.area_ongoingceg then
				testmsg('Area weapon has no CEGs in customparams', areaDef.name)
			elseif damage * radius > highDamageTimesArea then
				testmsg('High-damage area weapon without damagedCEG', areaDef.name)
			end
		elseif not params.area_ongoingceg and damage * radius > highDamageTimesArea then
			testmsg('High-damage area weapon without ongoingCEG', areaDef.name)
		end

		-- Check for bad/missing/??? damage types and immunities.
		local damageTypes = { 'acid', 'fire' }
		local immunities  = { 'acid', 'fire', 'raptor', 'friendly', 'all' } -- idk
		if isWeaponDef and not paramsTable[defID].area_damagetype then
			testmsg('Weapon is missing its damage type(acid/napalm/...)', areaDef.name)
		end
	end

	local function FixIssues(paramsTable, defID, def)
		local areaWeaponName = def.customParams.area_weaponname or def.name.."_"..defaultWeaponName
		local areaWeaponDef = WeaponDefNames[areaWeaponName]

		---- Remove misconfigured area triggers and weapons.
		local misconfigured = false
		if tonumber(def.customParams.area_duration * groupDuration) <= 1 / gameSpeed then
			warnmsg('Invalid area_duration', def.name)
			misconfigured = true
		end
		if def == areaWeaponDef then
			warnmsg('Removed self-respawning area weapon', def.name)
			misconfigured = true
		end
		----
		if misconfigured then
			explosionCaches[paramsTable[defID]] = nil
			paramsTable[defID] = nil
		end
	end

	for defID, params in pairs(weaponTriggerParams)  do TestStuff(weaponTriggerParams, defID, params)  end
	for defID, params in pairs(destroyTriggerParams) do TestStuff(destroyTriggerParams, defID, params) end
	local testMessages = #messages

	for defID, _ in pairs(weaponTriggerParams)  do FixIssues(weaponTriggerParams, defID, WeaponDefs[defID]) end
	for defID, _ in pairs(destroyTriggerParams) do FixIssues(destroyTriggerParams, defID, UnitDefs[defID])  end
	local warnMessages = #messages - testMessages

	if #messages > 0 then
		Spring.Echo('unit_area_timed_damage test results: '..testMessages..' tests and '..warnMessages..' issues.')
		Spring.Echo('\n' .. table.concat(messages, '\n'))
	end
end
