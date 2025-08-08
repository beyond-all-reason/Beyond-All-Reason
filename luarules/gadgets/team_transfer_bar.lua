local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name = "BAR Team Transfer Handler", 
        desc = "Clean team transfer implementation - consolidated but well-organized",
        author = "Claude-4-Sonnet",
        date = "2025",
        license = "GPL v2 or later",
        layer = -1001,
        enabled = true
    }
end

if gadgetHandler:IsSyncedCode() then

-- ============================================================================
-- DOMAIN: Core Business Logic and Configuration
-- ============================================================================

    local BARTransfer = {}
    
-- Transfer reasons (business domain)
    BARTransfer.REASON = {
        RECLAIMED            = 0, -- When unit wreckage is reclaimed and converted to resources
        GIVEN                = 1, -- When player explicitly shares units with allies via give command or team death
        CAPTURED             = 2, -- When builders capture enemy structures through construction
        IDLE_PLAYER_TAKEOVER = 3, -- When units transfer to active ally after player goes idle/drops
        TAKEN                = 4, -- When player uses take command to claim units from idle allies  
        SOLD                 = 5, -- When units are sold through the marketplace system
        SCAVENGED            = 6, -- When scavenger AI captures player units during raids
        UPGRADED             = 7, -- When unit ownership transfers during mex/geo upgrade process
        DECORATION           = 8, -- When decorative units (hats) transfer between players
        DEV_TRANSFER         = 9, -- When developers use transferunits command for testing/admin
    }
    
-- Configuration state
BARTransfer.config = {
    allowResourceSharing = true,
    allowUnitSharing = true,
    allowEnemyResourceSharing = false,
    allowEnemyUnitSharing = false,
    allowBuilderSharing = false,
    shareDelaySeconds = 0,
    enabled = true
}

BARTransfer.devConfig = {
    noCostEnabled = false
}

-- Validator registry
BARTransfer.validators = {}
BARTransfer.lastRefusals = {}

-- ============================================================================
-- TECHNICAL SERVICE: Spring API Integration
-- ============================================================================

-- Command definitions (technical configuration)
local commands = {
    take = {
        reason = BARTransfer.REASON.TAKEN,
        prefix = "take",
        scope = "all_team_units",
        validation = {"allied_only", "no_human_players"},
        resources = true,
        target_selection = "auto_idle_teams",
        fallback = "take"
    },
    capture = {
        reason = BARTransfer.REASON.CAPTURED, 
        prefix = "capture",
        scope = "all_team_units",
        validation = {"enemy_only"},
        resources = true,
        target_selection = "specify_team_or_all_enemies",
        fallback = "capture"
    },
    give = {
        reason = BARTransfer.REASON.GIVEN,
        prefix = "give", 
        scope = "selected_units",
        validation = {"valid_team"},
        target_selection = "specify_team",
        fallback = "give"
    },
    transferunits = {
        reason = BARTransfer.REASON.DEV_TRANSFER,
        prefix = "transferunits",
        scope = "selected_units",
        validation = {"dev_only"},
        target_selection = "specify_team",
        fallback = "transferunits"
    },
    share = {
        reason = BARTransfer.REASON.GIVEN,
        prefix = "share",
        scope = "selected_units",
        validation = {"valid_team"},
        target_selection = "specify_team",
        fallback = "share"
    },
    aishare = {
        reason = BARTransfer.REASON.GIVEN,
        prefix = "aishare",
        scope = "all_team_units",
        validation = {"valid_team"},
        target_selection = "specify_team",
        fallback = "aishare"
    }
}

-- ============================================================================
-- DOMAIN: Business Logic Functions
-- ============================================================================

function BARTransfer.RegisterValidator(name, validatorFunc)
    BARTransfer.validators[name] = validatorFunc
    Spring.Log("BARTransfer", LOG.INFO, "Registered validator: " .. name)
end

function BARTransfer.AddRefusal(team, msg)
    local frameNum = Spring.GetGameFrame()
    local lastRefusal = BARTransfer.lastRefusals[team]
    if ((not lastRefusal) or (lastRefusal ~= frameNum)) then
        BARTransfer.lastRefusals[team] = frameNum
        Spring.SendMessageToTeam(team, msg)
    end
end

