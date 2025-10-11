VFS.Include("types/spring.lua")

---@class SpringRepository : ISpringRepository

---Create a new SpringRepository instance
---@return SpringRepository
local SpringRepository = {}
function SpringRepository.new()
    local self = {
        CMD = Spring.CMD or {
            LOAD_ONTO = 1,
            SELFD = 2
        }
    }

    ---@return table?
    function self:GetModOptions()
        return Spring.GetModOptions()
    end

    ---@return number, any
    function self:GetGameFrame()
        return Spring.GetGameFrame()
    end

    ---@return boolean
    function self:IsCheatingEnabled()
        return Spring.IsCheatingEnabled()
    end

    ---@param tag string
    ---@param level string
    ---@param msg string
    function self:Log(tag, level, msg)
        Spring.Log(tag, level, msg)
    end

    ---@return TeamInfo[]?
    function self:GetTeamList()
        local teamIds = Spring.GetTeamList()
        if not teamIds then return nil end

        local teams = {}
        for i, teamId in ipairs(teamIds) do
            local name, leader, isDead, isAI, side, allyTeam = Spring.GetTeamInfo(teamId)
            teams[i] = {
                id = teamId,
                name = name or "",
                leader = leader or -1,
                isDead = isDead or false,
                isAI = isAI or false,
                side = side or "",
                allyTeam = allyTeam or -1
            }
        end
        return teams
    end

    ---Private method to get complete resource data for a team and resource type
    ---@param teamID number
    ---@param resourceType string
    ---@return ResourceData
    function self:_getTeamResourceData(teamID, resourceType)
        local current, storage, pull, income, expense, share, sent, received = self:GetTeamResources(teamID, resourceType)
        return {
            current = current,
            storage = storage,
            pull = pull,
            income = income,
            expense = expense,
            shareSlider = share,
            sent = sent,
            received = received
        }
    end

    ---Get team resources with exact Spring engine signature
    ---@param teamID number
    ---@param resourceType string
    ---@return number?, number?, number?, number?, number?, number?, number?, number?, number?
    function self:GetTeamResources(teamID, resourceType)
        return Spring.GetTeamResources(teamID, resourceType)
    end

    ---Get team resources as unpacked table for easier handling
    ---@param teamID number
    ---@param resourceType string
    ---@return ResourceData Complete resource data for the team
    function self:GetTeamResourceData(teamID, resourceType)
        return self:_getTeamResourceData(teamID, resourceType)
    end

    ---Get player list with exact Spring engine signature (returns player IDs)
    ---@return number[]?
    function self:GetPlayerList()
        return Spring.GetPlayerList()
    end

    ---Get player list as unpacked TeamInfo objects for easier handling
    ---@return TeamInfo[]?
    function self:GetPlayerListData()
        -- In Spring, teams and players are synonymous (each team has one controlling player)
        return self:GetTeamList()
    end

    ---Get player IDs list (alias for GetPlayerList for compatibility)
    ---@return number[]?
    function self:GetPlayerIdsList()
        return self:GetPlayerList()
    end

    ---Check if two teams are allied
    ---@param team1ID number
    ---@param team2ID number
    ---@return boolean?
    function self:AreAlliedTeams(team1ID, team2ID)
        return Spring.AreTeamsAllied(team1ID, team2ID)
    end

    ---Get all units for a team
    ---@param teamID number
    ---@return number[]?
    function self:GetTeamUnits(teamID)
        return Spring.GetTeamUnits(teamID)
    end

    ---Get the team that owns a unit
    ---@param unitID number
    ---@return number? teamID or nil if unit doesn't exist
    function self:GetUnitTeam(unitID)
        return Spring.GetUnitTeam(unitID)
    end

    ---Get the unit definition ID for a unit
    ---@param unitID number
    ---@return number? unitDefID or nil if unit doesn't exist
    function self:GetUnitDefID(unitID)
        return Spring.GetUnitDefID(unitID)
    end

    ---Give an order to a unit
    ---@param unitID number
    ---@param commandID number
    ---@param params table
    ---@param options table
    function self:GiveOrderToUnit(unitID, commandID, params, options)
        Spring.GiveOrderToUnit(unitID, commandID, params, options)
    end

    ---Add resource to a team
    ---@param teamID number
    ---@param resourceType string
    ---@param amount number
    function self:AddTeamResource(teamID, resourceType, amount)
        Spring.AddTeamResource(teamID, resourceType, amount)
    end

    return self
end

return SpringRepository
