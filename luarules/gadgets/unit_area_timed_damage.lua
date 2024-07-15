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
-- customparams = {
--     area_duration    :=  <number>                    -  Required. The duration of the effect in seconds.
--     area_weaponName  :=  <string> | <default_name>   -  Required. The unit+weapon name of the area weapon.
--     area_ongoingCEG  :=  <string> | nil              -  Name of a CEG that lasts for the entire duration.
--     area_damagedCEG  :=  <string> | nil              -  Name of a CEG that spawns on damaged targets.
--     area_damageType  :=  <string> | nil [WDef only]  -  The name of the weapon's general damage type.
--     area_immunities  :=  <string> | nil [UDef only]  -  Space-separated list of resisted damage types.
-- }
-- 
-- area_weaponName = {
--     areaofeffect        -  Needs to match the size of its CEGs.
--     explosiongenerator  -  Needs to match both the area of effect and loop duration.
--     impulse*            -  Modified by this script. Set to your target impulse per-hit.
--     damage              -  Modified by this script. Set to the damage dealt per-second.
--     crater*             -  Set by this script. Timed areas cannot damage terrain.
--     edgeeffectiveness   -  Set by this script. Damage is evenly distributed in each area.
--     explosionspeed      -  Set by this script. Damage is instantaneous in each area.
-- }
-- 
---------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------
---- Configuration

local frameResolution   = 1                    -- The bin size, in frames, to loop over groups of areas.
local loopDuration      = 1/2                  -- The time between area procs. Adjusts damage automagically.

local areaFlankDamage   = true                 -- When set to `false`, damage is adjusted to offset flanking.
local areaImpulseRate   = 1                    -- Multiplies the impulse of area weapons. Generally 0 or 1.

local enableImmunities  = true                 -- Whether or not units can ignore area damage completely.
local enableBriefAreas  = false                -- Whether or not short-lived areas are spawned. Can reduce FPS.
local reduceDamagedCEGs = true                 -- Reduce number of particles drawn by not displaying some CEGs.
local shieldsDenyAreas  = true                 -- Whether or not shields cancel delayed areas. Can reduce FPS.

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

---------------------------------------------------------------------------------------------------------------
---- Initialization

-- Setup for the update loop.

frameResolution = math.clamp(math.round(frameResolution), 1, gameSpeed)
loopDuration    = math.clamp(loopDuration, 0.2, 1)

local loopFrameCount = frameResolution * math.round(gameSpeed * loopDuration / frameResolution)
loopDuration = loopFrameCount * (1 / gameSpeed)

local groupCount = loopFrameCount / frameResolution
local groupDuration = frameResolution * (1 / gameSpeed)

local ticks = 1 -- int in [1, frameResolution]
local frame = 1 -- int in [1, groupCount]
local time  = 1 -- int cumulative group frames

local shieldFrame = shieldsDenyAreas and math.clamp(math.round(frameResolution / 2), 1, math.round(gameSpeed / 2))
local shortDuration = math.round(3 / groupDuration) -- seconds -> frame groups

areaImpulseRate = areaImpulseRate * math.min(2, math.sqrt(1 / loopDuration))

-- Pull all the defs into info tables.

local weaponTriggerParams = {}
local destroyTriggerParams = {}
local timedAreaParams = {}

for defs, triggerParams in pairs({ [WeaponDefs] = weaponTriggerParams, [UnitDefs] = destroyTriggerParams }) do
	for defID, def in pairs(defs) do
		if tonumber(def.customParams.area_duration) then
			local areaWeaponName = def.customParams.area_weaponname or def.name.."_"..defaultWeaponName
			local areaWeaponDef = WeaponDefNames[areaWeaponName]
			if not areaWeaponDef then
				Spring.Log(gadget:GetInfo().name, LOG.WARNING, 'Did not find area weapon for ' .. def.name)
				return
			end

			local areaDuration = math.round(tonumber(def.customParams.area_duration or 0) / groupDuration)
			if not enableBriefAreas and areaDuration <= shortDuration then
				Spring.Log(gadget:GetInfo().name, LOG.INFO, 'Disabling brief-area effect on weapon ' .. def.name)
				return
			end

			local fullDamages = areaWeaponDef.damages
			local loopDamages = {}
			for ii = 0, #Game.armorTypes do
				if fullDamages[ii] and fullDamages[ii] > 0 then
					if not areaFlankDamage then
						-- A legbar-corcan test showed flanking adds ~1/6th excess damage on average.
						loopDamages[ii] = max(1, math.round(fullDamages[ii] * loopDuration / (1 + 1/6)))
					else
						loopDamages[ii] = max(1, math.round(fullDamages[ii] * loopDuration))
					end
				else
					loopDamages[ii] = 0
				end
			end
			loopDamages.damageAreaOfEffect = areaWeaponDef.damageAreaOfEffect
			loopDamages.edgeEffectiveness  = 1
			loopDamages.explosionSpeed     = 10000 * gameSpeed
			if fullDamages.impulseBoost and fullDamages.impulseBoost > 0 then
				loopDamages.impulseBoost = fullDamages.impulseBoost
			end
			if fullDamages.impulseFactor and fullDamages.impulseFactor > 0 then
				loopDamages.impulseFactor = fullDamages.impulseFactor * areaImpulseRate
			end
			if areaWeaponDef.paralyzer then
				loopDamages.paralyzeDamageTime = areaDamages.paralyzeDamageTime
			end

			-- Add two entries, one for the area trigger and one for the area weapon.
			triggerParams[defID] = {
				area_duration    = areaDuration,
				area_weapondefid = areaWeaponDef.id,
				area_weaponname  = areaWeaponDef.name,
				area_damages     = loopDamages,
				area_radius      = areaWeaponDef.damageAreaOfEffect / 2, -- diameter => radius
				area_damagetype  = string.lower(def.customParams.area_damagetype),
				area_ongoingceg  = def.customParams.area_ongoingceg,
				area_damagedceg  = def.customParams.area_damagedceg,
			}
			timedAreaParams[areaWeaponDef.id] = triggerParams[defID]
		end
	end
