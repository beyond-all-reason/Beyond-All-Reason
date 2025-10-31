local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "resurrected param",
        desc      = "marks resurrected units as resurrected.",
        author    = "Floris",
        date      = "25 oct 2015",
        license   = "GNU GPL, v2 or later",
        layer     = 5,
        enabled   = true
    }
end

local CMD_WAIT = CMD.WAIT

if (gadgetHandler:IsSyncedCode()) then

    local canResurrect = {}
	local isBuilding = {}
    for unitDefID, unitDef in pairs(UnitDefs) do
        if unitDef.canResurrect then
            canResurrect[unitDefID] = true
        end
		if unitDef.isBuilding then
			isBuilding[unitDefID] = true
		end
    end

    -- detect resurrected units here
	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		if builderID and canResurrect[Spring.GetUnitDefID(builderID)] then
			local rezRulesParam = Spring.GetUnitRulesParam(unitID, "resurrected")
			if not Spring.Utilities.Gametype.IsScavengers()  and rezRulesParam == nil then
				Spring.SetUnitRulesParam(unitID, "resurrected", 1, {inlos=true})
			end
			Spring.SetUnitHealth(unitID, Spring.GetUnitHealth(unitID) * 0.05)
			if not isBuilding[unitDefID] then
				Spring.GiveOrderToUnit(unitID, CMD_WAIT, {}, 0)
			end
		end
		-- See: https://github.com/beyond-all-reason/spring/pull/471
		-- if builderID and Spring.GetUnitCurrentCommand(builderID) == CMD.RESURRECT then
		--	Spring.SetUnitHealth(unitID, Spring.GetUnitHealth(unitID) * 0.05)
		-- end
		-- this code is buggy.
		-- Spring.GetUnitCurrentCommand(builderID) does not return CMD.RESURRECT in all cases
		-- Switch to using same rule as the halo visual
		-- which does have the limitation that *any* unit created by a builder that can rez
		-- will be created at 5% HP
		-- currently not an issue with BAR's current units, but is a limitation on any
		-- future multi-purpose rez unit
	end
end
