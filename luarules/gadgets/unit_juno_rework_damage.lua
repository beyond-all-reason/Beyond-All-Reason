local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = 'Juno Rework Damage',
		desc = 'Handles Juno damage',
		author = 'Niobium, Bluestone, Hornet',--rework by Hornet, elements of older Juno code from prior authors
		version = 'v3.0',
		date = '05/2024',--original 05/2013
		license = 'GNU GPL, v2 or later',
		layer = 0,
		enabled = Spring.GetModOptions().junorework
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then



--hornet todo;
--deploy to juno_mini_damage when mechanics sorted
--tarpit pawns & grunts possibly. code added but glitched for now.



	----------------------------------------------------------------
	-- Config
	----------------------------------------------------------------


local tokillUnitsNames = {
		['corfav'] = true,
		['armfav'] = true,
		['armflea'] = true,
		['legscout'] = true,
		['raptor_land_swarmer_brood_t2_v1'] = true,
		['raptor_land_kamikaze_basic_t2_v1'] = true,
		['raptor_land_kamikaze_emp_t2_v1'] = true,
		['raptor_land_kamikaze_basic_t4_v1'] = true,
		['raptor_land_kamikaze_emp_t4_v1'] = true,
}

--emp these
local toStunUnitsNames = {--this could maybe use customparams later, at least in part to detect mines
		['armarad'] = true,
		['armaser'] = true,
		['armason'] = true,
		['armfrad'] = true,
		['armjam'] = true,
		['armjamt'] = true,
		['armmark'] = true,
		['armrad'] = true,
		['armseer'] = true,
		['armsjam'] = true,
		['armsonar'] = true,
		['armveil'] = true,
		['corarad'] = true,
		['corason'] = true,
		['coreter'] = true,
		['corfrad'] = true,
		['corjamt'] = true,
		['corrad'] = true,
		['corshroud'] = true,
		['corsjam'] = true,
		['corsonar'] = true,
		['corspec'] = true,
		['corvoyr'] = true,
		['corvrad'] = true,

		['coreyes'] = true,
		['armeyes'] = true,
		['armmine1'] = true,
		['armmine2'] = true,
		['armmine3'] = true,
		['cormine1'] = true,
		['cormine2'] = true,
		['cormine3'] = true,
		['armfmine3'] = true,		
		['corfmine3'] = true,
		['legmine1'] = true,
		['legmine2'] = true,
		['legmine3'] = true,

}


local stunDuration = Spring.GetModOptions().emprework and 32 or 30
--hornet todo, might leave this to be decided by EMP settings and just max it out?


local toTarpitUnitsNames = {
	['corak'] = true,
	['armpw'] = true,
	['leggob'] = true,
}