end

-- Cache the table params for SpawnExplosion.

local explosionCaches = {}

for _, triggerParams in ipairs({weaponTriggerParams, destroyTriggerParams}) do
	for entityID, params in pairs(triggerParams) do
		explosionCaches[params] = {
			weaponDef    = params.area_weapondefid,
			damages      = params.area_damages,
			damageGround = false,
			owner        = -1,
		}
	end
end

-- Build tables when enabled in the config.

local damageImmunities = {}
local ignoredFeatureDefs = {}
local shieldUnitParams = {}

if enableImmunities then
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.customParams.area_immunities then
			damageImmunities[unitDefID] = {}
			for word in unitDef.customParams.area_immunities:gmatch("[%w_]+") do
				damageImmunities[unitDefID][string.lower(word)] = true
			end
		end
	end
end

if reduceDamagedCEGs then
	for featureDefID, featureDef in ipairs(FeatureDefs) do
		if featureDef.customParams and featureDef.customParams.fromunit then
			ignoredFeatureDefs[featureDefID] = true
		end
	end
end

if shieldsDenyAreas then
	local suppressionCharge = 100
	local suppressionRadius = 100
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

-- Keep track of ongoing areas, delayed areas, and shield-carrying units.

local timedAreas = {}
local delayQueue = {}
local shieldUnits = {}

---------------------------------------------------------------------------------------------------------------
---- Functions

local function startTimedArea(x, y, z, weaponParams, ownerID)
	ownerID = ownerID or -1

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

		-- Most timed areas are represented by a long-duration CEG.
		-- The others use an explosiongenerator on the area weapon.
		if weaponParams.area_ongoingceg then
			local dx, dy, dz = Spring.GetGroundNormal(x, z)
			spSpawnCEG(
				weaponParams.area_ongoingceg,
				x, elevation, z,
				dx, dy, dz
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

		-- Spawn a single explosion in mid-air with no recurring area.
		else
			local explosion = explosionCaches[weaponParams]
			explosion.owner = ownerID ~= -1 and ownerID or nil
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
			explosion.owner = timedArea[3] ~= -1 and timedArea[3] or nil 
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

	time  = 1 + (math.floor(Spring.GetGameFrame() / frameResolution))
	frame = 1 + (math.floor(Spring.GetGameFrame() / frameResolution) % groupCount)
	ticks = 1 + (Spring.GetGameFrame() % frameResolution)

	timedAreas = {}
	delayQueue = {}
	shieldUnits = {}

	for ii = 1, groupCount do
		timedAreas[ii] = {}
	end

	if shieldsDenyAreas then
		for _, unitID in pairs(Spring.GetAllUnits()) do
			local unitDefID = Spring.GetUnitDefID(unitID)
			if unitDefID and shieldUnitParams[unitDefID] then
				shieldUnits[unitID] = shieldUnitParams[unitDefID]
			end
		end
	end
end

function gadget:GameFrame(gameFrame)
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
		local immunities = damageImmunities[unitDefID]
		if immunities and (immunities[timedAreaParams[weaponDefID].area_damagetype] or immunities.all) then
			return 0, 0
		end
	end
end

function gadget:FeaturePreDamaged(featureID, featureDefID, featureTeam, damage, weaponDefID, projID, attackID, attackDefID, attackTeam)
	if timedAreaParams[weaponDefID] then
		local damagedCEG = timedAreaParams[weaponDefID].area_damagedceg
		if not ignoredFeatureDefs[featureDefID] and damagedCEG then
			local _,_,_, x,y,z = spGetFeaturePosition(featureID, true)
			spSpawnCEG(damagedCEG, x, y + 18, z, 0, 0, 0, 0, damage)
		end
	end
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

if shieldsDenyAreas then
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
		table.insert(messages, 'test: '..text..' : '..name)
	end
	local function warnmsg(text, name)
		table.insert(messages, 'warn: '..text..' : '..name)
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

		-- Check for bad/missing damage types and immunities.
		local damageTypes = { 'acid', 'fire' }
		local immunities  = { 'acid', 'fire', 'raptor', 'friendly', 'all' } -- idk
		if isWeaponDef and not paramsTable[defID].area_damagetype then
			testmsg('Weapon is missing its damage type(acid/napalm/...)', areaDef.name)
		end
	end

	local function FixIssues(paramsTable, defID, def)
		local areaWeaponName = def.customParams.area_weaponname or def.name.."_"..defaultWeaponName
		local areaWeaponDef = WeaponDefNames[areaWeaponName]

		-- Remove misconfigured area triggers and weapons.
		local misconfigured = false
		if tonumber(def.customParams.area_duration * groupDuration) <= 1 / gameSpeed then
			warnmsg('Invalid area_duration', def.name)
			misconfigured = true
		end
		if def == areaWeaponDef then
			warnmsg('Removed self-respawning area weapon', def.name)
			misconfigured = true
		end

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
		Spring.Log(gadget:GetInfo().name, LOG.INFO,
			'unit_area_timed_damage test results: '..testMessages..' tests and '..warnMessages..' issues.')
		Spring.Log(gadget:GetInfo().name, LOG.INFO,
			'\n' .. table.concat(messages, '\n'))
	end
end