function BARTransfer.AllowResourceTransfer(oldTeam, newTeam, resourceType, amount)
    if not BARTransfer.config.enabled then
        return true
    end
    
    if not BARTransfer.config.allowResourceSharing then
        Spring.SendMessageToTeam(oldTeam, "Resource sharing has been disabled")
        return false
    end
    
    if BARTransfer.config.allowEnemyResourceSharing or Spring.AreTeamsAllied(oldTeam, newTeam) then
        return true
    else
        Spring.SendMessageToTeam(oldTeam, "Cannot give resources to enemies")
        return false
    end
end

-- ============================================================================
-- DOMAIN: Transfer Handler Dispatch
-- ============================================================================

function BARTransfer.ChangeTeamWithReason(unitID, oldTeam, newTeam, reason)
    if reason == BARTransfer.REASON.TAKEN then
        return BARTransfer.HandleTakeTransfer(unitID, oldTeam, newTeam)
    elseif reason == BARTransfer.REASON.SOLD then
        return BARTransfer.HandleSoldTransfer(unitID, oldTeam, newTeam)
    elseif reason == BARTransfer.REASON.CAPTURED then
        return BARTransfer.HandleCapturedTransfer(unitID, oldTeam, newTeam)
    elseif reason == BARTransfer.REASON.GIVEN then
        return BARTransfer.HandleGivenTransfer(unitID, oldTeam, newTeam)
    elseif reason == BARTransfer.REASON.SCAVENGED then
        return BARTransfer.HandleScavengedTransfer(unitID, oldTeam, newTeam)
    elseif reason == BARTransfer.REASON.UPGRADED then
        return BARTransfer.HandleUpgradedTransfer(unitID, oldTeam, newTeam)
    elseif reason == BARTransfer.REASON.RECLAIMED then
        return BARTransfer.HandleReclaimedTransfer(unitID, oldTeam, newTeam)
    elseif reason == BARTransfer.REASON.DECORATION then
        return BARTransfer.HandleDecorationTransfer(unitID, oldTeam, newTeam)
    elseif reason == BARTransfer.REASON.IDLE_PLAYER_TAKEOVER then
        return BARTransfer.HandleIdlePlayerTakeoverTransfer(unitID, oldTeam, newTeam)
    elseif reason == BARTransfer.REASON.DEV_TRANSFER then
        Spring.Log("BARTransfer", LOG.INFO, "Dev transfer: Unit " .. unitID .. " from team " .. oldTeam .. " to team " .. newTeam)
        return true
    end
    
    Spring.Log("BARTransfer", LOG.WARNING, "Unknown transfer reason: " .. tostring(reason))
    return true
end

-- ============================================================================
-- DOMAIN: Specific Transfer Handlers  
-- ============================================================================
    
    function BARTransfer.HandleTakeTransfer(unitID, oldTeam, newTeam)
        local oldAllyTeam = select(4, Spring.GetTeamInfo(oldTeam))
        local newAllyTeam = select(4, Spring.GetTeamInfo(newTeam))
        
        if oldAllyTeam ~= newAllyTeam then
            Spring.Log("BARTransfer", LOG.WARNING, "Take blocked: Can only take from allied teams")
            return false
        end

        for _, pid in ipairs(Spring.GetPlayerList()) do
            local name, active, spec, teamID, allyTeamID, income, isAI = Spring.GetPlayerInfo(pid)
            if teamID == oldTeam and (type(isAI) ~= 'boolean' or isAI == false) then
                Spring.Log("BARTransfer", LOG.WARNING, "Take blocked: Team " .. oldTeam .. " has human players")
                return false
            end
        end
        
        Spring.Log("BARTransfer", LOG.INFO, "Take transfer: Unit " .. unitID .. " from team " .. oldTeam .. " to team " .. newTeam)
        return true
    end
    
function BARTransfer.HandleSoldTransfer(unitID, oldTeam, newTeam)
    if not Spring.ValidUnitID(unitID) then
            return false
        end

        if not Spring.AreTeamsAllied(oldTeam, newTeam) then
            Spring.Log("BARTransfer", LOG.WARNING, "Market transfer blocked: Teams not allied")
            return false
        end

        Spring.Log("BARTransfer", LOG.INFO, "Market transfer: Unit " .. unitID .. " sold from team " .. oldTeam .. " to team " .. newTeam)
        return true
    end
    
