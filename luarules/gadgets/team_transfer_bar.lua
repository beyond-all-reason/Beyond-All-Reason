function gadget:GetInfo()
    return {
        name = "BAR Team Transfer Handler", 
        desc = "Complete team transfer implementation for BAR - replaces deprecated engine logic and consolidates all transfer commands",
        author = "Claude-4-Sonnet",
        date = "2025",
        license = "GPL v2 or later",
        layer = -1001,
        enabled = true
    }
end





if gadgetHandler:IsSyncedCode() then
    local BARTransfer = {}
    
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
    
    BARTransfer.validators = {}
    
    function BARTransfer.IsTransferReason(reason)
        return reason == BARTransfer.REASON.GIVEN or 
               reason == BARTransfer.REASON.IDLE_PLAYER_TAKEOVER or
               reason == BARTransfer.REASON.TAKEN or 
               reason == BARTransfer.REASON.SOLD
    end
    
    function BARTransfer.RegisterValidator(name, validatorFunc)
        BARTransfer.validators[name] = validatorFunc
        Spring.Log("BARTransfer", LOG.INFO, "Registered validator: " .. name)
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
    
    function BARTransfer.ChangeTeamWithReason(unitID, oldTeam, newTeam, reason)
        if reason == BARTransfer.REASON.TAKEN then
            return BARTransfer.HandleTakeTransfer(unitID, oldTeam, newTeam)
        elseif reason == BARTransfer.REASON.SOLD then
            return BARTransfer.HandleMarketTransfer(unitID, oldTeam, newTeam)
        elseif reason == BARTransfer.REASON.SCAVENGED then
            return BARTransfer.HandleScavengerTransfer(unitID, oldTeam, newTeam)
        elseif reason == BARTransfer.REASON.UPGRADED then
            return BARTransfer.HandleUpgradeTransfer(unitID, oldTeam, newTeam)
        elseif reason == BARTransfer.REASON.CAPTURED then
            return BARTransfer.HandleCaptureTransfer(unitID, oldTeam, newTeam)
        elseif reason == BARTransfer.REASON.GIVEN then
            return BARTransfer.HandleGivenTransfer(unitID, oldTeam, newTeam)
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
    }
}

function gadget:Initialize()
    for cmdName, cmdDef in pairs(commands) do
        Script.AddSyncedActionFallback(cmdDef.fallback, function(msg, playerID)
            return BARTransfer.ProcessCommand(msg, playerID, cmdDef)
        end)
        Spring.Log("BARTransfer", LOG.INFO, "Registered command: /" .. cmdName)
    end
    
    Spring.Log("BARTransfer", LOG.INFO, "Team transfer handler loaded - using direct AllowUnitTransfer callin")
end

function gadget:Shutdown()
    for cmdName, cmdDef in pairs(commands) do
        Script.RemoveSyncedActionFallback(cmdDef.fallback)
    end
