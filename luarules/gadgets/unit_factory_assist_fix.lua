
if not gadgetHandler:IsSyncedCode() then
	return
end


local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Factory Assist Fix",
		desc      = "Fixes factory assist so that builders don't leave to repair damaged finished units",
		author    = "TheDujin",
		date      = "Jun 2025",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

Spring.Echo("hello world x1")

local isAssistBuilder = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilder and unitDef.canAssist then
		isAssistBuilder[unitDefID] = true
	end
end


local spGetUnitBuildFacing = Spring.GetUnitBuildFacing

local CMD_REPAIR = CMD.REPAIR

local CMD_MOVE = CMD.MOVE

--------------------------------------------------------------------------------
-- Unit Handling

function gadget:UnitFromFactory(unitID, unitDefID, unitTeam,
								factID, factDefID, userOrders)
	local unitHealth, unitMaxHealth, _, _, _ = Spring.GetUnitHealth(unitID)
	Spring.Echo(string.format("curr health: %d. max health: %d", unitHealth, unitMaxHealth))
	if (unitHealth >= unitMaxHealth) then
		return
	end
	
	for _, otherUnitID in ipairs(Spring.GetAllUnits()) do
		-- Spring.Echo("hello each")

		local otherUnitDefID = Spring.GetUnitDefID(otherUnitID)
		if (isAssistBuilder[otherUnitDefID]) then
			local commands = Spring.GetUnitCommands(otherUnitID, 2)
			if (#commands >= 2) then
				local firstCmd = commands[1]
				local secondCmd = commands[2]
				if (firstCmd.id == CMD.REPAIR
					and secondCmd.id == CMD.GUARD and commands) then
						Spring.Echo("found something")
						local isRepairingNewUnit = firstCmd.params[1] == unitID
						local isGuardingFactory = secondCmd.params[1] == factID
						Spring.Echo("i really found something :D")
						Spring.GiveOrderToUnit(otherUnitID, CMD.REMOVE, {firstCmd.id}, CMD.OPT_ALT)
						Spring.Echo("huh")
				end
			end
			-- Spring.Echo("irrelevant builder")
		end
	end
	Spring.Echo("hello 3")
end

function gadget:Initialize()
	Spring.Echo("hello 2")
end


-- Spring.GetAllUnits
--------------------------------------------------------------------------------
