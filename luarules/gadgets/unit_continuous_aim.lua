function gadget:GetInfo()
	return {
		name = "Continuous Aim",
		desc = "Applies lower 'reaimTime for continuous aim'",
		author = "Doo",
		date = "April 2018",
		license = "Whatever works",
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
	--[UnitDefNames.armfav.id] = true,
	--[UnitDefNames.armflash.id] = true,
	--[UnitDefNames.armjanus.id] = true,
	--[UnitDefNames.armpincer.id] = true,
	--[UnitDefNames.armsam.id] = true,
	--[UnitDefNames.armstump.id] = true,
	[UnitDefNames.armpw.id] = 1,
	[UnitDefNames.armflea.id] = 1,
	[UnitDefNames.armrock.id] = 1,
	[UnitDefNames.armham.id] = 1,
	[UnitDefNames.armwar.id] = 1,
	[UnitDefNames.armjeth.id] = 1,
	--[UnitDefNames.corfav.id] = true,
	--[UnitDefNames.corgarp.id] = true,
	--[UnitDefNames.corgator.id] = true,
	--[UnitDefNames.corlevlr.id] = true,
	--[UnitDefNames.cormist.id] = true,
	--[UnitDefNames.corraid.id] = true,
	--[UnitDefNames.corwolv.id] = true,
	[UnitDefNames.corak.id] = 1,
	[UnitDefNames.corthud.id] = 1,
	[UnitDefNames.corstorm.id] = 1,
	[UnitDefNames.corcrash.id] = 1,
	[UnitDefNames.armsnipe.id] = 1,
	[UnitDefNames.armfido.id] = 1,
	[UnitDefNames.armfboy.id] = 1,
	[UnitDefNames.armfast.id] = 1,
	[UnitDefNames.armamph.id] = 1,
	[UnitDefNames.armmav.id] = 1,
	[UnitDefNames.armspid.id] = 1,
	[UnitDefNames.armzeus.id] = 1,
	[UnitDefNames.coramph.id] = 1,
	[UnitDefNames.corcan.id] = 1,
	[UnitDefNames.corhrk.id] = 1,
	[UnitDefNames.cormando.id] = 1,
	[UnitDefNames.cormort.id] = 1,
	[UnitDefNames.corpyro.id] = 1,
	--[UnitDefNames.corsumo.id] = true,
	[UnitDefNames.cortermite.id] = 1,
	[UnitDefNames.armraz.id] = 1,
	[UnitDefNames.armmar.id] = 1,
	[UnitDefNames.armbanth.id] = 1,
	[UnitDefNames.corkorg.id] = 1,
	--[UnitDefNames.corkarg.id] = true,
	--[UnitDefNames.corjugg.id] = true,
	[UnitDefNames.armvang.id] = 1,

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
}

for udid, ud in pairs(UnitDefs) do
	for id, v in pairs(convertedUnits) do
		if string.find(ud.name, UnitDefs[id].name) then
			convertedUnits[udid] = v
		end
	end
end

local unitWeapons = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.scriptName == "scripts/BASICTANKSCRIPT.LUA" then
		convertedUnits[unitDefID] = true
	end
	if #unitDef.weapons > 0 then
		for id, table in pairs(unitDef.weapons) do
			if not unitWeapons[unitDefID] then
				unitWeapons[unitDefID] = {}
			end
			unitWeapons[unitDefID][id] = table.weaponDef
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if convertedUnits[unitDefID] and unitWeapons[unitDefID] then
		for id, _ in pairs(unitWeapons[unitDefID]) do
			-- NOTE: this will prevent unit from firing if it does not IMMEDIATELY return from AimWeapon (no sleeps, not wait for turns!)
			-- So you have to manually check in script if it is at the desired heading
			-- https://springrts.com/phpbb/viewtopic.php?t=36654
			Spring.SetUnitWeaponState(unitID, id, "reaimTime", convertedUnits[unitDefID])
		end
	end
end
