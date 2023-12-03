function gadget:GetInfo()
	return {
		name = "Continuous Aim",
		desc = "Applies lower 'reaimTime for continuous aim'",
		author = "Doo, Beherith",
		date = "April 2018",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true, -- When we will move on 105 :)
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end


local convertedUnits = {
	-- value is reaimtime in frames, engine default is 15
	--[UnitDefNames.armart.id] = true,
	[UnitDefNames.armfav.id] = 3,
	--[UnitDefNames.armflash.id] = true,
	--[UnitDefNames.armjanus.id] = true,
	--[UnitDefNames.armpincer.id] = true,
	--[UnitDefNames.armsam.id] = true,
	--[UnitDefNames.armstump.id] = true,
	[UnitDefNames.armbeamer.id] = 3,
	[UnitDefNames.armpw.id] = 2,
	[UnitDefNames.armpwt4.id] = 2,
	[UnitDefNames.armflea.id] = 2,
	[UnitDefNames.armrock.id] = 2,
	[UnitDefNames.armham.id] = 2,
	[UnitDefNames.armwar.id] = 2,
	[UnitDefNames.armjeth.id] = 2,
	[UnitDefNames.corfav.id] = 3,
	--[UnitDefNames.corgarp.id] = true,
	--[UnitDefNames.corgator.id] = true,
	--[UnitDefNames.corlevlr.id] = true,
	--[UnitDefNames.cormist.id] = true,
	--[UnitDefNames.corraid.id] = true,
	--[UnitDefNames.corwolv.id] = true,
	[UnitDefNames.corak.id] = 2,
	[UnitDefNames.corthud.id] = 2,
	[UnitDefNames.corstorm.id] = 2,
	[UnitDefNames.corcrash.id] = 5,
	[UnitDefNames.legkark.id] = 2,
	[UnitDefNames.armsnipe.id] = 2,
	[UnitDefNames.armfido.id] = 3,
	[UnitDefNames.armfboy.id] = 2,
	[UnitDefNames.armfast.id] = 2,
	[UnitDefNames.armamph.id] = 3,
	[UnitDefNames.armmav.id] = 2,
	[UnitDefNames.armspid.id] = 3,
	[UnitDefNames.armsptk.id] = 5,
	[UnitDefNames.armzeus.id] = 3,
	[UnitDefNames.coramph.id] = 3,
	[UnitDefNames.corcan.id] = 2,
	[UnitDefNames.corhrk.id] = 5,
	[UnitDefNames.cormando.id] = 2,
	[UnitDefNames.cormort.id] = 2,
	[UnitDefNames.corpyro.id] = 2,
	--[UnitDefNames.corsumo.id] = true,
	[UnitDefNames.cortermite.id] = 2,
	[UnitDefNames.armraz.id] = 2,
	[UnitDefNames.armmar.id] = 3,
	[UnitDefNames.armbanth.id] = 1,
	[UnitDefNames.corkorg.id] = 1,
	--[UnitDefNames.corkarg.id] = true,
	--[UnitDefNames.corjugg.id] = true,
	[UnitDefNames.armvang.id] = 3,

	-- the following units get a faster reaimtime to counteract their turret acceleration
	[UnitDefNames.armflash.id] = 6,
	[UnitDefNames.corgator.id] = 6,
	[UnitDefNames.armdecade.id] = 6,
	[UnitDefNames.coresupp.id] = 6,
	[UnitDefNames.corhlt.id] = 5,
	[UnitDefNames.corfhlt.id] = 5,
	[UnitDefNames.cordoom.id] = 5,
	[UnitDefNames.corshiva.id] = 5,
	[UnitDefNames.corcat.id] = 5,
	[UnitDefNames.corkarg.id] = 5,
	[UnitDefNames.corbhmth.id] = 5,
	[UnitDefNames.armguard.id] = 5,
	[UnitDefNames.armamb.id] = 5,
	[UnitDefNames.corpun.id] = 5,
	[UnitDefNames.cortoast.id] = 5,
	[UnitDefNames.corbats.id] = 5,
	[UnitDefNames.corblackhy.id] = 5,
	[UnitDefNames.corscreamer.id] = 5,
	[UnitDefNames.corcom.id] = 5,
	[UnitDefNames.armcom.id] = 5,
	[UnitDefNames.cordecom.id] = 5,
	[UnitDefNames.armdecom.id] = 5,
	[UnitDefNames.legbal.id] = 5,
	[UnitDefNames.legcen.id] = 2,
	[UnitDefNames.leggat.id] = 5,
	[UnitDefNames.leggob.id] = 5,
	[UnitDefNames.leginc.id] = 10,
	[UnitDefNames.cordemont4.id] = 6,
	[UnitDefNames.corcrwh.id] = 7,
	[UnitDefNames.leglob.id] = 5,
	[UnitDefNames.legmos.id] = 5,
	[UnitDefNames.leghades.id] = 5,
	[UnitDefNames.leghelios.id] = 5,
	[UnitDefNames.legrail.id] = 5,
	[UnitDefNames.legbar.id] = 5,
	[UnitDefNames.legcomoff.id] = 5,
	[UnitDefNames.legcomt2off.id] = 5,
	[UnitDefNames.legcomt2com.id] = 5,
	[UnitDefNames.legstr.id] = 5,
	[UnitDefNames.legbart.id] = 5,
	[UnitDefNames.legmrv.id] = 5,
	[UnitDefNames.legsco.id] = 5,
	[UnitDefNames.legcom.id] = 5,
	[UnitDefNames.legcomlvl2.id] = 5,
	[UnitDefNames.legcomlvl3.id] = 5,
	[UnitDefNames.legcomlvl4.id] = 5,
	[UnitDefNames.leegmech.id] = 5,
}


