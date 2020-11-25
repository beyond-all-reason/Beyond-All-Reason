function gadget:GetInfo()
	return {
		name      = "Death Animations",
		desc      = "Prevent moving of Dying units",
		author    = "Beherith",
		date      = "2020",
		license   = "CC BY NC ND",
		layer     = 1000,
		enabled   = true,
	}
end

if (not gadgetHandler:IsSyncedCode()) then
	return
end

local spGetGameFrame = Spring.GetGameFrame

local hasDeathAnim = {
  [UnitDefNames.corkarg.id] = true,
  [UnitDefNames.corthud.id] = true,
  [UnitDefNames.corstorm.id] = true,
  [UnitDefNames.corsumo.id] = true,
}

local dyingUnits = {}

local maxDeathAnimLength = 300

for udid, ud in pairs(UnitDefs) do
	if ud.customParams and ud.customParams.subfolder and ud.customParams.subfolder == "other/chickens" then
		hasDeathAnim[udid] = true
	end
end

local SetUnitNoSelect	= Spring.SetUnitNoSelect
local GiveOrderToUnit	= Spring.GiveOrderToUnit
local CMD_STOP = CMD.STOP

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if hasDeathAnim[unitDefID] then
		--Spring.Echo("gadget:UnitDestroyed",unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
		SetUnitNoSelect(unitID,true)
		GiveOrderToUnit(unitID, CMD_STOP, {}, 0)
    dyingUnits[unitID] = spGetGameFrame()
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
  if dyingUnits[unitID] then
    return false
  else
    return true
  end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID) -- for unitID reuse
  if dyingUnits[unitID] then dyingUnits[unitID] = nil end
end

function gadget:GameFrame(n) --clean up 
  if n % 31 == 0 then
    for time, unitid in pairs(dyingUnits) do
      if time + maxDeathAnimLength > n then
        dyingUnits[unitid] = nil
      end
    end
  end
end