end
    
    function BARTransfer.HandleTakeTransfer(unitID, oldTeam, newTeam)
        -- Validate ally teams (based on cmd_take.lua)
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
    
    function BARTransfer.HandleMarketTransfer(unitID, oldTeam, newTeam)

        if not Spring.IsUnitValid(unitID) then
            return false
        end
        

        if not Spring.AreTeamsAllied(oldTeam, newTeam) then
            Spring.Log("BARTransfer", LOG.WARNING, "Market transfer blocked: Teams not allied")
            return false
        end
        

        Spring.Log("BARTransfer", LOG.INFO, "Market transfer: Unit " .. unitID .. " sold from team " .. oldTeam .. " to team " .. newTeam)
        return true
    end
    
    function BARTransfer.HandleScavengerTransfer(unitID, oldTeam, newTeam)

        if Spring.IsUnitValid(unitID) then

            Spring.SetUnitHealth(unitID, {capture = 0.95})
            local maxHealth = Spring.GetUnitMaxHealth(unitID)
            Spring.SetUnitHealth(unitID, {health = maxHealth})
            

            Spring.Log("BARTransfer", LOG.INFO, "Scavenger transfer: Unit " .. unitID .. " captured from team " .. oldTeam .. " to team " .. newTeam)
        end
        return true
    end
    
    function BARTransfer.HandleUpgradeTransfer(unitID, oldTeam, newTeam)

        if not _G.transferredUnits then
            _G.transferredUnits = {}
        end
        _G.transferredUnits[unitID] = Spring.GetGameFrame()
        
        Spring.Log("BARTransfer", LOG.INFO, "Upgrade transfer: Unit " .. unitID .. " ownership from team " .. oldTeam .. " to team " .. newTeam)
        return true
    end
    
    function BARTransfer.HandleCaptureTransfer(unitID, oldTeam, newTeam)
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
    
    function BARTransfer.HandleReclaimedTransfer(unitID, oldTeam, newTeam)
        Spring.Log("BARTransfer", LOG.INFO, "Reclaimed transfer: Unit " .. unitID .. " reclaimed from team " .. oldTeam .. " to team " .. newTeam)
        return true
    end
    
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
    
    function BARTransfer.HandleDecorationTransfer(unitID, oldTeam, newTeam)
        -- DECORATION transfers (hats, xmas balls, etc.) - usually to Gaia team
        -- These are non-gameplay transfers that should always succeed
        Spring.Log("BARTransfer", LOG.INFO, "Decoration transfer: Unit " .. unitID .. " from team " .. oldTeam .. " to team " .. newTeam)
        return true
    end
    
    function BARTransfer.HandleIdlePlayerTakeoverTransfer(unitID, oldTeam, newTeam)
        -- IDLE_PLAYER_TAKEOVER transfers - special case of take command
        -- Reuse the same validation as take command
        local oldAllyTeam = select(4, Spring.GetTeamInfo(oldTeam))
        local newAllyTeam = select(4, Spring.GetTeamInfo(newTeam))
        
        if oldAllyTeam ~= newAllyTeam then
            Spring.Log("BARTransfer", LOG.WARNING, "Idle takeover blocked: Can only take from allied teams")
            return false
        end
        
        -- Check if old team has human players (should be idle)
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
    
    function BARTransfer.GetTargetTeams(playerData, targetParam, cmdDef)
        local targetTeams = {}
        local targetTeamID = (targetParam and targetParam ~= "") and tonumber(targetParam) or nil
        
        if cmdDef.target_selection == "specify_team" then
            if targetTeamID and Spring.GetTeamInfo(targetTeamID) then
                table.insert(targetTeams, targetTeamID)
            end
        elseif cmdDef.target_selection == "auto_idle_teams" then
            -- Take command logic: find idle allied teams
            local teamList = targetTeamID and {targetTeamID} or Spring.GetTeamList(playerData.allyTeamID)
            for _, teamID in ipairs(teamList) do
                if teamID ~= playerData.teamID then
                    table.insert(targetTeams, teamID)
                end
            end
        elseif cmdDef.target_selection == "specify_team_or_all_enemies" then
            -- Capture command logic
            if targetTeamID then
                if Spring.GetTeamInfo(targetTeamID) and not Spring.AreTeamsAllied(playerData.teamID, targetTeamID) then
                    table.insert(targetTeams, targetTeamID)
                end
            else
                -- All enemy teams
                for _, teamID in ipairs(Spring.GetTeamList()) do
                    if teamID ~= playerData.teamID and not Spring.AreTeamsAllied(playerData.teamID, teamID) then
                        table.insert(targetTeams, teamID)
                    end
                end
            end
        end
        
        return targetTeams
    end
    
    function BARTransfer.ExecuteTransfers(playerData, targetTeams, cmdDef)
        local totalTransferred = 0
        
        for _, teamID in ipairs(targetTeams) do
            local units = {}
            
            if cmdDef.scope == "all_team_units" then
                units = Spring.GetTeamUnits(teamID)
            elseif cmdDef.scope == "selected_units" then
                units = Spring.GetSelectedUnits()
                -- Filter to only units from the correct team
                local filteredUnits = {}
                for _, unitID in ipairs(units) do
                    if Spring.GetUnitTeam(unitID) == (teamID == playerData.teamID and playerData.teamID or teamID) then
                        table.insert(filteredUnits, unitID)
                    end
                end
                units = filteredUnits
            end
            
            -- Transfer units
            for _, unitID in ipairs(units) do
                local success = Spring.TransferUnitWithReason(unitID, playerData.teamID, cmdDef.reason)
                if success then
                    totalTransferred = totalTransferred + 1
                end
            end
            
            -- Transfer resources if specified
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