function BARTransfer.HandleCapturedTransfer(unitID, oldTeam, newTeam)
        local oldAllyTeam = select(4, Spring.GetTeamInfo(oldTeam))
        local newAllyTeam = select(4, Spring.GetTeamInfo(newTeam))
        
        if oldAllyTeam == newAllyTeam then
            Spring.Log("BARTransfer", LOG.WARNING, "Capture blocked: Cannot capture from allied teams")
            return false
        end
        
        Spring.Log("BARTransfer", LOG.INFO, "Capture transfer: Unit " .. unitID .. " captured from enemy team " .. oldTeam .. " to team " .. newTeam)
        return true
    end
    
    function BARTransfer.HandleGivenTransfer(unitID, oldTeam, newTeam)
        if Spring.IsTeamFull and Spring.IsTeamFull(newTeam) then
            Spring.Log("BARTransfer", LOG.WARNING, "Given transfer blocked: Team " .. newTeam .. " is at unit capacity")
            return false
        end
        
        Spring.Log("BARTransfer", LOG.INFO, "Given transfer: Unit " .. unitID .. " shared from team " .. oldTeam .. " to team " .. newTeam)
        return true
    end

function BARTransfer.HandleScavengedTransfer(unitID, oldTeam, newTeam)
    if Spring.ValidUnitID(unitID) then
        Spring.SetUnitHealth(unitID, {capture = 0.95})
        local maxHealth = Spring.GetUnitMaxHealth(unitID)
        Spring.SetUnitHealth(unitID, {health = maxHealth})
        
        Spring.Log("BARTransfer", LOG.INFO, "Scavenger transfer: Unit " .. unitID .. " captured from team " .. oldTeam .. " to team " .. newTeam)
    end
    return true
end

function BARTransfer.HandleUpgradedTransfer(unitID, oldTeam, newTeam)
    if not _G.transferredUnits then
        _G.transferredUnits = {}
    end
    _G.transferredUnits[unitID] = Spring.GetGameFrame()
    
    Spring.Log("BARTransfer", LOG.INFO, "Upgrade transfer: Unit " .. unitID .. " ownership from team " .. oldTeam .. " to team " .. newTeam)
    return true
end
    
    function BARTransfer.HandleReclaimedTransfer(unitID, oldTeam, newTeam)
        Spring.Log("BARTransfer", LOG.INFO, "Reclaimed transfer: Unit " .. unitID .. " reclaimed from team " .. oldTeam .. " to team " .. newTeam)
        return true
    end
    
    function BARTransfer.HandleDecorationTransfer(unitID, oldTeam, newTeam)
        Spring.Log("BARTransfer", LOG.INFO, "Decoration transfer: Unit " .. unitID .. " from team " .. oldTeam .. " to team " .. newTeam)
        return true
    end
    
    function BARTransfer.HandleIdlePlayerTakeoverTransfer(unitID, oldTeam, newTeam)
        local oldAllyTeam = select(4, Spring.GetTeamInfo(oldTeam))
        local newAllyTeam = select(4, Spring.GetTeamInfo(newTeam))
        
        if oldAllyTeam ~= newAllyTeam then
            Spring.Log("BARTransfer", LOG.WARNING, "Idle takeover blocked: Can only take from allied teams")
            return false
        end
        
        for _, pid in ipairs(Spring.GetPlayerList()) do
            local name, active, spec, teamID, allyTeamID, income, isAI = Spring.GetPlayerInfo(pid)
            if teamID == oldTeam and (type(isAI) ~= 'boolean' or isAI == false) and active then
                Spring.Log("BARTransfer", LOG.WARNING, "Idle takeover blocked: Team " .. oldTeam .. " has active human players")
                return false
            end
        end
        
        Spring.Log("BARTransfer", LOG.INFO, "Idle player takeover: Unit " .. unitID .. " from team " .. oldTeam .. " to team " .. newTeam)
        return true
    end

-- ============================================================================
-- VALIDATORS: Business Rules
-- ============================================================================

