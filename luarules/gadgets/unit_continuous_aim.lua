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
	[UnitDefNames.armart.id] = true,
	[UnitDefNames.armfav.id] = true,
	[UnitDefNames.armflash.id] = true,
	[UnitDefNames.armjanus.id] = true,
	[UnitDefNames.armpincer.id] = true,
	[UnitDefNames.armsam.id] = true,
	[UnitDefNames.armstump.id] = true,
	[UnitDefNames.armpw.id] = true,
	[UnitDefNames.armflea.id] = true,
	[UnitDefNames.armrock.id] = true,
	[UnitDefNames.armham.id] = true,
	[UnitDefNames.armwar.id] = true,
	[UnitDefNames.armjeth.id] = true,
	[UnitDefNames.corfav.id] = true,
	[UnitDefNames.corgarp.id] = true,
	[UnitDefNames.corgator.id] = true,
	[UnitDefNames.corlevlr.id] = true,
	[UnitDefNames.cormist.id] = true,
	[UnitDefNames.corraid.id] = true,
	[UnitDefNames.corwolv.id] = true,
	[UnitDefNames.corak.id] = true,
	[UnitDefNames.corthud.id] = true,
	[UnitDefNames.corstorm.id] = true,
	[UnitDefNames.corcrash.id] = true,
	[UnitDefNames.armsnipe.id] = true,
	[UnitDefNames.armfido.id] = true
	[UnitDefNames.armfboy.id] = true,
	[UnitDefNames.armfast.id] = true
	[UnitDefNames.armamph.id] = true,
	[UnitDefNames.armmav.id] = true,
	[UnitDefNames.armspid.id] = true,
	[UnitDefNames.armzeus.id] = true,
	}

    function gadget:UnitCreated(unitID,unitDefID)
		if convertedUnits[unitDefID] then
			for id, table in pairs(UnitDefs[Spring.GetUnitDefID(unitID)].weapons) do
				Spring.SetUnitWeaponState(unitID, id, "reaimTime", 1)
			end
		end
    end