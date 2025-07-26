function gadget:GetInfo()
	return {
        name = "Give Command",
        desc = "Provides the /give command to spawn units or give resources.",
        author = "GameLobby",
        date = "2024-07-26",
        license = "GNU GPL, v2 or later",
        layer = 1,
        enabled = true,
    }
end

if gadgetHandler:IsSyncedCode() then
    local spGetPlayerInfo = Spring.GetPlayerInfo
    local spGetTeamInfo = Spring.GetTeamInfo
    local spCreateUnit = Spring.CreateUnit
    local spAddTeamResource = Spring.AddTeamResource
    local spSetUnitExperience = Spring.SetUnitExperience
    local spSendMessageToPlayer = Spring.SendMessageToPlayer
    local spSendMessageToTeam = Spring.SendMessageToTeam
    local ud_GetUnitDefID = UnitDefNames.GetUnitDefID

    -- Security and gameplay protection variables
    local givenSomethingAtFrame = -1
    local startPlayers = {}
    
    -- Silent unit gifts (objects that shouldn't spam team messages)
    local isSilentUnitGift = {}
    for udefID, def in ipairs(UnitDefs) do
        if def.modCategories and def.modCategories['object'] or def.customParams and def.customParams.objectify then
            isSilentUnitGift[udefID] = true
        end
    end

    local function checkStartPlayers()
        for _, playerID in ipairs(Spring.GetPlayerList()) do
            local playername, _, spec = Spring.GetPlayerInfo(playerID, false)
            if not spec then
                startPlayers[playername] = true
            end
        end
    end

    function gadget:Initialize()
        checkStartPlayers()
    end

    function gadget:GameStart()
        checkStartPlayers()
    end

    local function GiveCmdFunc(_, args, playerID)
        -- Double spawn prevention
        if givenSomethingAtFrame == Spring.GetGameFrame() then
            return true
        end

        -- Authorization check
        local playername, _, spec = Spring.GetPlayerInfo(playerID, false)
        local authorized = false
        if _G.permissions and _G.permissions.give and _G.permissions.give[playername] then
            authorized = true
            givenSomethingAtFrame = Spring.GetGameFrame()
        end

        if not authorized then
            spSendMessageToPlayer(playerID, "You are not authorized to give units")
            return true
        end

        -- Player status restrictions
        if not spec then
            spSendMessageToPlayer(playerID, "You aren't allowed to give units when playing")
            return true
        end

        if startPlayers[playername] then
            spSendMessageToPlayer(playerID, "You aren't allowed to give units when you have been a player")
            return true
        end

        local target, amount, teamID_str, xp_str = args:match("^(%S+)%s*(%d*)%s*(%d*)%s*(%d*)$")

        if not target then
            spSendMessageToPlayer(playerID, "Usage: /give <unitdef|metal|energy> [amount] [team] [experience]")
            return true
        end

        local amount_num = (amount and amount ~= "") and tonumber(amount) or 1
        local _, _, _, pTeamID = spGetPlayerInfo(playerID)
        local teamID = (teamID_str and teamID_str ~= "") and tonumber(teamID_str) or pTeamID
        local xp = (xp_str and xp_str ~= "") and tonumber(xp_str) or nil

        if not spGetTeamInfo(teamID) then
            spSendMessageToPlayer(playerID, "Invalid team ID: " .. teamID)
            return true
        end

        if (target == "metal" or target == "energy") then
            spAddTeamResource(teamID, target, amount_num)
            spSendMessageToTeam(teamID, "You have been given: " .. amount_num .. " " .. target)
            spSendMessageToPlayer(playerID, ("Gave %d %s to team %d"):format(amount_num, target, teamID))
            return true
        end

        local unitDefID = ud_GetUnitDefID(target)
        if not unitDefID then
            spSendMessageToPlayer(playerID, "Unknown unitdef: " .. target)
            return true
        end

        local x, _, z = spGetPlayerInfo(playerID, "mousepos")
        if not x then
             _, x, _, z = spGetTeamInfo(teamID, "startpos")
        end

        local successfullyCreated = 0
        for i = 1, amount_num do
            local px = x + (math.random() * 100) - 50
            local pz = z + (math.random() * 100) - 50
            local py = Spring.GetGroundHeight(px, pz)
            local unitID = spCreateUnit(unitDefID, px, py, pz, 0, teamID)
            if unitID then
                successfullyCreated = successfullyCreated + 1
                if xp then
                    spSetUnitExperience(unitID, xp)
                end
            end
        end

        if successfullyCreated > 0 then
            -- Silent unit gift check
            if isSilentUnitGift[unitDefID] == nil then
                spSendMessageToTeam(teamID, "You have been given: " .. successfullyCreated .. " " .. target)
            end
            spSendMessageToPlayer(playerID, ("Spawned %d of %s for team %d"):format(successfullyCreated, target, teamID))
        end

        return true
    end

    function gadget:Initialize()
        gadgetHandler:AddChatAction('give', GiveCmdFunc, "Spawns units or gives resources: /give <unitdef|metal|energy> [amount] [team] [xp]")
    end

    function gadget:Shutdown()
        gadgetHandler:RemoveChatAction('give')
    end

else   -- UNSYNCED
    local myPlayerID = Spring.GetMyPlayerID()
    local myPlayerName = Spring.GetPlayerInfo(myPlayerID, false)
    local authorized = SYNCED.permissions and SYNCED.permissions.give and SYNCED.permissions.give[myPlayerName]

    local function RequestGive(cmd, line, words, playerID)
        if authorized and playerID == myPlayerID then
            local mx, my = Spring.GetMouseState()
            local targettype, pos = Spring.TraceScreenRay(mx, my)
            if targettype == 'unit' then
                pos = {Spring.GetUnitPosition(pos)}
            elseif targettype == 'feature' then
                pos = {Spring.GetFeaturePosition(pos)}
            end
            
            if type(pos) == 'table' and pos[1] and pos[3] and pos[1] > 0 and pos[3] > 0 and words[1] and words[2] and words[3] then
                Spring.SendLuaRulesMsg("$g$:" .. words[1] .. ":" .. words[2] .. ":" .. words[3] .. ":" .. pos[1] .. ":" .. pos[3] .. (words[4] and ":" .. words[4] or ""))
            else
                Spring.SendMessageToPlayer(playerID, "Failed to give, check syntax or cursor position")
            end
        end
    end

    function gadget:Initialize()
        gadgetHandler:AddChatAction('give', RequestGive)
    end

    function gadget:Shutdown()
        gadgetHandler:RemoveChatAction('give')
    end
end