function BARTransfer.RegisterBuiltInValidators()
    BARTransfer.RegisterValidator("share_control", function(unitID, unitDefID, oldTeam, newTeam, reason)
        if not BARTransfer.config.enabled then
            return true
        end
        
        if reason ~= BARTransfer.REASON.GIVEN then
            return true
        end
        
        if Spring.IsCheatingEnabled() then
            return true
        end
        
        if not BARTransfer.config.allowUnitSharing then
            BARTransfer.AddRefusal(oldTeam, "Unit sharing has been disabled")
            return false
        end
        
        if BARTransfer.config.allowEnemyUnitSharing or Spring.AreTeamsAllied(oldTeam, newTeam) then
            return true
        end
        
        BARTransfer.AddRefusal(oldTeam, "Cannot give units to enemies")
        return false
    end)
    
    BARTransfer.RegisterValidator("no_builders", function(unitID, unitDefID, oldTeam, newTeam, reason)
        if not BARTransfer.config.allowBuilderSharing and reason == BARTransfer.REASON.GIVEN then
            local unitDef = UnitDefs[unitDefID]
            if unitDef and (unitDef.isBuilder or unitDef.isFactory) then
                BARTransfer.AddRefusal(oldTeam, "Sharing builders and factories is disabled")
                return false
            end
        end
        return true
    end)
end

-- ============================================================================
-- TECHNICAL SERVICE: Command Processing Infrastructure
-- ============================================================================
    
    function BARTransfer.GetPlayerData(playerID)
        local actualPlayerID = -1
        local playerData = {}
        
        if playerID == 0 then
            for _, pid in ipairs(Spring.GetPlayerList()) do
                local name, active, spec, teamID, allyTeamID, income, isAI = Spring.GetPlayerInfo(pid)
                if type(isAI) ~= 'boolean' or isAI == false then
                    actualPlayerID = pid
                    playerData = { playerID = pid, teamID = teamID, allyTeamID = allyTeamID, name = name }
                    break
                end
            end
        else
            actualPlayerID = playerID
            local name, active, spec, teamID, allyTeamID = Spring.GetPlayerInfo(playerID)
            playerData = { playerID = playerID, teamID = teamID, allyTeamID = allyTeamID, name = name }
        end
        
        return actualPlayerID ~= -1 and playerData or nil
    end

function BARTransfer.GetTargetTeams(playerData, targetParam, cmdDef)
    local targetTeams = {}
    local targetTeamID = (targetParam and targetParam ~= "") and tonumber(targetParam) or nil
    
    if cmdDef.target_selection == "specify_team" then
        if targetTeamID and Spring.GetTeamInfo(targetTeamID) then
            table.insert(targetTeams, targetTeamID)
        end
    elseif cmdDef.target_selection == "auto_idle_teams" then
        local teamList = targetTeamID and {targetTeamID} or Spring.GetTeamList(playerData.allyTeamID)
        for _, teamID in ipairs(teamList) do
            if teamID ~= playerData.teamID then
                table.insert(targetTeams, teamID)
            end
        end
    elseif cmdDef.target_selection == "specify_team_or_all_enemies" then
        if targetTeamID then
            if Spring.GetTeamInfo(targetTeamID) and not Spring.AreTeamsAllied(playerData.teamID, targetTeamID) then
                table.insert(targetTeams, targetTeamID)
            end
        else
            for _, teamID in ipairs(Spring.GetTeamList()) do
                if teamID ~= playerData.teamID and not Spring.AreTeamsAllied(playerData.teamID, teamID) then
                    table.insert(targetTeams, teamID)
                end
            end
        end
    end
    
    return targetTeams
