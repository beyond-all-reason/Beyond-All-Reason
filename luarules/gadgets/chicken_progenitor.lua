--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "ProgenitorSpawner",
    desc      = "Manages Splitting Chickens",
    author    = "TheFatController",
    date      = "05 November, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true --  loaded by default?
  }
end

local teams = Spring.GetTeamList()
for i =1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
    if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 9) == 'Chicken: ' then
        chickensEnabled = true
    end
end

if chickensEnabled == true then
	Spring.Echo("[ChickenDefense: ProgenitorSpawner] Activated!")
else
	Spring.Echo("[ChickenDefense: ProgenitorSpawner] Deactivated!")
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (gadgetHandler:IsSyncedCode()) then

local GetGameRulesParam = Spring.GetGameRulesParam
local GetUnitPosition = Spring.GetUnitPosition
local TestBuildOrder = Spring.TestBuildOrder
local GetGroundBlocked = Spring.GetGroundBlocked
local CreateUnit = Spring.CreateUnit
local GiveOrderToUnit = Spring.GiveOrderToUnit
local BOSS_WHITE1 = UnitDefNames["chickenh2"].id
local BOSS_WHITE2 = UnitDefNames["chickenh3"].id
local SMALLUNIT = UnitDefNames["chicken1"].id
local progList = {}

local function getChickenSpawnLoc(unitID)
  local x, z
  local bx, by, bz    = GetUnitPosition(unitID)
  if (not bx or not by or not bz) then
    return false
  end
  
  local tries         = 0
  local s             = 64
      
  repeat
    x = math.random(bx - s, bx + s)
    z = math.random(bz - s, bz + s)
    s = s + 4
    tries = tries + 1
  until ((TestBuildOrder(SMALLUNIT, x, by, z, 1) == 2) and (not GetGroundBlocked(x, z))) 
           or (tries > 10)
   
  return x, by, z
   
end

local function spawnChicken(number, ownerID, unitName, unitTeam)
    for i = 1,number,1 do
      local x, y, z = getChickenSpawnLoc(ownerID)
      if x then
        local newChicken = CreateUnit(unitName, x,y,z, "n", unitTeam)
        GiveOrderToUnit(newChicken, CMD.STOP, {}, {})
      end
    end
end

function gadget:GameFrame(n)
  if n%350 == 0 then
    for unitID, count in pairs(progList) do
      if Spring.ValidUnitID(unitID) and (count > 0) then
        spawnChicken(1, unitID, "chickenh3", Spring.GetUnitTeam(unitID))
        progList[unitID] = (count - 1)
      else
        progList[unitID] = nil
      end
    end
  end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
  if (unitDefID == BOSS_WHITE1) then
    progList[unitID] = 6
  end
end
  
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
  if (unitDefID == BOSS_WHITE1) then
    progList[unitID] = nil
    Spring.SetUnitBlocking(unitID, false, false)
    spawnChicken(2, unitID, "chickenh3", unitTeam)
  elseif (unitDefID == BOSS_WHITE2) then
    Spring.SetUnitBlocking(unitID, false, false)
    spawnChicken(2, unitID, "chickenh4", unitTeam)
  end
end

end 