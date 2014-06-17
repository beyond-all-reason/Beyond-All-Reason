--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Commander Blast",
    desc      = "Spawns commander blast CEG, dependent upon skillclass",
    author    = "Bluestone",
    date      = "June 2014",
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


local COMMANDER_EXPLOSION = "COMMANDER_EXPLOSION"
local COMMANDER_EXPLOSION_YELLOW = "COMMANDER_EXPLOSION_YELLOW"
local COMMANDER_EXPLOSION_BLUE = "COMMANDER_EXPLOSION_BLUE"


local COMMANDER = {
  [UnitDefNames["corcom"].id] = true,
  [UnitDefNames["armcom"].id] = true,
}

local teamCEG = {} --teamCEG[tID] = cegID of commander blast for that team

function gadget:Initialize()
    -- give each team the CEG corresponding to the player with the lowest skillClass in that team
    local gaiaTeamID = Spring.GetGaiaTeamID()
    local teamList = Spring.GetTeamList()
    for _,tID in pairs(teamList) do
        if tID==gaiaTeamID then
            teamCEG[tID] = COMMANDER_EXPLOSION
        else
            local playerList = Spring.GetPlayerList(tID)
            local teamSkillClass = 5
            for _,pID in pairs(playerList) do
                local customtable = select(10,Spring.GetPlayerInfo(pID))
                local skillClass = customtable.skillclass -- 1 (1st), 2 (top5), 3 (top10), 4 (top20), 5 (other) 
                teamSkillClass = math.min(teamSkillClass, skillClass or 5)
            end
            if teamSkillClass >= 5 then
                teamCEG[tID] = COMMANDER_EXPLOSION
            elseif teamSkillClass >= 3 then
                teamCEG[tID] = COMMANDER_EXPLOSION_YELLOW
            else
                teamCEG[tID] = COMMANDER_EXPLOSION_BLUE
            end
        end    
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeam)
    if not COMMANDER[unitDefID] then return end
    
    local x,y,z = Spring.GetUnitBasePosition(unitID)
    Spring.SpawnCEG(teamCEG[teamID], x,y,z, 0,0,0, 0, 0) --spawn CEG, cause no damage
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------