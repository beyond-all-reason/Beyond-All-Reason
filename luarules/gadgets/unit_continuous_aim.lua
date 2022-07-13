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
	[UnitDefNames.armpw.id] = 2,
	[UnitDefNames.armpwt4.id] = 2,
	[UnitDefNames.armflea.id] = 2,
	[UnitDefNames.armrock.id] = 2,
	[UnitDefNames.armham.id] = 2,
	[UnitDefNames.armwar.id] = 2,
	[UnitDefNames.armjeth.id] = 2,
	--[UnitDefNames.corfav.id] = true,
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
	[UnitDefNames.corkark.id] = 2,
	[UnitDefNames.armsnipe.id] = 2,
	[UnitDefNames.armfido.id] = 2,
	[UnitDefNames.armfboy.id] = 2,
	[UnitDefNames.armfast.id] = 2,
	[UnitDefNames.armamph.id] = 3,
	[UnitDefNames.armmav.id] = 2,
	[UnitDefNames.armspid.id] = 3,
	[UnitDefNames.armsptk.id] = 5,
	[UnitDefNames.armzeus.id] = 3,
	[UnitDefNames.coramph.id] = 2,
	[UnitDefNames.corcan.id] = 2,
	[UnitDefNames.corhrk.id] = 5,
	[UnitDefNames.cormando.id] = 2,
	[UnitDefNames.cormort.id] = 2,
	[UnitDefNames.corpyro.id] = 2,
	--[UnitDefNames.corsumo.id] = true,
	[UnitDefNames.cortermite.id] = 2,
	[UnitDefNames.armraz.id] = 2,
	[UnitDefNames.armmar.id] = 1,
	[UnitDefNames.armbanth.id] = 1,
	[UnitDefNames.corkorg.id] = 1,
	--[UnitDefNames.corkarg.id] = true,
	--[UnitDefNames.corjugg.id] = true,
	[UnitDefNames.armvang.id] = 2,

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
}

-- add for scavengers copies
local convertedUnitsCopy = table.copy(convertedUnits)
for id, v in pairs(convertedUnitsCopy) do
	if UnitDefNames[UnitDefs[id].name..'_scav'] then
		convertedUnits[UnitDefNames[UnitDefs[id].name..'_scav'].id] = v
	end
end

local unitWeapons = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local weapons = unitDef.weapons
	if #weapons > 0 then
		unitWeapons[unitDefID] = {}
		for id, _ in pairs(weapons) do
			unitWeapons[unitDefID][id] = true	-- no need to store weapondefid
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