end
    
    function BARTransfer.ValidateCommandPermissions(playerData, targetTeams, cmdDef)
        if not cmdDef.validation then return true end

        for _, validationRule in ipairs(cmdDef.validation) do
            if validationRule == "dev_only" and not Spring.IsCheatingEnabled() then
                Spring.SendMessageToPlayer(playerData.playerID, "You do not have permission to use this command.")
                return false
            elseif validationRule == "allied_only" then
                for _, teamID in ipairs(targetTeams) do
                    if not Spring.AreTeamsAllied(playerData.teamID, teamID) then
                        Spring.SendMessageToPlayer(playerData.playerID, "You can only use this command on allied teams.")
                        return false
                    end
                end
            elseif validationRule == "enemy_only" then
                for _, teamID in ipairs(targetTeams) do
                    if Spring.AreTeamsAllied(playerData.teamID, teamID) then
                        Spring.SendMessageToPlayer(playerData.playerID, "You can only use this command on enemy teams.")
                        return false
                    end
                end
            elseif validationRule == "no_human_players" then
                for _, teamID in ipairs(targetTeams) do
                    for _, pid in ipairs(Spring.GetPlayerList(teamID, false)) do
                        local _, _, _, _, _, _, isAI = Spring.GetPlayerInfo(pid)
                        if type(isAI) ~= 'boolean' or isAI == false then
                            Spring.SendMessageToPlayer(playerData.playerID, "You cannot use this command on teams with active human players.")
                            return false
                        end
                    end
                end
            elseif validationRule == "valid_team" then
                if #targetTeams == 0 then
                    Spring.SendMessageToPlayer(playerData.playerID, "You must specify a valid target team.")
                    return false
                end
            end
        end

        return true
    end
    
    function BARTransfer.ExecuteTransfers(playerData, targetTeams, cmdDef)
        local totalTransferred = 0
        
        for _, teamID in ipairs(targetTeams) do
            local units = {}
            
            if cmdDef.scope == "all_team_units" then
                units = Spring.GetTeamUnits(teamID)
            elseif cmdDef.scope == "selected_units" then
                units = Spring.GetSelectedUnits()
                local filteredUnits = {}
                for _, unitID in ipairs(units) do
                    if Spring.GetUnitTeam(unitID) == (teamID == playerData.teamID and playerData.teamID or teamID) then
                        table.insert(filteredUnits, unitID)
                    end
                end
                units = filteredUnits
            end
            
            for _, unitID in ipairs(units) do
                local success = Spring.TransferUnitWithReason(unitID, playerData.teamID, cmdDef.reason)
                if success then
                    totalTransferred = totalTransferred + 1
                end
            end
            
            if cmdDef.resources then
                for _, resType in ipairs({ "metal", "energy" }) do
                    local resValue = select(1, Spring.GetTeamResources(teamID, resType))
                    if resValue and resValue > 0 then
                        Spring.AddTeamResource(teamID, resType, -resValue)
                        Spring.AddTeamResource(playerData.teamID, resType, resValue)
                    end
                end
            end
        end
        
        Spring.SendMessageToPlayer(playerData.playerID, cmdDef.prefix .. ": Transferred " .. totalTransferred .. " units from " .. #targetTeams .. " teams")
        return true
    end
    
-- ============================================================================
-- COMMAND HANDLERS: User Interface Layer
-- ============================================================================

function BARTransfer.ProcessCommand(msg, playerID, cmdDef)
    local targetParam = string.sub(msg, string.len(cmdDef.prefix) + 1):match("^%s*(%d*)%s*$")
    
    local playerData = BARTransfer.GetPlayerData(playerID)
    if not playerData then
        Spring.SendMessageToPlayer(playerID, cmdDef.prefix .. ": Error getting player data")
        return false
    end
    
    local targetTeams = BARTransfer.GetTargetTeams(playerData, targetParam, cmdDef)

    if not BARTransfer.ValidateCommandPermissions(playerData, targetTeams, cmdDef) then
        return false
    end

    return BARTransfer.ExecuteTransfers(playerData, targetTeams, cmdDef)
end

function BARTransfer.HandleShareCommand(msg, playerID)
    local args = string.sub(msg, 7):match("^%s*(.-)%s*$") -- Remove "share " prefix
    local words = {}
    for word in args:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if #words < 3 then
        Spring.SendMessageToPlayer(playerID, "Usage: /share <toTeam> <metal> <energy> [shareUnits]")
        return true
    end
    
    local toTeamID = tonumber(words[1])
    local metalShare = tonumber(words[2])
    local energyShare = tonumber(words[3])
    local shareUnits = (words[4] == "1" or words[4] == "true")
    
    local playerData = BARTransfer.GetPlayerData(playerID)
    if not playerData then
        return true
    end
    
    if not teamHandler.IsValidTeam(toTeamID) then
        return true
    end
    
    local srcTeamID = playerData.teamID
    
    if metalShare > 0 then
        if BARTransfer.AllowResourceTransfer(srcTeamID, toTeamID, "metal", metalShare) then
            local _, mCurrent = Spring.GetTeamResources(srcTeamID, "metal")
            metalShare = math.min(metalShare, mCurrent)
            Spring.AddTeamResource(srcTeamID, "metal", -metalShare)
            Spring.AddTeamResource(toTeamID, "metal", metalShare)
        end
    end
    
    if energyShare > 0 then
        if BARTransfer.AllowResourceTransfer(srcTeamID, toTeamID, "energy", energyShare) then
            local _, eCurrent = Spring.GetTeamResources(srcTeamID, "energy")
            energyShare = math.min(energyShare, eCurrent)
            Spring.AddTeamResource(srcTeamID, "energy", -energyShare)
            Spring.AddTeamResource(toTeamID, "energy", energyShare)
        end
    end
    
    if shareUnits then
        local selectedUnits = Spring.GetSelectedUnits()
        for _, unitID in ipairs(selectedUnits) do
            local unit = Spring.GetUnit(unitID)
            if unit and unit.team == srcTeamID and not unit.beingBuilt then
                if BARTransfer.ValidateTransfer(unitID, unit.unitDefID, srcTeamID, toTeamID, BARTransfer.REASON.GIVEN) then
                    Spring.TransferUnitWithReason(unitID, toTeamID, BARTransfer.REASON.GIVEN)
                end
            end
        end
    end
    
    return true
end

function BARTransfer.HandleAIShareCommand(msg, playerID)
    local args = string.sub(msg, 9):match("^%s*(.-)%s*$") -- Remove "aishare " prefix
    local words = {}
    for word in args:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if #words < 4 then
        Spring.SendMessageToPlayer(playerID, "Usage: /aishare <srcTeam> <toTeam> <metal> <energy> [unitIDs...]")
        return true
    end
    
    local srcTeamID = tonumber(words[1])
    local toTeamID = tonumber(words[2])
    local metalShare = tonumber(words[3])
    local energyShare = tonumber(words[4])
    
    if not teamHandler.IsValidTeam(srcTeamID) or not teamHandler.IsValidTeam(toTeamID) then
        return true
    end
    
    if metalShare > 0 then
        if BARTransfer.AllowResourceTransfer(srcTeamID, toTeamID, "metal", metalShare) then
            local _, mCurrent = Spring.GetTeamResources(srcTeamID, "metal")
            metalShare = math.min(metalShare, mCurrent)
            Spring.AddTeamResource(srcTeamID, "metal", -metalShare)
            Spring.AddTeamResource(toTeamID, "metal", metalShare)
        end
    end
    
    if energyShare > 0 then
        if BARTransfer.AllowResourceTransfer(srcTeamID, toTeamID, "energy", energyShare) then
            local _, eCurrent = Spring.GetTeamResources(srcTeamID, "energy")
            energyShare = math.min(energyShare, eCurrent)
            Spring.AddTeamResource(srcTeamID, "energy", -energyShare)
            Spring.AddTeamResource(toTeamID, "energy", energyShare)
        end
    end
    
    for i = 5, #words do
        local unitID = tonumber(words[i])
        if unitID then
            local unit = Spring.GetUnit(unitID)
            if unit and unit.team == srcTeamID and not unit.beingBuilt then
                if BARTransfer.ValidateTransfer(unitID, unit.unitDefID, srcTeamID, toTeamID, BARTransfer.REASON.GIVEN) then
                    Spring.TransferUnitWithReason(unitID, toTeamID, BARTransfer.REASON.GIVEN)
                end
            end
        end
    end
    
    return true
end


function BARTransfer.HandleShareControl(msg, playerID)
    local function AllowAction(playerID)
        if (playerID ~= 0) then
            Spring.SendMessageToPlayer(playerID, "Must be the host player")
            return false
        end
        if (not Spring.IsCheatingEnabled()) then
            Spring.SendMessageToPlayer(playerID, "Cheating must be enabled")
            return false
        end
        return true
    end
    
    local function PrintState()
        Spring.Echo('Unit sharing is ' .. (BARTransfer.config.allowUnitSharing and 'enabled' or 'disabled'))
        Spring.Echo('Resource sharing is ' .. (BARTransfer.config.allowResourceSharing and 'enabled' or 'disabled'))
        Spring.Echo('Enemy unit sharing is ' .. (BARTransfer.config.allowEnemyUnitSharing and 'enabled' or 'disabled'))
        Spring.Echo('Enemy resource sharing is ' .. (BARTransfer.config.allowEnemyResourceSharing and 'enabled' or 'disabled'))
        Spring.Echo('Builder sharing is ' .. (BARTransfer.config.allowBuilderSharing and 'enabled' or 'disabled'))
        return true
    end
    
    if not AllowAction(playerID) then
        PrintState()
        return true
    end
    
    local args = string.sub(msg, 10):match("^%s*(.-)%s*$")
    local words = {}
    for word in args:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if #words == 0 then
        BARTransfer.config.allowUnitSharing = not BARTransfer.config.allowUnitSharing
        BARTransfer.config.allowResourceSharing = BARTransfer.config.allowUnitSharing
    elseif #words == 1 then
        local mode = words[1]
        if mode == "0" or mode == "none" then
            BARTransfer.config.allowResourceSharing = false
            BARTransfer.config.allowUnitSharing = false
            BARTransfer.config.allowEnemyResourceSharing = false
            BARTransfer.config.allowEnemyUnitSharing = false
        elseif mode == "1" or mode == "ally" then
            BARTransfer.config.allowResourceSharing = true
            BARTransfer.config.allowUnitSharing = true
            BARTransfer.config.allowEnemyResourceSharing = false
            BARTransfer.config.allowEnemyUnitSharing = false
        elseif mode == "2" or mode == "full" then
            BARTransfer.config.allowResourceSharing = true
            BARTransfer.config.allowUnitSharing = true
            BARTransfer.config.allowEnemyResourceSharing = true
            BARTransfer.config.allowEnemyUnitSharing = true
        end
    elseif #words >= 2 then
        local target = words[1]
        local enable = words[2] == "1" or words[2] == "true"
        
        if target == "u" or target == "unit" then
            BARTransfer.config.allowUnitSharing = enable
        elseif target == "r" or target == "resource" then
            BARTransfer.config.allowResourceSharing = enable
        elseif target == "b" or target == "builder" then
            BARTransfer.config.allowBuilderSharing = enable
        end
        
        if #words >= 3 and words[3] == "e" then
            if target == "u" or target == "unit" then
                BARTransfer.config.allowEnemyUnitSharing = enable
            elseif target == "r" or target == "resource" then
                BARTransfer.config.allowEnemyResourceSharing = enable
            end
        end
    end
    
    PrintState()
    return true
end

function BARTransfer.HandleDevCommand(msg, playerID)
    local function AllowAction(playerID)
        if (playerID ~= 0) then
            Spring.SendMessageToPlayer(playerID, "Must be the host player")
            return false
        end
        if (not Spring.IsCheatingEnabled()) then
            Spring.SendMessageToPlayer(playerID, "Cheating must be enabled")
            return false
        end
        return true
    end
    
    if not AllowAction(playerID) then
        return true
    end
    
    local args = string.sub(msg, 10):match("^%s*(.-)%s*$")
    local words = {}
    for word in args:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if #words == 0 then
        return true
    end
    
    local command = words[1]
    if command == "run" then
        local code = string.sub(args, 5)
        local chunk, err = loadstring(code, "run")
        if chunk then
            local success, result = pcall(chunk)
            if not success then
                Spring.Echo("Error: " .. tostring(result))
            end
        else
            Spring.Echo("Syntax error: " .. tostring(err))
        end
    elseif command == "echo" then
        local code = string.sub(args, 6)
        local chunk, err = loadstring("return " .. code, "echo")
        if chunk then
            local success, result = pcall(chunk)
            if success then
                Spring.Echo(tostring(result))
            else
                Spring.Echo("Error: " .. tostring(result))
            end
        else
            Spring.Echo("Syntax error: " .. tostring(err))
        end
    end
    
    return true
end

function BARTransfer.HandleNoCostCommand(msg, playerID)
    local function AllowAction(playerID)
        if (playerID ~= 0) then
            Spring.SendMessageToPlayer(playerID, "Must be the host player")
            return false
        end
        if (not Spring.IsCheatingEnabled()) then
            Spring.SendMessageToPlayer(playerID, "Cheating must be enabled")
            return false
        end
        return true
    end
    
    if not AllowAction(playerID) then
        Spring.Echo('NoCost is ' .. (BARTransfer.devConfig.noCostEnabled and 'enabled' or 'disabled'))
        return true
    end
    
    local args = string.sub(msg, 4):match("^%s*(.-)%s*$")
    local words = {}
    for word in args:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if #words <= 0 then
        BARTransfer.devConfig.noCostEnabled = not BARTransfer.devConfig.noCostEnabled
    else
        BARTransfer.devConfig.noCostEnabled = (words[1] == '1')
    end
    
    Spring.Echo('NoCost is ' .. (BARTransfer.devConfig.noCostEnabled and 'enabled' or 'disabled'))
    return true
end

-- ============================================================================
-- GADGET LIFECYCLE AND CALLINS
-- ============================================================================

function gadget:Initialize()
    for cmdName, cmdDef in pairs(commands) do
        Script.AddSyncedActionFallback(cmdDef.fallback, function(msg, playerID)
            return BARTransfer.ProcessCommand(msg, playerID, cmdDef)
        end)
        Spring.Log("BARTransfer", LOG.INFO, "Registered command: /" .. cmdName)
    end
    
    Script.AddSyncedActionFallback("sharectrl", function(msg, playerID)
        return BARTransfer.HandleShareControl(msg, playerID)
    end)
    
    Script.AddSyncedActionFallback("luarules", function(msg, playerID)
        return BARTransfer.HandleDevCommand(msg, playerID)
    end)
    
    Script.AddSyncedActionFallback("nc", function(msg, playerID)
        return BARTransfer.HandleNoCostCommand(msg, playerID)
    end)

    Script.AddSyncedActionFallback("share", function(msg, playerID)
        return BARTransfer.HandleShareCommand(msg, playerID)
    end)
    
    Script.AddSyncedActionFallback("aishare", function(msg, playerID)
        return BARTransfer.HandleAIShareCommand(msg, playerID)
    end)
    
    BARTransfer.RegisterBuiltInValidators()
    
    Spring.Log("BARTransfer", LOG.INFO, "Team transfer handler loaded - using direct AllowUnitTransfer callin")
end

function gadget:Shutdown()
    for cmdName, cmdDef in pairs(commands) do
        Script.RemoveSyncedActionFallback(cmdDef.fallback)
    end
    Script.RemoveSyncedActionFallback("sharectrl")
    Script.RemoveSyncedActionFallback("luarules")
    Script.RemoveSyncedActionFallback("nc")
    Script.RemoveSyncedActionFallback("share")
    Script.RemoveSyncedActionFallback("aishare")
end

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, reason)
    for name, validator in pairs(BARTransfer.validators) do
        if not validator(unitID, unitDefID, oldTeam, newTeam, reason) then
            Spring.Log("BARTransfer", LOG.INFO, "Transfer rejected by validator: " .. name)
            return false
        end
    end

    return BARTransfer.ChangeTeamWithReason(unitID, oldTeam, newTeam, reason)
