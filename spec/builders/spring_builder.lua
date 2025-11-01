-- Ensure TeamData type is available
require("spec/builders/team_builder")
require("common/stringFunctions")
require("common.tablefunctions")

---@class SpringBuilder
---@field modOptions table
---@field teamRulesParams table
---@field teams table<number, TeamBuilder> Team builders that provide resource data
---@field logMessages table
---@field alliances table
---@field gameFrame number
---@field cheatingEnabled boolean
---@field _builtTeams table? -- Internal field for testing
---@field initialUnits table<number, table<number, string>>
local SB = {}
SB.__index = SB

---Get comprehensive default mod options required for unitdefs and alldefs_post.lua loading
---@return table
local function getUnitDefRequireModoptionDefaults()
    return {
        -- Multipliers
        multiplier_maxvelocity = 1,
        multiplier_turnrate = 1,
        multiplier_builddistance = 1,
        multiplier_buildpower = 1,
        multiplier_metalextraction = 1,
        multiplier_resourceincome = 1,
        multiplier_energyproduction = 1,
        multiplier_energyconversion = 1,
        multiplier_losrange = 1,
        multiplier_radarrange = 1,
        multiplier_shieldpower = 1,
        multiplier_weaponrange = 1,
        multiplier_weapondamage = 1,

        -- Unit restrictions
        unit_restrictions_notech2 = false,
        unit_restrictions_notech3 = false,
        unit_restrictions_notech15 = false,
        unit_restrictions_noair = false,
        unit_restrictions_noextractors = false,
        unit_restrictions_noconverters = false,
        unit_restrictions_nofusion = false,
        unit_restrictions_nonukes = false,
        unit_restrictions_nodefence = false,
        unit_restrictions_noantinuke = false,
        unit_restrictions_notacnukes = false,
        unit_restrictions_nolrpc = false,
        unit_restrictions_noendgamelrpc = false,

        -- Experimental features
        experimentallegionfaction = false,
        experimentalextraunits = false,
        experimentalshields = false,

        -- Game modes
        comrespawn = "none",
        evocom = false,
        evocomxpmultiplier = 1,
        evocomlevelupmethod = "dynamic",
        evocomlevelupmultiplier = 1,
        evocomleveluptime = 1,
        evocomlevelcap = 10,

        -- Balance changes
        junorework = false,
        shieldsrework = false,
        emprework = false,
        air_rework = false,
        skyshift = false,
        proposed_unit_reworks = false,
        lategame_rebalance = false,
        factory_costs = false,
        splittiers = false,

        -- Other features
        unithats = false,
        scavunitsforplayers = false,
        releasecandidates = false,
        ruins = "disabled",
        forceallunits = false,
        transportenemy = "all",
        animationcleanup = false,
        xmas = false,
        assistdronesbuildpowermultiplier = 1,

        gamespeed = 30,
    }
end

---@return SpringBuilder
function SB.new()
    return setmetatable({
        modOptions = {},
        teamRulesParams = {}, -- teamID -> paramName -> value
        teams = {}, -- teamID -> TeamData from team builders
        logMessages = {},
        alliances = {}, -- teamID -> teamID -> boolean
        gameFrame = 1,
        cheatingEnabled = false,
        _globalUnitDefs = nil -- Shared unit definitions cache
    }, SB)
end

---@param self SpringBuilder
---@param options table
---@return SpringBuilder
function SB:WithModOptions(options)
    self.modOptions = options
    return self
end

---@param self SpringBuilder
---@param key string
---@param value any
---@return SpringBuilder
function SB:WithModOption(key, value)
    self.modOptions[key] = value
    return self
end


---@param self SpringBuilder
---@param team1ID number
---@param team2ID number
---@return SpringBuilder
function SB:WithAlliance(team1ID, team2ID, isAllied)
    if isAllied == nil then isAllied = true end -- Default to allied for backward compatibility
    self.alliances[team1ID] = self.alliances[team1ID] or {}
    self.alliances[team2ID] = self.alliances[team2ID] or {}
    self.alliances[team1ID][team2ID] = isAllied
    self.alliances[team2ID][team1ID] = isAllied
    return self