local todenyUnitsNames = {
	['corfav'] = true,
	['armfav'] = true,
	['armflea'] = true,
	['raptor_land_swarmer_brood_t2_v1'] = true,
	['raptor_land_kamikaze_basic_t2_v1'] = true,
	['raptor_land_kamikaze_emp_t2_v1'] = true,
	['raptor_land_kamikaze_basic_t4_v1'] = true,
	['raptor_land_kamikaze_emp_t4_v1'] = true,
}


	-- convert unitname -> unitDefID
	local tokillUnits = {}
	for name, params in pairs(tokillUnitsNames) do
		if UnitDefNames[name] then
			tokillUnits[UnitDefNames[name].id] = params
		end
	end
	tokillUnitsNames = nil
	-- convert unitname -> unitDefID
	local todenyUnits = {}
	for name, params in pairs(todenyUnitsNames) do
		if UnitDefNames[name] then
			todenyUnits[UnitDefNames[name].id] = params
		end
	end
	todenyUnitsNames = nil
	-- convert unitname -> unitDefID
	local toStunUnits = {}
	for name, params in pairs(toStunUnitsNames) do
		if UnitDefNames[name] then
			toStunUnits[UnitDefNames[name].id] = params
		end
	end
	toStunUnitsNames = nil
	--[[
	--WiP, works but has bug outlined below, out of time to chase in circles for now
	local toTarpitUnits = {}
	for name, params in pairs(toTarpitUnitsNames) do
		if UnitDefNames[name] then
			toTarpitUnits[UnitDefNames[name].id] = params
		end
	end
	toTarpitUnitsNames = nil
	--]]




	for udid, ud in pairs(UnitDefs) do
		for id, v in pairs(tokillUnits) do
			if string.find("_scav", ud.name) and string.sub(UnitDefs[id].name, 1, -5) == ud.name then
			--if string.find(ud.name, UnitDefs[id].name) then
				tokillUnits[udid] = v
			end
		end
		for id, v in pairs(todenyUnits) do
			if string.find("_scav", ud.name) and string.sub(UnitDefs[id].name, 1, -5) == ud.name then
			--if string.find(ud.name, UnitDefs[id].name) then
				todenyUnits[udid] = v
			end
		end
		for id, v in pairs(toStunUnits) do
			if string.find("_scav", ud.name) and string.sub(UnitDefs[id].name, 1, -5) == ud.name then
			--if string.find(ud.name, UnitDefs[id].name) then
				toStunUnits[udid] = v
			end
		end

	end


	--config -- see also in unsynced
	local radius = 450 --outer radius of area denial ring
	local width = 30 --width of area denial ring
	local effectlength = 30 --how long area denial lasts, in seconds
	local fadetime = 2 --how long fade in/out effect lasts, in seconds

	--locals
	local SpGetGameSeconds = Spring.GetGameSeconds
	local SpGetUnitsInCylinder = Spring.GetUnitsInCylinder
	local SpDestroyUnit = Spring.DestroyUnit
	local SpGetUnitDefID = Spring.GetUnitDefID
	local SpValidUnitID = Spring.ValidUnitID
	local Mmin = math.min


	-- kill appropriate things from initial juno blast --

	local junoWeaponsNames = {
		["armjuno_juno_pulse"] = true,
		["corjuno_juno_pulse"] = true,
		["legjuno_juno_pulse"] = true,
		["armjuno_scav_juno_pulse"] = true,
		["corjuno_scav_juno_pulse"] = true,
		["legjuno_scav_juno_pulse"] = true,
	}
	-- convert unitname -> unitDefID
	local junoWeapons = {}
	for name, params in pairs(junoWeaponsNames) do
		if WeaponDefNames[name] then
			junoWeapons[WeaponDefNames[name].id] = params
		end
	end
	junoWeaponsNames = nil

	function gadget:UnitDamaged(uID, uDefID, uTeam, damage, paralyzer, weaponID, projID, aID, aDefID, aTeam)

		
		--[[
		if junoWeapons[weaponID] and toTarpitUnits[uDefID] and aID~=99 then
			if uID and SpValidUnitID(uID) then
				local px, py, pz = Spring.GetUnitPosition(uID)
				if px then
					Spring.SpawnCEG("juno-damage", px, py + 8, pz, 0, 1, 0)
				end
				
				local health, maxHealth, paralyzeDamage, capture, build = Spring.GetUnitHealth(uID)
				Spring.AddUnitDamage (uID, maxHealth/2, 5, 99, aDefID)
			end
		end--]]--

		if junoWeapons[weaponID] and toStunUnits[uDefID] and aID~=99 and (paralyzer == false) then--needed to stop possible loops
			if uID and SpValidUnitID(uID) then
				local px, py, pz = Spring.GetUnitPosition(uID)
				if px then
					Spring.SpawnCEG("juno-damage", px, py + 8, pz, 0, 1, 0)
				end
				
				local health, maxHealth, paralyzeDamage, capture, build = Spring.GetUnitHealth(uID)
				Spring.AddUnitDamage (uID, maxHealth*3, stunDuration, 99, weaponID)--no weapon ID, no stun. with weapon ID, infinite loops, even with the 99 exclusion. -1 does not work.
				--aID check removed as -probably- only useful for kill crediting?

			end
		end
	
		if junoWeapons[weaponID] and tokillUnits[uDefID] then
			if uID and SpValidUnitID(uID) then
				local px, py, pz = Spring.GetUnitPosition(uID)
				if px then
					Spring.SpawnCEG("juno-damage", px, py + 8, pz, 0, 1, 0)
				end
				if aID and SpValidUnitID(aID) then
					SpDestroyUnit(uID, false, false, aID)
				else
					SpDestroyUnit(uID, false, false) -- leavewreck, makeselfdexplosion
				end
			end
		end
	end

	-- area denial --
	local centers = {} --table of where juno missiles hit etc
	local counter = 1 --index each explosion of juno missile with this counter

	function gadget:Initialize()
		if WeaponDefNames.armjuno_juno_pulse then
			Script.SetWatchExplosion(WeaponDefNames.armjuno_juno_pulse.id, true)
		end
		if WeaponDefNames.corjuno_juno_pulse then
			Script.SetWatchExplosion(WeaponDefNames.corjuno_juno_pulse.id, true)
		end
		if WeaponDefNames.legjuno_juno_pulse then
			Script.SetWatchExplosion(WeaponDefNames.legjuno_juno_pulse.id, true)
		end
	end

	function gadget:Explosion(weaponID, px, py, pz, ownerID)
		if junoWeapons[weaponID] then
			local curtime = SpGetGameSeconds()
			local junoExpl = { x = px, y = py, z = pz, t = curtime, o = ownerID }
			centers[counter] = junoExpl
			--SendToUnsynced("AddToCenters", counter, px, py, pz, curtime)
			counter = counter + 1
		end
	end

	local lastupdate = -1
	local updatespersec = 30
	local updategrain = 1 / updatespersec
	local update = true

	function gadget:GameFrame(frame)
		--if frame == 10 then
		--seems that SendToUnsynced has to happen after
		--SendToUnsynced("RecieveConstants", width, radius, effectlength, fadetime)
		--end

		local curtime = SpGetGameSeconds()

		if Spring.GetGameFrame() % 15 == 0 then

			for counter, expl in pairs(centers) do
				if expl.t >= curtime - effectlength then
					local q = 1
					if expl.t + effectlength - fadetime <= curtime and curtime <= expl.t + effectlength then
						q = (1 / fadetime) * Mmin(curtime - expl.t, expl.t + effectlength - curtime)
					end

					local unitIDsBig = SpGetUnitsInCylinder(expl.x, expl.z, q * radius)

					for i = 1, #unitIDsBig do
						-- linear and not O(n^2)
						local unitID = unitIDsBig[i]
						local unitDefID = SpGetUnitDefID(unitID)
						if todenyUnits[unitDefID] then
							local px, py, pz = Spring.GetUnitPosition(unitID)
							local dx = expl.x - px
							local dz = expl.z - pz
							if (dx * dx + dz * dz) > (q * (radius - width)) * (q * (radius - width)) then
								-- linear and not O(n^2)
								Spring.SpawnCEG("juno-damage", px, py + 8, pz, 0, 1, 0)
								SpDestroyUnit(unitID, true, false)
							end
						end

						
						if toStunUnits[unitDefID] then
							local px, py, pz = Spring.GetUnitPosition(unitID)
							local dx = expl.x - px
							local dz = expl.z - pz

							--does the cyl search above not already do this...?
							if (dx * dx + dz * dz) > (q * (radius - width)) * (q * (radius - width)) then
								-- linear and not O(n^2)
								local health, maxHealth, paralyzeDamage, capture, build = Spring.GetUnitHealth(unitID)
								--Spring.Echo(paralyzeDamage, maxHealth*1.2)
								if (paralyzeDamage < maxHealth*1.2) then--try to prevent excessive stun times, also needless restuns 
									Spring.AddUnitDamage (unitID, maxHealth*2, 5, 99, WeaponDefNames["corjuno_juno_pulse_ghost"].id)---...close enough?
									Spring.SpawnCEG("juno-damage", px, py + 8, pz, 0, 1, 0)
								end
	
								--SpDestroyUnit(unitID, true, false)
							end
						end

						--[[
						--this mostly works but has a loop I can't chase out atm, and some weirdness at the end of the effect that applies a stun all over again
						if toTarpitUnits[unitDefID] and Spring.GetModOptions().emprework then--useless without it, just adds visual noise
							local px, py, pz = Spring.GetUnitPosition(unitID)
							local dx = expl.x - px
							local dz = expl.z - pz
							if (dx * dx + dz * dz) > (q * (radius - width)) * (q * (radius - width)) then
								-- linear and not O(n^2)
								Spring.SpawnCEG("juno-damage", px, py + 8, pz, 0, 1, 0)
								local health, maxHealth, paralyzeDamage, capture, build = Spring.GetUnitHealth(unitID)
								Spring.AddUnitDamage (unitID, maxHealth*2, 5, 99, WeaponDefNames["corjuno_juno_pulse_ghost"].id)---...close enough?
							end
						end--]]--
					end
				else
					--SendToUnsynced("RemoveFromCenters", counter)
					table.remove(centers, counter)
				end

				if expl.t + fadetime >= curtime or expl.t + effectlength - fadetime <= curtime and curtime <= expl.t + effectlength then
					update = true -- fast update during fade in/out
				end

			end
		end

		if #centers ~= 0 and curtime - lastupdate > 1 then
			--slow update (to re-match ground in unsync)
			update = true
		end

		if update == true and curtime - lastupdate > updategrain then
			lastupdate = curtime
			--SendToUnsynced("UpdateList", curtime)
			update = false
		end
	end





end