end

function gadget:AllowResourceTransfer(oldTeam, newTeam, resourceType, amount)
    return BARTransfer.AllowResourceTransfer(oldTeam, newTeam, resourceType, amount)
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if BARTransfer.devConfig.noCostEnabled then
        Spring.SetUnitCosts(unitID, {
            buildTime  = 1,
            metalCost  = 1,
            energyCost = 1
        })
    end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
    if BARTransfer.devConfig.noCostEnabled then
        local unitDef = UnitDefs[unitDefID]
        if unitDef then
            Spring.SetUnitCosts(unitID, {
                buildTime  = unitDef.buildTime,
                metalCost  = unitDef.metalCost,
                energyCost = unitDef.energyCost
            })
        end
    end
end

    GG.BARTransfer = BARTransfer

else -- UNSYNCED

    local commands = {
        take = { prefix = "take" },
        capture = { prefix = "capture" },
        give = { prefix = "give" }
    }

    function gadget:GotChatMsg(msg, playerID)
        for cmdName, cmdDef in pairs(commands) do
            if string.sub(msg, 1, string.len(cmdDef.prefix)) == cmdDef.prefix then
                local params = string.sub(msg, string.len(cmdDef.prefix) + 1)
                Spring.SendLuaRulesMsg(cmdName .. ":" .. (params or ""))
                return true
            end
        end
        return false
    end

end