end

---@param self SpringBuilder
---@param frame number
---@return SpringBuilder
function SB:WithGameFrame(frame)
    self.gameFrame = frame
    return self
end

---@param self SpringBuilder
---@param teamID number
---@param key string
---@param value any
---@return SpringBuilder
function SB:WithTeamRulesParam(teamID, key, value)
    self.teamRulesParams[teamID] = self.teamRulesParams[teamID] or {}
    self.teamRulesParams[teamID][key] = value
    return self
end

---@param self SpringBuilder
---@return ISpring
function SB:Build()
    return self:BuildSpring()
end

---@param self SpringBuilder
---@return ISpring
function SB:BuildSpring()
    ---@type SpringBuilder
    local instance = self

    -- Build all teams for use throughout the repository
    local builtTeams = {}
    for teamId, teamBuilder in pairs(instance.teams) do
        builtTeams[teamId] = teamBuilder:Build()
    end
    -- Store built teams for access by other functions
    instance._builtTeams = builtTeams

    -- Integrate real unit definitions into built teams if available
    if instance._globalUnitDefs then
        for teamId, builtTeam in pairs(builtTeams) do
            if builtTeam.units then
                for unitId, unitWrapper in pairs(builtTeam.units) do
                    if unitWrapper.unitDefId and instance._globalUnitDefs[unitWrapper.unitDefId] then
                        -- Populate unit wrapper with real unit definition data
                        local unitDef = instance._globalUnitDefs[unitWrapper.unitDefId]
                        for k, v in pairs(unitDef) do
                            if unitWrapper[k] == nil then  -- Don't overwrite existing fields
                                unitWrapper[k] = v
                            end
                        end
                        unitWrapper.unitDef = unitDef
                    end
                end
            end
        end
    end
    -- Use the team rules params configured via WithTeamRulesParam
    local rulesParams = instance.teamRulesParams

    -- Helper function for getting team resource data
    local function getTeamResourceData(teamID, resourceType)
        if type(teamID) ~= "number" then
            error(string.format("TeamID must be a number, got %s: %s", type(teamID), tostring(teamID)))
        end
        if type(resourceType) ~= "string" then
            error(string.format("ResourceType must be a string, got %s: %s", type(resourceType), tostring(resourceType)))
        end

        -- Require team builder data - no fallbacks allowed
        local teamBuilder = builtTeams[teamID]
        if not teamBuilder then
            error(string.format("TeamBuilder not found for teamID %d. Use SpringBuilder:WithTeam(teamBuilder) to configure teams properly.", teamID))
        end

        if resourceType == "metal" then
            return teamBuilder.metal
        elseif resourceType == "energy" then
            return teamBuilder.energy
        else
            error(string.format("Unknown resource type: %s", resourceType))
        end
    end

    local mock = {
        CMD = Spring and Spring.CMD or {
            LOAD_ONTO = 1,
            SELFD = 2,
            GUARD = 25,
            REPAIR = 40,
            RECLAIM = 90
        },
        GetModOptions = function()
            -- Return only the mod options that were explicitly set via WithModOption/WithModOptions
            return instance.modOptions
        end,
        GetGameFrame = function()
            return instance.gameFrame
        end,
        IsCheatingEnabled = function()
            return instance.cheatingEnabled
        end,
        Log = function(tag, level, msg)
            table.insert(instance.logMessages, {tag = tag, level = level, msg = msg})
            --- Silent for testing - don't print
        end,
        GetLoggedMessages = function()
            return instance.logMessages
        end,
        AreAlliedTeams = function(team1ID, team2ID)
            if team1ID == team2ID then return true end
            -- Check explicit alliance settings first
            if instance.alliances[team1ID] and instance.alliances[team1ID][team2ID] ~= nil then
                return instance.alliances[team1ID][team2ID]
            end
            return false
        end,
        GetTeamRulesParam = function(teamID, key)
            return rulesParams[teamID] and rulesParams[teamID][key] or nil
        end,
        SetTeamRulesParam = function(teamID, key, value)
            rulesParams[teamID] = rulesParams[teamID] or {}
            rulesParams[teamID][key] = value
        end,
        GetTeamList = function()
            -- Convert teams (TeamData objects) to TeamInfo array for Spring API
            local teams = {}
            local i = 1
            for teamId, teamData in pairs(builtTeams) do
                teams[i] = {
                    id = teamData.id,
                    name = teamData.playerName or ("Team " .. teamData.id),
                    leader = teamData.id,
                    isDead = false,
                    isAI = not teamData.isHuman,
                    side = "arm",
                    allyTeam = teamData.id
                }
                i = i + 1
            end
            return teams
        end,

        GetTeamResources = function(teamID, resourceType)
            local data = getTeamResourceData(teamID, resourceType)
            return data.current, data.storage, data.pull, data.income, data.expense, data.share, data.sent, data.received
        end,
        -- Convenience accessors for tests
        __getInitialUnits = function()
            return instance.initialUnits
        end,
        GetUnitDefs = function()
            -- Return instance globals from WithRealUnitDefs
            if instance._globalUnitDefs then
                return instance._globalUnitDefs
            end

            -- Otherwise, return registered unitDefs from team builders
            local unitDefs = {}
            local registeredUnitDefIds = {}

            -- Collect all unique unitDefIds from teams' units
            for teamId, teamBuilder in pairs(instance._builtTeams or {}) do
                if teamBuilder.units then
                    for unitId, unitWrapper in pairs(teamBuilder.units) do
                        if unitWrapper.unitDefId then
                            registeredUnitDefIds[unitWrapper.unitDefId] = true
                        end
                    end
                end
            end

            -- Create mock unitDefs for registered unitDefIds
            for unitDefId in pairs(registeredUnitDefIds) do
                -- Create a basic mock unitDef - this may need to be enhanced based on what properties are checked
                local mockDef = {
                    id = unitDefId,
                    name = "mock_unit_" .. unitDefId,
                    isFactory = false,
                    canAssist = false,
                    buildOptions = {},
                    customParams = {
                        techlevel = 1,
                        unitgroup = "combat"
                    }
                }
                unitDefs[unitDefId] = mockDef
            end

            return unitDefs
        end
    }

    -- Make built teams accessible for testing/debugging
    mock._builtTeams = builtTeams

    -- Add functions that reference other functions in the table
    mock.GetPlayerList = function(teamID)
        -- Spring.GetPlayerList returns player IDs, not TeamInfo objects
        local teamList = mock.GetTeamList()
        if not teamList then return nil end

        if teamID then
            -- If teamID is provided, return players on that team
            for _, teamInfo in ipairs(teamList) do
                if teamInfo.id == teamID then
                    return {teamInfo.leader}
                end
            end
            return {}
        end

        local playerIds = {}
        for i, teamInfo in ipairs(teamList) do
            playerIds[i] = teamInfo.leader
        end
        return playerIds
    end

    mock.GetTeamUnits = function(teamID)
        local teamData = mock._builtTeams[teamID]
        if not teamData or not teamData.units then
            return {}
        end

        -- Convert unitID -> unitWrapper to unitID -> unitDefId
        local unitMap = {}
        for unitID, unitWrapper in pairs(teamData.units) do
            unitMap[unitID] = unitWrapper.unitDefId
        end
        return unitMap
    end

    mock.GetUnitTeam = function(unitID)
        -- Find which team owns this unit
        local bt = mock._builtTeams
        for teamId, teamBuilder in pairs(bt) do
            if teamBuilder.units then
                for uId, uData in pairs(teamBuilder.units) do
                    if uId == unitID then
                        return teamId
                    end
                end
            end
        end
        return nil -- Unit not found
    end

    mock.GetUnitDefID = function(unitID)
        local bt = mock._builtTeams or builtTeams
        for teamId, teamBuilder in pairs(bt) do
            if teamBuilder.units then
                for storedUnitId, unitWrapper in pairs(teamBuilder.units) do
                    if storedUnitId == unitID then
                        return unitWrapper.unitDefId
                    end
                end
            end
        end
        return nil -- Unit not found
    end

    mock.GiveOrderToUnit = function(unitID, cmdID, params, options)
        -- Mock implementation - spy to record that the method was called
        return true
    end

    mock.AddTeamResource = function(teamID, resourceType, amount)
        local teamData = builtTeams[teamID]
        if teamData then
            if resourceType == "metal" then
                teamData.metal.current = teamData.metal.current + amount
            elseif resourceType == "energy" then
                teamData.energy.current = teamData.energy.current + amount
            end
        end
        return true, amount
    end

    mock.ValidUnitID = function(unitID)
        -- Check if unit exists in any team
        for teamId, teamBuilder in pairs(builtTeams) do
            if teamBuilder.units and teamBuilder.units[unitID] then
                return true
            end
        end
        return false
    end

    mock.TransferUnit = function(unitID, newTeamID, given)
        -- Find current team
        local currentTeamID = nil
        local unitDefID = nil
        local bt = mock._builtTeams or builtTeams
        for teamId, teamBuilder in pairs(bt) do
            if teamBuilder.units and teamBuilder.units[unitID] then
                currentTeamID = teamId
                unitDefID = teamBuilder.units[unitID].unitDefId
                break
            end
        end
        
        if not currentTeamID then
            return false
        end
        
        if currentTeamID == newTeamID then
            return true
        end
        
        -- Remove from current team
        if bt[currentTeamID] and bt[currentTeamID].units then
            bt[currentTeamID].units[unitID] = nil
        end

        -- Add to new team
        if not bt[newTeamID] then
            bt[newTeamID] = {units = {}}
        end
        if not bt[newTeamID].units then
            bt[newTeamID].units = {}
        end
        bt[newTeamID].units[unitID] = {unitDefId = unitDefID}
        
        return true
    end

    mock.AreTeamsAllied = function(teamA, teamB)
        -- Mock implementation - check if alliance was set up
        local teamAId = type(teamA) == "table" and (teamA.id or tostring(teamA)) or tostring(teamA)
        local teamBId = type(teamB) == "table" and (teamB.id or tostring(teamB)) or tostring(teamB)
        local allianceKey = teamAId .. "_" .. teamBId
        return instance.alliances[allianceKey] or false
    end

    mock.IsCheatingEnabled = function()
        return false
    end

    return mock
