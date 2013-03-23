--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Prevent Range Hax",
    desc      = "Prevent Range Hax",
    author    = "TheFatController",
    date      = "Jul 24, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitHeight = Spring.GetUnitHeight

local CMD_ATTACK = CMD.ATTACK
local CMD_INSERT = CMD.INSERT
local Bombers = { -- ALL BOMBER TYPE AIRCRAFT FAIL THIS CHECK
					--So they are ignored, cause of a bug in .91 
					--hacky hack solution by beherith
  [UnitDefNames["corseap"].id] = true,
  [UnitDefNames["corsb"].id] = true,
  [UnitDefNames["corhurc"].id] = true,
  [UnitDefNames["cortitan"].id] = true,
  [UnitDefNames["corshad"].id] = true,
  [UnitDefNames["corgripn"].id] = true,
  [UnitDefNames["armcybr"].id] = true,
  [UnitDefNames["armlance"].id] = true,
  [UnitDefNames["armpnix"].id] = true,
  [UnitDefNames["armthund"].id] = true,
  [UnitDefNames["armseap"].id] = true,
  [UnitDefNames["armsb"].id] = true,
}
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
  if synced then return true end
  if (Bombers[unitDefID]) then return true end
  
  local maxwaterdepth = UnitDefs[unitDefID]["maxWaterDepth"]
  local height = GetUnitHeight(unitID)
  local basex,basey,basez = GetUnitPosition(unitID)
  if (cmdID == CMD_INSERT) and (CMD_ATTACK == cmdParams[2]) and cmdParams[6] then
	-- Note: this check and its equivalent below must match the behaviour of customformations or customformations commands will get modified
	if (maxwaterdepth<=0) or (basey+height<=0) then y=GetGroundHeight(cmdParams[4],cmdParams[6]) else y = math.max(0,GetGroundHeight(cmdParams[4],cmdParams[6])) end
    if (cmdParams[5] > y) then
      GiveOrderToUnit(unitID, CMD_INSERT, {cmdParams[1],cmdParams[2],cmdParams[3],cmdParams[4],y,cmdParams[6]}, cmdOptions.coded)
      return false
    end    
  end  
  if (cmdID == CMD_ATTACK) and cmdParams[3] then
	if maxwaterdepth<=0 or (basey+height<=0) then y=GetGroundHeight(cmdParams[1],cmdParams[3]) else y = math.max(0,GetGroundHeight(cmdParams[1],cmdParams[3])) end
    if (cmdParams[2] > y) then
      GiveOrderToUnit(unitID, CMD_ATTACK, {cmdParams[1],y,cmdParams[3]}, cmdOptions.coded)
      return false
    end
  end
  return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------