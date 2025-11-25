-- Ensure TeamData type is available
VFS.Include("spec/builders/team_builder.lua")
VFS.Include("common/stringFunctions.lua")
VFS.Include("common.tablefunctions.lua")

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
        unit_restrictions_noair = false,
        unit_restrictions_nobots = false,
        unit_restrictions_nocons = false,
        unit_restrictions_nodrops = false,
        unit_restrictions_noecon = false,
        unit_restrictions_nofactory = false,
        unit_restrictions_nogh = false,
        unit_restrictions_nohover = false,
        unit_restrictions_nokbot = false,
        unit_restrictions_nonavy = false,
        unit_restrictions_noradarvh = false,
        unit_restrictions_notank = false,
        unit_restrictions_nouber = false,
        unit_restrictions_nowall = false,
        unit_restrictions_noxp = false,
        unit_restrictions_nosuperweapons = false,

        -- Commander perks
        commander = 0,
        commtype = 0,
        commanderstorage = 0,
        automatic_swarm = 0,
        automatic_factory = 0,

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

local function normalizeUnitDef(unitDef)
    if not unitDef then return end
    local cp = unitDef.customParams or unitDef.customparams
    if not cp then
        cp = {}
    end
    unitDef.customParams = cp
    unitDef.customparams = cp
    if cp.unitgroup == nil and unitDef.unitgroup then
        cp.unitgroup = unitDef.unitgroup
    end
    if unitDef.buildOptions == nil and unitDef.buildoptions ~= nil then
        unitDef.buildOptions = unitDef.buildoptions
    elseif unitDef.buildoptions == nil and unitDef.buildOptions ~= nil then
        unitDef.buildoptions = unitDef.buildOptions
    end
    if unitDef.canAssist == nil and unitDef.canassist ~= nil then
        unitDef.canAssist = unitDef.canassist
    elseif unitDef.canassist == nil and unitDef.canAssist ~= nil then
        unitDef.canassist = unitDef.canAssist
    end
end

