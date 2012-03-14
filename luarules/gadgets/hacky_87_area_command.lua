function gadget:GetInfo()
  return {
    name      = "Hacky 87.0 Area Command workaround",
    desc      = "Uses double wait to fix area command halting",
    author    = "Google Frog",
    date      = "12 March 2012",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
    return
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local CMD_RECLAIM = CMD.RECLAIM
local CMD_RESURRECT = CMD.RESURRECT
local CMD_RESURRECT = CMD.REPAIR
local CMD_WAIT = CMD.WAIT
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spValidUnitID = Spring.ValidUnitID

local units = {count = 0, unitID = {}}
local thereIsStuffToDo = false

function gadget:UnitCmdDone(unitID, unitDefID, team, cmdID, cmdTag)
	if (cmdID == CMD.RECLAIM or cmdID == CMD_RESURRECT or cmdID == CMD_REPAIR or cmdID < 0) then
		-- Double wait requires a 1 frame delay
		thereIsStuffToDo = true
		units.count = units.count + 1
		units.unitID[units.count] = unitID
	end
end

--buildDistance
function gadget:GameFrame(f)
	if thereIsStuffToDo then
		for i = 1, units.count do
			local unitID = units.unitID[i]
			if Spring.ValidUnitID(unitID) then
				-- Double wait, is there anything you can't fix? <3
				Spring.GiveOrderToUnit(unitID,CMD_WAIT,{},{})
				Spring.GiveOrderToUnit(unitID,CMD_WAIT,{},{})
			end
		end
		thereIsStuffToDo = false
		units = {count = 0, unitID = {}}
	end
end