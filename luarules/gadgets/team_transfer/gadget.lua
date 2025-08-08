local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name = "Team Transfer",
        desc = "Centralized team and resource transfer system",
        author = "BAR Team",
        date = "2025",
        license = "GPL v2 or later",
        layer = -1001,
        enabled = true
    }
end

if gadgetHandler:IsSyncedCode() then

    local TeamTransfer = VFS.Include("LuaRules/Gadgets/team_transfer/definitions.lua")
    local Units = VFS.Include("LuaRules/Gadgets/team_transfer/units.lua")
    local Resources = VFS.Include("LuaRules/Gadgets/team_transfer/resources.lua")
    local Teammates = VFS.Include("LuaRules/Gadgets/team_transfer/teammates.lua")
    local Registry = VFS.Include("LuaRules/Gadgets/team_transfer/registry.lua")



    local commands = {
        take = { 
            reason = TeamTransfer.REASON.TAKEN, 
            prefix = "take", 
            scope = "all_team_units", 
            validation = {"allied_only", "no_human_players"}, 
            resources = true, 
            target_selection = "auto_idle_teams", 
            fallback = "take" 
        },
        capture = { 
            reason = TeamTransfer.REASON.CAPTURED, 
            prefix = "capture", 
            scope = "all_team_units", 
            validation = {"enemy_only"}, 
            resources = true, 
            target_selection = "specify_team_or_all_enemies", 
            fallback = "capture" 
        },
        give = { 
            reason = TeamTransfer.REASON.GIVEN, 
            prefix = "give", 
            scope = "selected_units", 
            validation = {"valid_team"}, 
            target_selection = "specify_team", 
            fallback = "give" 
        },
        aishare = { 
            reason = TeamTransfer.REASON.GIVEN, 
            prefix = "aishare", 
            scope = "all_team_units", 
            validation = {"valid_team"}, 
            target_selection = "specify_team", 
            fallback = "aishare" 
        },
    }

    local function ValidateCommandPermissions(playerData, targetTeams, cmdDef)
        if not cmdDef.validation then return true end
        for _, rule in ipairs(cmdDef.validation) do
            if rule == "dev_only" and not Spring.IsCheatingEnabled() then
                Spring.SendMessageToPlayer(playerData.playerID, "You do not have permission to use this command.")
                return false
            elseif rule == "allied_only" then
                for _, teamID in ipairs(targetTeams) do
                    local canTake, reason = Teammates.CanTakeFrom(teamID, playerData.teamID)
                    if not canTake then
                        Spring.SendMessageToPlayer(playerData.playerID, reason)
                        return false
                    end
                end
            elseif rule == "enemy_only" then
                for _, teamID in ipairs(targetTeams) do
                    local canCapture, reason = Teammates.CanCaptureFrom(teamID, playerData.teamID)
                    if not canCapture then
                        Spring.SendMessageToPlayer(playerData.playerID, reason)
                        return false
                    end
                end
            elseif rule == "no_human_players" then
                for _, teamID in ipairs(targetTeams) do
                    local canTake, reason = Teammates.CanTakeFrom(teamID, playerData.teamID)
                    if not canTake and reason:find("human players") then
                        Spring.SendMessageToPlayer(playerData.playerID, "You cannot use this command on teams with active human players.")
                        return false
                    end
                end
            elseif rule == "valid_team" then
                if #targetTeams == 0 then
                    Spring.SendMessageToPlayer(playerData.playerID, "You must specify a valid target team.")
                    return false
                end
            end
        end
        return true
    end

    local function ExecuteTransfers(playerData, targetTeams, cmdDef)
        local total = 0
        for _, teamID in ipairs(targetTeams) do
            if cmdDef.reason == TeamTransfer.REASON.TAKEN then
                total = total + Teammates.TakeFromTeam(playerData, teamID)
            elseif cmdDef.reason == TeamTransfer.REASON.CAPTURED then
                total = total + Teammates.CaptureFromTeam(playerData, teamID)
            elseif cmdDef.reason == TeamTransfer.REASON.GIVEN then
                local selectedUnits = cmdDef.scope == "selected_units" and Spring.GetSelectedUnits() or nil
                total = total + Teammates.GiveToTeam(playerData, teamID, selectedUnits)
            end
        end
        Spring.SendMessageToPlayer(playerData.playerID, cmdDef.prefix .. ": Transferred " .. total .. " units from " .. #targetTeams .. " teams")
        return true
    end

    local function ProcessCommand(msg, playerID, cmdDef)
        local targetParam = string.sub(msg, string.len(cmdDef.prefix) + 1):match("^%s*(%d*)%s*$")
        local playerData = Teammates.GetPlayerData(playerID)
        if not playerData then return false end
        local targetTeams = Teammates.GetTargetTeams(playerData, targetParam, cmdDef.target_selection)
        if not ValidateCommandPermissions(playerData, targetTeams, cmdDef) then return false end
        return ExecuteTransfers(playerData, targetTeams, cmdDef)
    end

    local function HandleEngineTransfer(unitID, fromTeam, toTeam, reason)
        local unitDefID = Spring.GetUnitDefID(unitID)
        if not unitDefID then return false end
        if not TeamTransfer.ValidateTransfer(unitID, unitDefID, fromTeam, toTeam, reason) then return false end
        return Units.ChangeTeamWithReason(unitID, fromTeam, toTeam, reason)
    end

    function gadget:Initialize()
        -- Register built-in validators
        TeamTransfer.RegisterValidator("share_control", function(unitID, unitDefID, oldTeam, newTeam, reason)
            if not TeamTransfer.config.enabled then return true end
            if reason ~= TeamTransfer.REASON.GIVEN then return true end
            if Spring.IsCheatingEnabled() then return true end
            if not TeamTransfer.config.allowUnitSharing then 
                TeamTransfer.AddRefusal(oldTeam, "Unit sharing has been disabled")
                return false 
            end
            if TeamTransfer.config.allowEnemyUnitSharing or Spring.AreTeamsAllied(oldTeam, newTeam) then 
                return true 
            end
            TeamTransfer.AddRefusal(oldTeam, "Cannot give units to enemies")
            return false
        end)
        TeamTransfer.RegisterValidator("no_builders", function(unitID, unitDefID, oldTeam, newTeam, reason)
            if not TeamTransfer.config.allowBuilderSharing and reason == TeamTransfer.REASON.GIVEN then
                local ud = UnitDefs[unitDefID]
                if ud and (ud.isBuilder or ud.isFactory) then 
                    TeamTransfer.AddRefusal(oldTeam, "Sharing builders and factories is disabled")
                    return false 
                end
            end
            return true
        end)

        -- Register domain ownership via SyncedActionFallback
        Registry.RegisterHooks(TeamTransfer.OWNED_HOOKS, {
            NetShareTransfer = HandleEngineTransfer,
            TeamTransfer = HandleEngineTransfer,
            BuilderCapture = HandleEngineTransfer,
            TeamGiveEverything = HandleEngineTransfer,
            TeamGiveEverythingComplete = function(fromTeam, toTeam) return true end,
            NetResourceTransfer = Resources.NetResourceTransfer,
            take = function(msg, playerID) return ProcessCommand(msg, playerID, commands.take) end,
            capture = function(msg, playerID) return ProcessCommand(msg, playerID, commands.capture) end,
            give = function(msg, playerID) return ProcessCommand(msg, playerID, commands.give) end,
            aishare = function(msg, playerID) return ProcessCommand(msg, playerID, commands.aishare) end,
        })

        -- Export global namespace
        GG.TeamTransfer = TeamTransfer
    end

    function gadget:Shutdown()
        Registry.UnregisterHooks(TeamTransfer.OWNED_HOOKS)
        GG.TeamTransfer = nil
    end

    -- Spring gadget interface - still required
    function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, reason)
        TeamTransfer.SetPendingReason(unitID, reason)
        local valid, failedValidator = TeamTransfer.ValidateTransfer(unitID, unitDefID, oldTeam, newTeam, reason)
        if not valid then return false end
        return Units.ChangeTeamWithReason(unitID, oldTeam, newTeam, reason)
    end

    function gadget:AllowResourceTransfer(oldTeam, newTeam, resourceType, amount)
        return Resources.AllowResourceTransfer(oldTeam, newTeam, resourceType, amount)
    end

    function gadget:UnitGiven(unitID, unitDefID, oldTeam, newTeam)
        local reason = TeamTransfer.ConsumePendingReason(unitID)
        TeamTransfer.NotifyUnitGiven(unitID, unitDefID, oldTeam, newTeam, reason)
    end

    function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
        local reason = TeamTransfer.ConsumePendingReason(unitID)
        TeamTransfer.NotifyUnitTaken(unitID, unitDefID, oldTeam, newTeam, reason)
    end

    function gadget:GameFrame()
        TeamTransfer.GC()
    end

else -- UNSYNCED

    local commands = {
        take = { prefix = "take" },
        capture = { prefix = "capture" },
        give = { prefix = "give" },
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