end

---Temporarily install minimal global Spring/VFS/Game/LOG (spec_helper does some of this but we try for thoroughness) to allow real unitdefs load
---@param self SpringBuilder
---@param fn fun()
---@param persist? boolean If true, don't clean up globals after execution
function SB:WithGlobalsDefined(fn, persist)
    local instance = self
    -- Save current globals
    local prevSpring = _G.Spring
    local prevVFS = _G.VFS
    local prevGame = _G.Game
    local prevLOG = _G.LOG
    local prevSplit = string.split
    local prevUnitDefs = _G.UnitDefs
    local prevUnitDefNames = _G.UnitDefNames

    -- Set up mocks for the duration of the function
    _G.Spring = _G.Spring or {}
    local mock = self:BuildSpring()

    -- Expose all Spring functions to global Spring object
    -- Defer to already defined GetModOptions if it exists (defined by springOverrides.lua)
    if not _G.Spring.GetModOptions then
        ---@diagnostic disable: duplicate-set-field
        _G.Spring.GetModOptions = function()
            -- Start with comprehensive defaults, then override with explicitly set mod options
            local modOptions = getUnitDefRequireModoptionDefaults()
            -- Override with any mod options that were explicitly set via WithModOption
            for k, v in pairs(self.modOptions) do
                modOptions[k] = v
            end
            return modOptions
        end
    end
    _G.Spring.GetGameFrame = mock.GetGameFrame
    _G.Spring.IsCheatingEnabled = mock.IsCheatingEnabled
    -- Don't override Spring.Log if it's already set by spec_helper
    if not _G.Spring.Log then
        _G.Spring.Log = mock.Log
    end
    _G.Spring.GetTeamRulesParam = mock.GetTeamRulesParam
    _G.Spring.SetTeamRulesParam = mock.SetTeamRulesParam
    _G.Spring.GetUnitDefID = mock.GetUnitDefID
    _G.Spring.ValidUnitID = mock.ValidUnitID


    -- Additional Spring functions that may be needed
    -- Defer to already defined GetTeamLuaAI if it exists (real Spring API function)
    if not _G.Spring.GetTeamLuaAI then
        ---@diagnostic disable: duplicate-set-field
        _G.Spring.GetTeamLuaAI = function(_) return "" end
    end
    _G.Spring.Utilities = _G.Spring.Utilities or { Gametype = { IsScavengers = function() return false end, IsRaptors = function() return false end, GetCurrentHolidays = function() return {} end } }

    _G.LOG = _G.LOG or { DEBUG = "DEBUG", INFO = "INFO", WARNING = "WARNING", ERROR = "ERROR" }
    _G.Game = _G.Game or {}
    _G.Game.gameSpeed = _G.Game.gameSpeed or 30

    -- Execute the function with globals set up
    local success, result = pcall(fn)
    if not success then
        error("WithGlobalsDefined function failed: " .. tostring(result))
    end

    -- If not persisting, restore original globals
    if not persist then
        _G.Spring = prevSpring
        _G.VFS = prevVFS
        _G.Game = prevGame
        _G.LOG = prevLOG
        string.split = prevSplit
        _G.UnitDefs = prevUnitDefs
        _G.UnitDefNames = prevUnitDefNames
    end

    return instance
