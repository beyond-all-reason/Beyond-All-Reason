    function gadget:GetInfo()
      return {
        name      = "Continuous Aim",
        desc      = "Applies lower 'reaimTime for continuous aim'",
        author    = "Doo",
        date      = "April 2018",
        license   = "Whatever works",
        layer     = 0,
        enabled   = true, -- When we will move on 105 :)
      }
    end
if (not gadgetHandler:IsSyncedCode()) then return end

local convertedUnits = {
	--[UnitDefNames.armart.id] = true,
	--[UnitDefNames.armfav.id] = true,
	--[UnitDefNames.armflash.id] = true,
	--[UnitDefNames.armjanus.id] = true,
	--[UnitDefNames.armpincer.id] = true,
	--[UnitDefNames.armsam.id] = true,
	--[UnitDefNames.armstump.id] = true,
	[UnitDefNames.armpw.id] = true,
	[UnitDefNames.armflea.id] = true,
	[UnitDefNames.armrock.id] = true,
	[UnitDefNames.armham.id] = true,
	[UnitDefNames.armwar.id] = true,
	[UnitDefNames.armjeth.id] = true,
	--[UnitDefNames.corfav.id] = true,
	--[UnitDefNames.corgarp.id] = true,
	--[UnitDefNames.corgator.id] = true,
	--[UnitDefNames.corlevlr.id] = true,
	--[UnitDefNames.cormist.id] = true,
	--[UnitDefNames.corraid.id] = true,
	--[UnitDefNames.corwolv.id] = true,
	[UnitDefNames.corak.id] = true,
	[UnitDefNames.corthud.id] = true,
	[UnitDefNames.corstorm.id] = true,
	[UnitDefNames.corcrash.id] = true,
	[UnitDefNames.armsnipe.id] = true,
	[UnitDefNames.armfido.id] = true,
	[UnitDefNames.armfboy.id] = true,
	[UnitDefNames.armfast.id] = true,
	[UnitDefNames.armamph.id] = true,
	[UnitDefNames.armmav.id] = true,
	[UnitDefNames.armspid.id] = true,
	[UnitDefNames.armzeus.id] = true,
	[UnitDefNames.coramph.id] = true,
	[UnitDefNames.corcan.id] = true,
	[UnitDefNames.corhrk.id] = true,
	[UnitDefNames.cormando.id] = true,
	[UnitDefNames.cormort.id] = true,
	[UnitDefNames.corpyro.id] = true,
	--[UnitDefNames.corsumo.id] = true,
	[UnitDefNames.cortermite.id] = true,
	[UnitDefNames.armraz.id] = true,
	[UnitDefNames.armmar.id] = true,
	[UnitDefNames.armbanth.id] = true,
	[UnitDefNames.corkrog.id] = true,
	--[UnitDefNames.corkarg.id] = true,
	--[UnitDefNames.corjugg.id] = true,
	[UnitDefNames.armvang.id] = true,
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

local weaponRange = {}
for weaponDefID, def in pairs(WeaponDefs) do
	weaponRange[weaponDefID] = def.range
end

local popups = {	-- exclude auto target range boost for popup units
	[UnitDefNames.armclaw.id] = true,
	[UnitDefNames.armpb.id] = true,
	[UnitDefNames.armamb.id] = true,
	[UnitDefNames.cormaw.id] = true,
	[UnitDefNames.corvipe.id] = true,
	[UnitDefNames.corpun.id] = true,
	[UnitDefNames.corexp.id] = true,

	[UnitDefNames.corllt.id] = true,
	[UnitDefNames.armllt.id] = true,
}
if UnitDefNames['armcom_scav'] then
	local scavengerPopups = {}
	for k,v in pairs(popups) do
		scavengerPopups[k..'_scav'] = v
	end
	for k,v in pairs(scavengerPopups) do
		popups[k] = v
	end
	scavengerPopups = nil
end

function gadget:UnitCreated(unitID,unitDefID)
	if convertedUnits[unitDefID] and unitWeapons[unitDefID] then
		for id, _ in pairs(unitWeapons[unitDefID]) do
			Spring.SetUnitWeaponState(unitID, id, "reaimTime", 1)
		end
	end
	if not popups[unitDefID] and unitWeapons[unitDefID] then
		for id, wdefID in pairs(unitWeapons[unitDefID]) do
			Spring.SetUnitWeaponState(unitID, id, "autoTargetRangeBoost", (0.1*weaponRange[wdefID]) or 20)
		end
	end
end