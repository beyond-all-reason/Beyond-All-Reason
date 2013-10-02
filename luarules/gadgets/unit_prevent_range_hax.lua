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

-- Note: this check must match the equivalent function in customformations or commands will get modified
-- TODO: make this into a table on init so as it doesnt have to be rechecked each time
local function HasWaterWeapon(UnitDefID)
	local haswaterweapon = false
	local numweapons = #(UnitDefs[UnitDefID]["weapons"])
	for j=1, numweapons do
		local weapondefid = UnitDefs[UnitDefID]["weapons"][j]["weaponDef"]
		local iswaterweapon = WeaponDefs[weapondefid]["waterWeapon"]
		if iswaterweapon then haswaterweapon=true end
	end	
	return haswaterweapon
end

function gadget:AllowCommand(UnitID, UnitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
  if synced then return true end
  if (Bombers[UnitDefID]) then return true end
  if (cmdID == CMD_INSERT) and (CMD_ATTACK == cmdParams[2]) and cmdParams[6] then
	if HasWaterWeapon(UnitDefID) then y=GetGroundHeight(cmdParams[4],cmdParams[6]) else y = math.max(0,GetGroundHeight(cmdParams[4],cmdParams[6])) end
    if (cmdParams[5] > y) then
      GiveOrderToUnit(UnitID, CMD_INSERT, {cmdParams[1],cmdParams[2],cmdParams[3],cmdParams[4],y,cmdParams[6]}, cmdOptions.coded)
      return false
    end    
  end  
  if (cmdID == CMD_ATTACK) and cmdParams[3] then
	if HasWaterWeapon(UnitDefID) then y=GetGroundHeight(cmdParams[1],cmdParams[3]) else y = math.max(0,GetGroundHeight(cmdParams[1],cmdParams[3])) end
    if (cmdParams[2] > y) then
      GiveOrderToUnit(UnitID, CMD_ATTACK, {cmdParams[1],y,cmdParams[3]}, cmdOptions.coded)
      return false
    end
  end
  return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------