
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
   GG.info[teamID][unitDefID] = GG.info[teamID][unitDefID] or {killed_cost=0,n=0}
   GG.info[teamID][unitDefID].n = GG.info[teamID][unitDefID].n + 1
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
    if not attackerDefID then return end
    if not unitDefID then return end
	if not GG.info[attackerTeam] then return end
    if not GG.info[attackerTeam][attackerDefID] then return end
    if Spring.AreTeamsAllied(unitTeam,attackerTeam) then return end
    local h,maxh,_ = Spring.GetUnitHealth(unitID)
    damage = math.max(h,damage)
	local ratio = damage/maxh
    local killed_m = UnitDefs[unitDefID].metalCost * ratio
    local killed_e = UnitDefs[unitDefID].energyCost * ratio
	GG.info[attackerTeam][attackerDefID].killed_cost = GG.info[attackerTeam][attackerDefID].killed_cost + killed_m + killed_e/60
    GG.info[attackerTeam][attackerDefID].avgkilled_cost = GG.info[attackerTeam][attackerDefID].killed_cost / GG.info[attackerTeam][attackerDefID].n
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