function gadget:GetInfo()
    return {
        name      = "WeaponStockpileGadget",
        desc      = "Sets the weapon stockpile to 0",
        author    = "Hornet",
        date      = "2022",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if gadgetHandler:IsSyncedCode() then

    function gadget:Initialize()
        -- Add any initialization code here
    end

	local function BosSetStockpile(unitID, unitDefID, _, count)
	
		local weaponStockpile = Spring.GetUnitStockpile(unitID)
		Spring.SetUnitStockpile(unitID, count)
	
	end

	function gadget:Initialize()
		gadgetHandler:RegisterGlobal("BosSetStockpile", BosSetStockpile)
	end

	function gadget:Shutdown()
		gadgetHandler:DeregisterGlobal("BosSetStockpile")
	end

end