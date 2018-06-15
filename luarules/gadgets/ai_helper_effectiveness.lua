
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
   if GG.info[teamID][unitDefID].n > 80 then 
   -- Only register the stats of the 30 latest made units:
   -- as the game evolves a unit that was being very effective can suddenly get crushed down,
   -- the greater the "n" value, the longer it will take for the avgkilled_cost to go down, and for the calculated effectiveness to go down
   -- this means the longer the game the more time the AI will take to "realise" it's being uneffective
   -- limiting the n value is done to prevent that, in hope of making AIs choices more dynamic somehow
	GG.info[teamID][unitDefID].n = GG.info[teamID][unitDefID].n - 1
	GG.info[teamID][unitDefID].killed_cost = GG.info[teamID][unitDefID].killed_cost - GG.info[teamID][unitDefID].avgkilled_cost
	if GG.info[teamID][unitDefID].killed_cost <= 0 then GG.info[teamID][unitDefID].killed_cost = 0 end
	GG.info[teamID][unitDefID].avgkilled_cost = GG.info[teamID][unitDefID].killed_cost / GG.info[teamID][unitDefID].n
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
    damage = math.min(h,damage)
	if paralyzer then damage = damage * 0.05 end
	local ratio = damage/maxh
    local killed_m = UnitDefs[unitDefID].metalCost * ratio
    local killed_e = UnitDefs[unitDefID].energyCost * ratio
	GG.info[attackerTeam][attackerDefID].killed_cost = GG.info[attackerTeam][attackerDefID].killed_cost + killed_m + killed_e/60
    GG.info[attackerTeam][attackerDefID].avgkilled_cost = GG.info[attackerTeam][attackerDefID].killed_cost / GG.info[attackerTeam][attackerDefID].n
end
end