local spamUnitsTeams = { --{unitDefID = {teamID = totalcreated,...}}
	[UnitDefNames.armpw.id] = {},
	[UnitDefNames.armflea.id]  = {},
	[UnitDefNames.armfav.id]  = {},
	[UnitDefNames.corak.id]  = {},
	[UnitDefNames.corfav.id]  = {},
}

local spamUnitsTeamsReaimTimes = {} --{unitDefID = {teamID = currentReAimTime,...}}


-- for every spamThreshold'th spammable unit type built by this team, increase reaimtime by 1 for that team
local spamThreshold = 100 
local maxReAimTime = 15

-- add for scavengers copies
local convertedUnitsCopy = table.copy(convertedUnits)
for id, v in pairs(convertedUnitsCopy) do
	if UnitDefNames[UnitDefs[id].name..'_scav'] then
		convertedUnits[UnitDefNames[UnitDefs[id].name..'_scav'].id] = v
	end
end

local spamUnitsTeamsCopy = table.copy(spamUnitsTeams)
for id,v in pairs(spamUnitsTeamsCopy) do 
	if UnitDefNames[UnitDefs[id].name..'_scav'] then
		spamUnitsTeams[UnitDefNames[UnitDefs[id].name..'_scav'].id] = {}
	end
end

for unitDefID, _ in pairs(spamUnitsTeams) do 
	spamUnitsTeamsReaimTimes[unitDefID] = {}
end

local unitWeapons = {}
for unitDefID, _ in pairs(convertedUnits) do 
	local unitDef = UnitDefs[unitDefID] 
	if unitDef then 
		local weapons = unitDef.weapons
		if #weapons > 0 then
			unitWeapons[unitDefID] = {}
			for id, _ in pairs(weapons) do
				unitWeapons[unitDefID][id] = true	-- no need to store weapondefid
			end
		else 
			-- units with no weapons shouldnt even be here
			convertedUnits[unitDefID] = nil
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
	if convertedUnits[unitDefID] then
		local currentReaimTime = convertedUnits[unitDefID]
		
		if spamUnitsTeams[unitDefID] then 
			if not spamUnitsTeams[unitDefID][teamID] then 
				-- initialize for this team at base defaults
				spamUnitsTeams[unitDefID][teamID] = 1
				spamUnitsTeamsReaimTimes[unitDefID][teamID] = convertedUnits[unitDefID]
			else
				local spamCount = spamUnitsTeams[unitDefID][teamID] + 1
				spamUnitsTeams[unitDefID][teamID] = spamCount
				currentReaimTime = spamUnitsTeamsReaimTimes[unitDefID][teamID]
				if spamCount % spamThreshold == 0 and currentReaimTime < maxReAimTime then 
					spamUnitsTeamsReaimTimes[unitDefID][teamID] = currentReaimTime + 1
					--Spring.Echo("Unit type", unitDefID,'has been built', spamCount, 'times by team', teamID,'increasing reaimtime to ', currentReaimTime + 1)
				end
			end
		end
		if currentReaimTime < 15 then 
			for id, _ in pairs(unitWeapons[unitDefID]) do
				-- NOTE: this will prevent unit from firing if it does not IMMEDIATELY return from AimWeapon (no sleeps, not wait for turns!)
				-- So you have to manually check in script if it is at the desired heading
				-- https://springrts.com/phpbb/viewtopic.php?t=36654
				Spring.SetUnitWeaponState(unitID, id, "reaimTime", currentReaimTime)
			end
		end
	end
end