end


---@param self SpringBuilder
---@param teamBuilder TeamBuilder The team builder instance
---@return SpringBuilder
function SB:WithTeam(teamBuilder)
    if not teamBuilder.id then
        error("TeamBuilder must have an id field. teamBuilder: " .. table.toString(teamBuilder))
    end
    self.teams[teamBuilder.id] = teamBuilder
    return self
end

---@param self SpringBuilder
---@return SpringBuilder
function SB:WithRealUnitDefs()
    if not self._globalUnitDefs then
        self:WithGlobalsDefined(function()
            -- Load unitdefs with proper VFS/Spring globals set up
            local success, defs = pcall(require, "gamedata.unitdefs")
            if success then
                -- Set global UnitDefs for post-processing
                _G.UnitDefs = defs
                
                -- Load alldefs_post first to ensure UnitDef_Post is available
                local alldefsSuccess, alldefsError = pcall(require, "gamedata.alldefs_post")
                if not alldefsSuccess then
                    Spring.Log("UNITDEFS", LOG.ERROR, "Failed to load alldefs_post: " .. tostring(alldefsError))
                end

                -- Run post-processing to normalize unit definitions
                local postSuccess, postError = pcall(require, "gamedata.unitdefs_post")
                if not postSuccess then
                    Spring.Log("UNITDEFS", LOG.ERROR, "Failed to run unitdefs post-processing: " .. tostring(postError))
                end
                
                -- Use the processed definitions and clear global state for test isolation
                self._globalUnitDefs = _G.UnitDefs
                self._globalUnitDefNames = _G.UnitDefNames
                _G.UnitDefs = nil
                _G.UnitDefNames = nil
            else
                -- If loading fails, leave _globalUnitDefs as nil so GetUnitDefs falls back to registered unitDefs
                self._globalUnitDefs = nil
            end
        end)
    end
    return self
end


return SB
