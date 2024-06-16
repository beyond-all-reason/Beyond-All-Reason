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

-- Areas are binned into intervals and updated once per second.
local frame = 1
local areas = {}
local freed = {}
local empty = {}
for ii = 1, 30 do
	areas[ii] = {}
	freed[ii] = {}
end

---------------------------------------------------------------------------------------------------------------

local function StartTimedArea(x, y, z, weaponParams)
	local elevation = math.max(0, Spring.GetGroundHeight(x, z))
	if y <= elevation + weaponParams.atd_radius * 0.5 then
		-- This interval won't recur for another 30 frames; if you want immediate damage
		-- on contact, you have to put it in the base weapon.
		local group = areas[frame]
		local holes = freed[frame]

		local index
		if #holes then
			index = holes[#holes]
			holes[#holes] = nil
		else
			index = #group + 1
		end

		group[index] = {
			weaponParams = weaponParams,
			endTime = weaponParams.area_duration + Spring.GetGameTime(),
			x = x,
			y = elevation,
			z = z,
		}

		Spring.SpawnCEG(
			weaponParams.area_ongoingCEG,
			x, elevation, z,
			0, 0, 0,
			weaponParams.area_weaponDef.damageAreaOfEffect, -- Just used for scaling?
			weaponParams.area_weaponDef.damages[0]          -- Just used for scaling?
		)
	end
end

local function StopTimedArea(group, index)
	if index == #group then
		group[#group] = nil
	else
		group[index] = empty
		freed[#freed + 1] = index
	end
end

local function UpdateTimedAreas()
	local frameAreas = areas[frame]
	local frameRate = Spring.GetGameSpeed()
	local frameTime = Spring.GetGameSeconds() - 0.5 / frameRate
	-- local damageRate = 30 / frameRate -- todo

	local explosion = {
		weaponDef          = 0, -- todo: Great. Now I gotta make a weapon for all of these.
		edgeEffectiveness  = 1,
		explosionSpeed     = 10000,
		damageGround       = false,
	}

	-- Deal recurring damage by spawning explosions.
	for index = #frameAreas, 1, -1 do
		local timedArea = frameAreas[index]
		if timedArea ~= empty then
			if timedArea.endTime > frameTime then
				-- todo: Will napalm/acid destroy shields now? Troubling thought.
				explosion.weaponDef = timedArea.params.area_weaponDef
				Spring.SpawnExplosion(timedArea.x, timedArea.y, timedArea.z, 0, 0, 0, explosion)
			else
				StopTimedArea(frameAreas, index)
			end
		end
	end
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
	-- Bin frames into intervals over the range [1, 30]:
	frame = (gameFrame % 30) + 1
	UpdateTimedAreas()
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
