function gadget:GetInfo()
  return {
    name      = "Load Missiles",
    desc      = "provides a \luarules loadmissiles command, can only be used after /cheat",
    author    = "Bluestone",
    date      = "05/04/2013",
    license   = "Horses",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

if (not gadgetHandler:IsSyncedCode()) then
	return
end

function LoadMissiles()
	if not Spring.IsCheatingEnabled() then return end

	local units = Spring.GetAllUnits()
	for _,unitID in ipairs(units) do
		Spring.SetUnitStockpile(unitID, 5) --no effect if the unit can't stockpile
	end

    return true
end


function gadget:Initialize()
	gadgetHandler:AddChatAction('loadmissiles', LoadMissiles, "")
end


function gadget:Shutdown()
	gadgetHandler:RemoveChatAction('loadmissiles')
end




--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
