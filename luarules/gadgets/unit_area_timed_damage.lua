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
-- Unit setup -- ! todo: Do this for all the units with area timed damage
--
-- (1) CustomParams. Add these properties to the unit (for ondeath) or weapon (for onhit).
--
-- area_timed_damage  -  true            -  Required.
--    atd_duration    -  <number>        -  Required. The duration of the effect.
--    atd_stable_ceg  -  <string> | nil  -  Name of the CEG that appears continuously for the duration.
--    atd_damage_ceg  -  <string> | nil  -  Name of the CEG that appears on anything damaged by the effect.
--    atd_resistance  -  <string> | nil  -  The 'type' of the damage, which can be resisted. Be uncreative.
--
-- (2) WeaponDefs. Add a new weapondef with its name set to:
--		(a) the base weapon name plus "_area" for a specific weapon, and/or
--		(b) "area_timed_damage" for an on-death hazard or any unmatched weapons; that is, if only the
--			weapondef "area_timed_damage" is provided, it will be used both for any weapons without a
--			matching name.."_area" weapondef and for the on-death explosion, if any.
--
--	Only a few properties of this wdef are used -- those that modify explosions:
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
---------------------------------------------------------------------------------------------------------------

local WeaponAreaDefs  = {}
local OnDeathAreaDefs = {}
local TimedAreaDefs   = {}

local function AddTimedAreaDef(id, def)
	if not def.customParams or not def.customParams.area_timed_damage == true then return end
	local isUnitDef = UnitDefNames[def.name] and true or false

	-- SpawnExplosion needs a weapondef entry to do its thing:
	local areaWeaponDef
	if isUnitDef then
		areaWeaponDef = WeaponDefNames[def.name .. "_area_timed_damage"]
	else
		areaWeaponDef = WeaponDefNames[def.name .. "_area"]
		if not areaWeaponDef then
			local name = ""
			for word in string.gmatch(def.name, "([^_]+)") do
				name = name == "" and word or name.."_"..word
				if UnitDefNames[name] and WeaponDefNames[name.."_area_timed_damage"] then
					areaWeaponDef = WeaponDefNames[name.."_area_timed_damage"]
				end
			end
		end
	end
	if not areaWeaponDef then
		Spring.Echo('[area_timed_damage] [warn] Did not find area weapon for ' .. def.name)
		return
	end
	def.atd_wdef = areaWeaponDef -- can cycle

	-- Add the definitions.
	if isUnitDef then
		OnDeathAreaDefs[id] = def.customParams
	else
		WeaponAreaDefs[id] = def.customParams
	end
	TimedAreaDefs[areaWeaponDef.id] = def.customParams

	-- Remove invalid durations.
	local thing = (isUnitDef and 'udef ' or 'wdef ') .. def.name
	if not def.customParams.atd_duration or def.customParams.atd_duration < 0 then
		Spring.Echo('[area_timed_damage] [warn] Invalid atd_duration for ' .. thing)
		AreaTable[id] = nil
	end
end

for wdid, wdef in pairs(WeaponDefs) do
	AddTimedAreaDef(wdid, wdef)
end

for udid, udef in pairs(UnitDefs) do
	AddTimedAreaDef(udid, udef)
end

-- Areas are binned into intervals and updated once per second.
local areas = {}
local freed = {}
local empty = {}
for ii = 1, 30 do
	areas[ii] = {}
	freed[ii] = {}
end

---------------------------------------------------------------------------------------------------------------

local function StartTimedArea(x, y, z, params)
	if not params then return end

	local elevation = Spring.GetGroundHeight(x, z)
	elevation = elevation < 0 and 0 or elevation
	if y <= elevation + params.atd_radius * 0.5 then
		-- This interval won't recur for another 30 frames; if you want immediate damage
		-- on contact, you have to put it in the base weapon.
		local frame = Spring.GetGameFrame() % 30
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
			params  = params,
			endTime = params.atd_duration + Spring.GetGameTime(),
			x = x,
			y = elevation,
			z = z,
		}

		Spring.SpawnCEG(
			params.atd_stable_ceg,
			x, elevation, z,
			0, 0, 0,
			params.atd_wdef.damageAreaOfEffect, -- Just used for scaling?
			params.atd_wdef.damages[0]          -- Just used for scaling?
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

local function UpdateTimedAreas(frame)
	local frameAreas = areas[frame % 30]
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
				explosion.weaponDef = timedArea.params.atd_wdef
				Spring.SpawnExplosion(timedArea.x, timedArea.y, timedArea.z, 0, 0, 0, explosion)
			else
				StopTimedArea(frameAreas, index)
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------

function gadget:Initialize()
	for wdid, _ in pairs(WeaponAreaDefs) do
		Script.SetWatchExplosion(wdid, true)
	end
end

function gadget:Explosion(weaponDefID, px, py, pz, attackerID, projectileID)
	local params = WeaponAreaDefs[weaponDefID]
	StartTimedArea(px, py, pz, params)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	local params = OnDeathAreaDefs[unitDefID]
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	StartTimedArea(ux, uy, uz, params)
end

function gadget:GameFrame(frame)
	UpdateTimedAreas(frame)
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
	local params = TimedAreaDefs[weaponDefID]
	if params then
		local unitDef = UnitDefs[unitDefID]
		local immunity = unitDef.customParams.areadamageresistance
		if immunity and string.find(immunity, params.atd_resistance, 1, true) then
			return 0, 0
		elseif params.atd_damage_ceg then
			local _,_,_, x,y,z = Spring.GetUnitPosition(unitID, true)
			Spring.SpawnCEG(params.atd_damage_ceg, x, y + 8, z, 0, 0, 0, 0, damage)
			-- return damage * damageRate, impulse * impulseRate
		end
	end
	return damage, 1
end

function gadget:FeaturePreDamaged(featureID, featureTeam, damage, weaponDefID, projID, attackID, attackDefID, attackTeam)
	local params = TimedAreaDefs[weaponDefID]
	if params and params.atd_damage_ceg then
		local _,_,_, x,y,z = Spring.GetFeaturePosition(featureID, true)
		Spring.SpawnCEG(params.atd_damage_ceg, x, y + 8, z, 0, 0, 0, 0, damage)
	end
	return damage, 1
end