local function buildUnitDefIndex(unitDefs, unitDefNames)
    local index = {}
    for key, def in pairs(unitDefs or {}) do
        if def then
            normalizeUnitDef(def)
            index[key] = def
            if def.id then
                index[def.id] = def
            end
            if def.name then
                index[def.name] = def
            end
        end
    end
    for name, info in pairs(unitDefNames or {}) do
        local numericId = info and info.id
        if numericId and unitDefs and unitDefs[name] then
            index[numericId] = unitDefs[name]
        end
    end
    return index
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
        for _, builtTeam in pairs(builtTeams) do
            if builtTeam.units then
                for _, unitWrapper in pairs(builtTeam.units) do
                    local defKey = unitWrapper.unitDefId
                    local unitDef = defKey and instance._globalUnitDefs[defKey]
                    if not unitDef and defKey and instance._globalUnitDefNames then
                        local info = instance._globalUnitDefNames[defKey]
                        local numericId = info and info.id
                        if numericId then
                            unitDef = instance._globalUnitDefs[numericId]
                            unitWrapper.unitDefId = numericId
                        end
                    end

                    if unitDef then
                        unitWrapper.unitDefName = unitWrapper.unitDefName or unitDef.name or defKey
                        unitWrapper.unitDefId = unitDef.id or unitWrapper.unitDefId
                        for k, v in pairs(unitDef) do
                            if unitWrapper[k] == nil then
                                unitWrapper[k] = v
                            end
                        end
                        unitWrapper.unitDef = unitDef
                    else
                        unitWrapper.unitDefName = unitWrapper.unitDefName or tostring(defKey)
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
        end,
        GetLoggedMessages = function()
            return instance.logMessages
        end,
        GetTeamRulesParam = function(teamID, key)
            return rulesParams[teamID] and rulesParams[teamID][key] or nil
        end,
        SetTeamRulesParam = function(teamID, key, value)
            rulesParams[teamID] = rulesParams[teamID] or {}
            rulesParams[teamID][key] = value
        end,
        GetTeamList = function()
            local teams = {}
            local i = 1
            for _, teamData in pairs(builtTeams) do
                teams[i] = {
                    id = teamData.id,
                    name = teamData.playerName or ("Team " .. teamData.id),
                    leader = teamData.leader or teamData.id,
                    isDead = teamData.isDead or false,
                    isAI = not teamData.isHuman,
                    side = teamData.side or "arm",
                    allyTeam = teamData.allyTeam or teamData.id,
                }
                i = i + 1
            end
            return teams
        end,
        GetPlayerInfo = function(playerID, getPlayerOpts)
            for _, teamData in pairs(builtTeams) do
                if teamData.players then
                    for _, player in ipairs(teamData.players) do
                        if player.id == playerID then
                            local name = player.name or ("Player " .. tostring(playerID))
                            local active = player.active ~= false
                            local spectator = player.spectator or false
                            local teamID = teamData.id
                            local allyTeamID = teamData.allyTeam or teamID
                            local pingTime = player.pingTime or 0
                            local cpuUsage = player.cpuUsage or 0
                            local country = player.country or "XX"
                            local rank = player.rank or 0
                            local hasSkirmishAIsInTeam = player.hasSkirmishAIsInTeam or false
                            local playerOpts = player.playerOpts or {}
                            local desynced = player.desynced or false
                            return name, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country, rank, hasSkirmishAIsInTeam, playerOpts, desynced
                        end
                    end
                end
            end
            return ("Player " .. tostring(playerID)), false, true, -1, -1, 0, 0, "XX", 0, false, {}, false
        end,

        GetTeamResources = function(teamID, resourceType)
            local data = getTeamResourceData(teamID, resourceType)
            return data.current, data.storage, data.pull, data.income, data.expense, data.share, data.sent, data.received, data.excess
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
        end,
        GetUnitDefNames = function()
            return instance._globalUnitDefNames
        end
    }

    -- Make built teams accessible for testing/debugging
    mock._builtTeams = builtTeams

    -- Add functions that reference other functions in the table
    mock.GetPlayerList = function(teamID)
        if teamID then
            local teamData = mock._builtTeams[teamID]
            if not teamData then return {} end
            local players = teamData.players or {}
            local ids = {}
            for i, player in ipairs(players) do
                ids[i] = player.id
            end
            if #ids == 0 then
                ids[1] = teamData.leader or teamID
            end
            return ids
        end

        local all = {}
        for _, teamData in pairs(mock._builtTeams) do
            local players = teamData.players or {}
            if #players > 0 then
                for _, player in ipairs(players) do
                    table.insert(all, player.id)
                end
            else
                table.insert(all, teamData.leader or teamData.id)
            end
        end
        return all
    end

    mock.GetTeamUnits = function(teamID)
        local teamData = mock._builtTeams[teamID]
        if not teamData or not teamData.units then
            return {}
        end

        -- Return an array of unitIDs, mirroring the engine API
        local unitIds = {}
        local i = 1
        for unitID in pairs(teamData.units) do
            unitIds[i] = unitID
            i = i + 1
        end
        return unitIds
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
        for _, teamBuilder in pairs(bt) do
            if teamBuilder.units then
                local unitWrapper = teamBuilder.units[unitID]
                if unitWrapper then
                    local id = unitWrapper.unitDefId
                    if type(id) == "number" then
                        return id
                    end
                    local name = unitWrapper.unitDefName or unitWrapper.unitDefId
                    if instance._globalUnitDefNames and name and instance._globalUnitDefNames[name] then
                        id = instance._globalUnitDefNames[name].id
                        unitWrapper.unitDefId = id
                        return id
                    end
                    if unitWrapper.unitDef and type(unitWrapper.unitDef.id) == "number" then
                        unitWrapper.unitDefId = unitWrapper.unitDef.id
                        return unitWrapper.unitDefId
                    end
                    return id
                end
            end
        end
        return nil
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

    mock.AreTeamsAllied = function(team1ID, team2ID)
        if team1ID == team2ID then return true end
        -- Check explicit alliance settings first
        if instance.alliances[team1ID] and instance.alliances[team1ID][team2ID] ~= nil then
            return instance.alliances[team1ID][team2ID]
        end
        return false
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
    if not _G.Spring.GetConfigInt then
        _G.Spring.GetConfigInt = function(name, default) return default or 0 end
    end
    _G.Spring.Utilities = _G.Spring.Utilities or { Gametype = { IsScavengers = function() return false end, IsRaptors = function() return false end, GetCurrentHolidays = function() return {} end } }

    -- Mock VFS.Include cache to intercept system.lua load
    local originalVFSInclude = _G.VFS.Include
    _G.VFS.Include = function(path, ...)
        if path == "gamedata/system.lua" then
            return {
                lowerkeys = function(t) return t end,
                reftable = function(ref, tbl)
                    tbl = tbl or {}
                    setmetatable(tbl, { __index = ref })
                    return tbl
                end,
                VFS = _G.VFS,
                Spring = _G.Spring,
                -- Export standard Lua libs as system.lua does
                pairs = pairs,
                ipairs = ipairs,
                math = math,
                table = table,
                string = string,
                tonumber = tonumber,
                tostring = tostring,
                type = type,
                unpack = unpack or table.unpack,
                print = print,
                error = error,
                pcall = pcall,
                select = select,
                next = next,
                require = require
            }
        end
        if originalVFSInclude then
            return originalVFSInclude(path, ...)
        end
        -- Fallback if original was nil (unlikely given setup)
        return {}
    end

    _G.LOG = _G.LOG or { DEBUG = "DEBUG", INFO = "INFO", WARNING = "WARNING", ERROR = "ERROR" }
    _G.Game = _G.Game or {}
    _G.Game.gameSpeed = _G.Game.gameSpeed or 30
    -- Make sure these are available in the environment
    _G.pairs = pairs
    _G.ipairs = ipairs
    _G.math = math
    _G.table = table
    _G.string = string
    _G.type = type
    _G.tostring = tostring
    _G.tonumber = tonumber
    _G.unpack = unpack or table.unpack
    _G.print = print
    _G.error = error
    _G.pcall = pcall
    _G.select = select
    _G.next = next
    _G.require = require

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
                self._globalUnitDefs = buildUnitDefIndex(_G.UnitDefs, _G.UnitDefNames)
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
