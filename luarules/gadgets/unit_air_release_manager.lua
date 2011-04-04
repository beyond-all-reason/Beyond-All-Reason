function gadget:GetInfo()
  return {
    name      = "Air Release",
    desc      = "Makes t1 air drops a bit smoother",
    author    = "TheFatController",
    date      = "21 Feb 2010",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

if (not gadgetHandler:IsSyncedCode()) then
  return
end

local CAN_RELEASE = {
  [UnitDefNames["corvalk"].id] = 25,
  [UnitDefNames["armatlas"].id] = 25,
}

local COMMANDO = UnitDefNames["commando"].id

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
	if CAN_RELEASE[unitDefID] then
		local unitList = Spring.GetUnitIsTransporting(unitID)
		if unitList[1] then
			for _,transUnitID in ipairs(unitList) do
			    local transUnitDefID = Spring.GetUnitDefID(transUnitID)
			    if transUnitDefID ~= COMMANDO then
					local x,y,z = Spring.GetUnitBasePosition(transUnitID)
					local h = Spring.GetGroundHeight(x,z)
					if (y-h) > CAN_RELEASE[unitDefID] then
						Spring.AddUnitDamage(transUnitID, 10000000, 0, -1)
					else
						Spring.AddUnitDamage(transUnitID, ((y-h)*25), 0, attackerID or -1)
					end
				else
				  local x,_,z = Spring.GetUnitVelocity(transUnitID)
				  Spring.AddUnitImpulse(transUnitID,x*0.5,2.5,z*0.5)
				end
			end
		end	
	end
end
