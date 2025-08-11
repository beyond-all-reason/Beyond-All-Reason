local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name = "Team Transfer",
        desc = "Centralized team and resource transfer system with comprehensive reason-based validation.",
        author = "BAR Team",
        date = "2025",
        license = "GPL v2 or later",
        layer = -1001,
        enabled = true
    }
end

if gadgetHandler:IsSyncedCode() then
          -- Load modules in synced context
      local TeamTransfer      = VFS.Include("LuaRules/Gadgets/team_transfer/definitions.lua")
      local Manager           = VFS.Include("LuaRules/Gadgets/team_transfer/manager.lua")
      local Units             = VFS.Include("LuaRules/Gadgets/team_transfer/units.lua")
      local Resources         = VFS.Include("LuaRules/Gadgets/team_transfer/resources.lua")
      local Teammates         = VFS.Include("LuaRules/Gadgets/team_transfer/teammates.lua")
      local GadgetManager     = Spring.Utilities.Include("luarules/modules/gadget_manager.lua")
      
      _G.TeamTransfer = TeamTransfer

    -- Declarative command definitions
    local commands = {
        take = {
            reason = TeamTransfer.REASON.TAKEN,
            prefix = "take",
            scope = "all_team_units",
            validation = { "allied_only", "no_human_players" },
            resources = true,
            target_selection = "auto_idle_teams",
        },
        capture = {
            reason = TeamTransfer.REASON.CAPTURED,
            prefix = "capture",
            scope = "all_team_units",
            validation = { "enemy_only" },
            resources = true,
            target_selection = "specify_team_or_all_enemies",
        },
        give = {
            reason = TeamTransfer.REASON.GIVEN,
            prefix  = "give",
            scope   = "selected_units",
            validation = { "valid_team" },
            target_selection = "specify_team",
        },
        aishare = {
            reason = TeamTransfer.REASON.GIVEN,
            prefix  = "aishare",
            scope   = "all_team_units",
            validation = { "valid_team" },
            target_selection = "specify_team",
        },
    }

    -- Validation helpers
    local function ValidateCommandPermissions(playerData, targetTeams, cmdDef)
        if not cmdDef.validation then return true end
        for _, rule in ipairs(cmdDef.validation) do
            if rule == "dev_only" and not Spring.IsCheatingEnabled() then
                Spring.SendMessageToPlayer(playerData.playerID, "You do not have permission to use this command.")
                return false
            elseif rule == "allied_only" then
                for _, teamID in ipairs(targetTeams) do
                    local ok, reason = Teammates.CanTakeFrom(teamID, playerData.teamID)
                    if not ok then
                        Spring.SendMessageToPlayer(playerData.playerID, reason)
                        return false
                    end
                end
            elseif rule == "enemy_only" then
                for _, teamID in ipairs(targetTeams) do
                    local ok, reason = Teammates.CanCaptureFrom(teamID, playerData.teamID)
                    if not ok then
                        Spring.SendMessageToPlayer(playerData.playerID, reason)
                        return false
                    end
                end
            elseif rule == "no_human_players" then
                for _, teamID in ipairs(targetTeams) do
                    if Teammates.TeamHasActiveHumanPlayers(teamID) then
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
                local selectedUnits = (cmdDef.scope == "selected_units") and Spring.GetSelectedUnits() or nil
                total = total + Teammates.GiveToTeam(playerData, teamID, selectedUnits)
            end
        end
        Spring.SendMessageToPlayer(playerData.playerID, (cmdDef.prefix .. ": Transferred " .. total .. " units from " .. #targetTeams .. " teams"))
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

    local syncedActions = {
        -- Engine fallbacks → route to Lua-owned transfer entrypoints
        NetShareTransfer           = function(unitID, oldTeam, newTeam, reason) return Units.TransferUnit(unitID, newTeam, reason) end,
        TeamTransfer               = function(unitID, oldTeam, newTeam, reason) return Units.TransferUnit(unitID, newTeam, reason) end,
        BuilderCapture             = function(unitID, oldTeam, newTeam, reason) return Units.TransferUnit(unitID, newTeam, reason) end,
        TeamGiveEverything         = function(fromTeam, toTeam) return Teammates.GiveEverythingTo(fromTeam, toTeam) end,
        TeamGiveEverythingComplete = function(fromTeam, toTeam) return true end,
        NetResourceTransfer        = function(fromTeam, toTeam, m, e) return Resources.NetResourceTransfer(fromTeam, toTeam, m, e) end,
        TeamAutoShare              = Teammates.TeamAutoShare,

        -- Chat command handlers (standard msg, playerID signature)
        take                       = function(msg, playerID) return ProcessCommand(msg, playerID, commands.take) end,
        capture                    = function(msg, playerID) return ProcessCommand(msg, playerID, commands.capture) end,
        give                       = function(msg, playerID) return ProcessCommand(msg, playerID, commands.give) end,
        aishare                    = function(msg, playerID) return ProcessCommand(msg, playerID, commands.aishare) end,
    }

    -- Use the gadget manager builder pattern
    function gadget:CreateGadgetManager()
        local builder = GadgetManager.CreateGadget("TeamTransfer")
        
        -- Register all synced actions via the builder
        for actionName, handler in pairs(syncedActions) do
            builder:WithSyncedAction(actionName, handler)
        end
        
        return builder
    end

    function gadget:Shutdown()
        GG.TeamTransfer = nil
        _G.TeamTransfer = nil
    end

    -- INBOUND engine veto: internal wiring only (not public API)
    function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, reason)
        return Manager.ValidateUnitTransfer(unitID, unitDefID, oldTeam, newTeam, reason)
    end

    -- INBOUND engine veto: internal wiring only (not public API)
    function gadget:AllowResourceTransfer(oldTeam, newTeam, resourceType, amount)
        return Manager.ValidateResourceTransfer(oldTeam, newTeam, resourceType, amount)
    end

         -- keep Initialize at bottom for readability
     function gadget:Initialize()
         -- Clean public API: merge definitions + manager
         GG.TeamTransfer = {}
         for k, v in pairs(TeamTransfer) do
             GG.TeamTransfer[k] = v
         end
         for k, v in pairs(Manager) do
             GG.TeamTransfer[k] = v
         end

         -- Register built-in validators
         GG.TeamTransfer.RegisterUnitValidator("TeamTransfer_AllowUnitTransfer", Units.AllowUnitTransfer)
         GG.TeamTransfer.RegisterResourceValidator("TeamTransfer_AllowResourceTransfer", Resources.AllowResourceTransfer)
     end

else -- UNSYNCED
    local commands = {
        take    = { prefix = "take"    },
        capture = { prefix = "capture" },
        give    = { prefix = "give"    },
    }

    function gadget:GotChatMsg(msg, playerID)
        for _, cmdDef in pairs(commands) do
            if string.sub(msg, 1, string.len(cmdDef.prefix)) == cmdDef.prefix then
                local params = string.sub(msg, string.len(cmdDef.prefix) + 1)
                Spring.SendLuaRulesMsg(cmdDef.prefix .. ":" .. (params or ""))
                return true
            end
        end
        return false
    end
end