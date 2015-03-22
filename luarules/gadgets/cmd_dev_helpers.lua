function gadget:GetInfo()
  return {
    name      = "Dev Helper Cmds",
    desc      = "provides various luarules commands to help developers, can only be used after /cheat",
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

    -- give all stockpilable units 5 missiles
	local units = Spring.GetAllUnits()
	for _,unitID in ipairs(units) do
		Spring.SetUnitStockpile(unitID, 5) --no effect if the unit can't stockpile
	end

    return true
end

function gadget:HalfHealth()
	if not Spring.IsCheatingEnabled() then return end

    -- reduce all units health to 1/2 of its current value
    local units = Spring.GetAllUnits()
    for _,unitID in pairs(units) do
        local h = Spring.GetUnitHealth(unitID)
        Spring.SetUnitHealth(unitID,h/2)    
    end
end


function gadget:Initialize()
	gadgetHandler:AddChatAction('loadmissiles', LoadMissiles, "")
	gadgetHandler:AddChatAction('halfhealth', HalfHealth, "")
end


function gadget:Shutdown()
	gadgetHandler:RemoveChatAction('loadmissiles')
	gadgetHandler:RemoveChatAction('halfhealth')
end




--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
