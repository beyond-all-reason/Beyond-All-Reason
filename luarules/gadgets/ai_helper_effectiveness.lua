
function gadget:GetInfo()
  return {
    name      = "AI Stats",
    desc      = "Collect stats per TeamID and per UnitDefID for LuaAIs",
    author    = "Doo (orig by bluestone: 'Stats')",
    date      = "",
    license   = "GNU GPL, v3 or later",
    layer     = -math.huge,
    enabled   = true,
  }
end

if (gadgetHandler:IsSyncedCode()) then



function gadget:Initialize()
GG.info = {}
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
   GG.info[teamID] = GG.info[teamID] or {}
   GG.info[teamID][unitDefID] = GG.info[teamID][unitDefID] or {killed_cost=0,n=0, avgkilled_cost=0}
   GG.info[teamID][unitDefID].n = GG.info[teamID][unitDefID].n + 1
   if not (
   GG.info[teamID][UnitDefNames["armgate"].id] and  
   GG.info[teamID][UnitDefNames["corgate"].id] and  
   GG.info[teamID][UnitDefNames["armamd"].id] and  
   GG.info[teamID][UnitDefNames["corfmd"].id] and  
   GG.info[teamID][UnitDefNames["armscab"].id] and  
   GG.info[teamID][UnitDefNames["cormabm"].id]  
   ) then
	   GG.info[teamID][UnitDefNames["armgate"].id]  = {killed_cost=0,n=0, avgkilled_cost=0}  
	   GG.info[teamID][UnitDefNames["corgate"].id]  = {killed_cost=0,n=0, avgkilled_cost=0}  
	   GG.info[teamID][UnitDefNames["armamd"].id]  = {killed_cost=0,n=0, avgkilled_cost=0}  
	   GG.info[teamID][UnitDefNames["corfmd"].id]  = {killed_cost=0,n=0, avgkilled_cost=0}  
	   GG.info[teamID][UnitDefNames["armscab"].id]  = {killed_cost=0,n=0, avgkilled_cost=0}  
	   GG.info[teamID][UnitDefNames["cormabm"].id]  = {killed_cost=0,n=0, avgkilled_cost=0}  
   end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
    if not attackerDefID then return end
    if not unitDefID then return end
	if not GG.info[attackerTeam] then return end
    if not GG.info[attackerTeam][attackerDefID] then return end
	if not GG.info[unitTeam] then return end
    if not GG.info[unitTeam][unitDefID] then return end
    if Spring.AreTeamsAllied(unitTeam,attackerTeam) then return end
    local h,maxh,_ = Spring.GetUnitHealth(unitID)
    damage = math.max(h,damage)
	local ratio = damage/maxh
    local killed_m = UnitDefs[unitDefID].metalCost * ratio
    local killed_e = UnitDefs[unitDefID].energyCost * ratio
	GG.info[attackerTeam][attackerDefID].killed_cost = GG.info[attackerTeam][attackerDefID].killed_cost + killed_m + killed_e/60
    GG.info[attackerTeam][attackerDefID].avgkilled_cost = GG.info[attackerTeam][attackerDefID].killed_cost / GG.info[attackerTeam][attackerDefID].n
	if weaponDefID and WeaponDefs[weaponDefID] then
		if WeaponDefs[weaponDefID].type == "Cannon" then
			GG.info[unitTeam][UnitDefNames["armgate"].id].killed_cost = GG.info[unitTeam][UnitDefNames["armgate"].id].killed_cost + killed_m + killed_e/60
			if GG.info[unitTeam][UnitDefNames["armgate"].id].n ~= 0 then 
				GG.info[unitTeam][UnitDefNames["armgate"].id].avgkilled_cost = GG.info[unitTeam][UnitDefNames["armgate"].id].killed_cost / GG.info[unitTeam][UnitDefNames["armgate"].id].n
			else
				GG.info[unitTeam][UnitDefNames["armgate"].id].avgkilled_cost = GG.info[unitTeam][UnitDefNames["armgate"].id].killed_cost
			end
			GG.info[unitTeam][UnitDefNames["corgate"].id].killed_cost = GG.info[unitTeam][UnitDefNames["corgate"].id].killed_cost + killed_m + killed_e/60
			if GG.info[unitTeam][UnitDefNames["corgate"].id].n ~= 0 then 
				GG.info[unitTeam][UnitDefNames["corgate"].id].avgkilled_cost = GG.info[unitTeam][UnitDefNames["corgate"].id].killed_cost / GG.info[unitTeam][UnitDefNames["corgate"].id].n
			else
				GG.info[unitTeam][UnitDefNames["corgate"].id].avgkilled_cost = GG.info[unitTeam][UnitDefNames["corgate"].id].killed_cost
			end

		elseif string.find(WeaponDefs[weaponDefID].name, "silo") then
				GG.info[unitTeam][UnitDefNames["armamd"].id].killed_cost = GG.info[unitTeam][UnitDefNames["armgame"].id].killed_cost + killed_m + killed_e/60
			if GG.info[unitTeam][UnitDefNames["armamd"].id].n ~= 0 then 
				GG.info[unitTeam][UnitDefNames["armamd"].id].avgkilled_cost = GG.info[unitTeam][UnitDefNames["armgame"].id].killed_cost / GG.info[unitTeam][UnitDefNames["armgame"].id].n
			else
				GG.info[unitTeam][UnitDefNames["armamd"].id].avgkilled_cost = GG.info[unitTeam][UnitDefNames["armgame"].id].killed_cost
			end
				GG.info[unitTeam][UnitDefNames["armscab"].id].killed_cost = GG.info[unitTeam][UnitDefNames["armscab"].id].killed_cost + killed_m + killed_e/60
			if GG.info[unitTeam][UnitDefNames["armscab"].id].n ~= 0 then 
				GG.info[unitTeam][UnitDefNames["armscab"].id].avgkilled_cost = GG.info[unitTeam][UnitDefNames["armscab"].id].killed_cost / GG.info[unitTeam][UnitDefNames["armscab"].id].n
			else
				GG.info[unitTeam][UnitDefNames["armscab"].id].avgkilled_cost = GG.info[unitTeam][UnitDefNames["armscab"].id].killed_cost
			end
				GG.info[unitTeam][UnitDefNames["coramd"].id].killed_cost = GG.info[unitTeam][UnitDefNames["coramd"].id].killed_cost + killed_m + killed_e/60
			if GG.info[unitTeam][UnitDefNames["coramd"].id].n ~= 0 then 
				GG.info[unitTeam][UnitDefNames["coramd"].id].avgkilled_cost = GG.info[unitTeam][UnitDefNames["coramd"].id].killed_cost / GG.info[unitTeam][UnitDefNames["coramd"].id].n
			else
				GG.info[unitTeam][UnitDefNames["coramd"].id].avgkilled_cost = GG.info[unitTeam][UnitDefNames["coramd"].id].killed_cost
			end
				GG.info[unitTeam][UnitDefNames["cormabm"].id].killed_cost = GG.info[unitTeam][UnitDefNames["cormabm"].id].killed_cost + killed_m + killed_e/60
			if GG.info[unitTeam][UnitDefNames["cormabm"].id].n ~= 0 then 
				GG.info[unitTeam][UnitDefNames["cormabm"].id].avgkilled_cost = GG.info[unitTeam][UnitDefNames["cormabm"].id].killed_cost / GG.info[unitTeam][UnitDefNames["cormabm"].id].n
			else
				GG.info[unitTeam][UnitDefNames["cormabm"].id].avgkilled_cost = GG.info[unitTeam][UnitDefNames["cormabm"].id].killed_cost
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if not attackerDefID then return end
    if not unitDefID then return end
    if not GG.info[attackerTeam][attackerDefID] then return end
    if unitTeam==attackerTeam then return end
    
    local killed_m = UnitDefs[unitDefID].metalCost
    local killed_e = UnitDefs[unitDefID].energyCost
   GG.info[attackerTeam][attackerDefID].killed_cost = GG.info[attackerTeam][attackerDefID].killed_cost + killed_m + killed_e/60
   GG.info[attackerTeam][attackerDefID].avgkilled_cost = GG.info[attackerTeam][attackerDefID].killed_cost/ GG.info[attackerTeam][attackerDefID].n
end
end