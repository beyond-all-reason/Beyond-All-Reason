function gadget:GetInfo()
    return {
        name = "Take Manager",
        desc = "Handles players AFK and drops",
        author = "BD",
        date = "2012",
        license = "WTFPL",
        layer = 1,
        enabled = true
    }
end

local maxIdleTreshold = 60 --in seconds
local maxPing = 30 -- in seconds
local finishedResumingPing = 2 --in seconds
local maxInitialQueueSlack = 120 -- in seconds
local takeCommand = "take2"
local minTimeToTake = 10 -- in seconds
local checkQueueTime = 25 -- in seconds 
--in chose ingame startpostype, players must place beforehand, so take an action, grace period can be shorter
minTimeToTake = Spring.GetModOptions().startpostype == 2 and 1 or minTimeToTake

local AFKMessage = 'idleplayers '
local AFKMessageSize = #AFKMessage
if ( not gadgetHandler:IsSyncedCode()) then
-- UNSYNCED code

    local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds
    local SendLuaRulesMsg = Spring.SendLuaRulesMsg
    local GetMouseState = Spring.GetMouseState
    local GetGameSeconds =     Spring.GetGameSeconds

    local min = math.min
    local max = math.max

    local nameEnclosingPatterns = {{""," added point"},{"<","> "},{"> <","> "},{"[","] "}}
    local myPlayerName = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
    local lastActionTime = 0
    local timer = 0
    local updateTimer = 0
    local gameStartTime = 0
    local isIdle = true
    local updateRefreshTime = 1 --in seconds
    local initialQueueTime

    local mx,my = GetMouseState()
    local validation = SYNCED.validationIdle

    function gadget:Initialize()
        gadgetHandler:AddSyncAction("onGameStart", onGameStart)
        gadgetHandler:AddChatAction("initialQueueTime",onInitialQueueTime)
    end

    function gadget:Shutdown()
        gadgetHandler:RemoveChatAction('initialQueueTime')
        gadgetHandler:RemoveSyncAction("onGameStart")
    end

    function onInitialQueueTime(_,_,words)
        initialQueueTime = tonumber(words[1])
        if initialQueueTime then
            initialQueueTime = min(initialQueueTime,maxInitialQueueSlack)
        end
        return true
    end

    function onGameStart()
        if initialQueueTime then
            NotIdle()
            -- allow the user to slack while initial queue is unrolling
            lastActionTime = timer + initialQueueTime
        end
        gameStartTime = timer
    end

    function WentIdle()
        if not isIdle then
            SendLuaRulesMsg(validation..AFKMessage.. "1")
            isIdle = true
        end
    end

    function NotIdle()
        lastActionTime = max(timer,lastActionTime)
        if isIdle then
            SendLuaRulesMsg(validation..AFKMessage.. "0")
            isIdle = false
        end
    end

    function gadget:Update()
        local dt = GetLastUpdateSeconds()
        timer = timer+dt
        updateTimer = updateTimer + dt
        if updateTimer < updateRefreshTime then
            return
        end
        updateTimer = 0
        
        -- 
        if checkQueueTime and GetGameSeconds() > checkQueueTime then
            local playerID = Spring.GetMyPlayerID()
            local teamID = Spring.GetMyTeamID()
            local myUnits = Spring.GetTeamUnits(teamID)
            local queueTime = 0
            for _,unitID in pairs(myUnits) do
                local unitDefID = Spring.GetUnitDefID(unitID)
                local thisQueueTime = 0
                if UnitDefs[unitDefID].isBuilder then 
                    local buildSpeed = UnitDefs[unitDefID].buildSpeed
                    local buildQueue = Spring.GetRealBuildQueue(unitID) 
                    if buildQueue then
                        for uDID,_ in pairs(buildQueue) do
                            thisQueueTime = thisQueueTime + UnitDefs[uDID].buildTime / buildSpeed
                        end
                    end
                end
                queueTime = max(queueTime, thisQueueTime)
            end
            lastActionTime = min(max(lastActionTime, timer+queueTime),gameStartTime+maxInitialQueueSlack) --treat this queue as though is was an initial queue
            checkQueueTime = nil 
        end
        
        -- ugly code to check if the mouse moved since the call-in doesn't work
        local x,y = GetMouseState()
        if mx ~= x or my ~= y then
            NotIdle()
        end
        my = y
        mx = x

        if timer-lastActionTime > maxIdleTreshold then
            WentIdle()
        end
    end

    -- MouseMove isn't called either??!
    function gadget:MouseMove()
        NotIdle()
    end

    function gadget:MousePress()
        NotIdle()
    end

    function gadget:MouseWheel()
        NotIdle()
    end

    function gadget:KeyPress()
        NotIdle()
    end

    -- extract a player name from a text message
    function getPlayerName(playerMessage)
        local pos
        local retVal = ""
        for index,pattern in pairs(nameEnclosingPatterns) do
            local prefix = pattern[1]
            local suffix = pattern[2]
            local prefixstart,prefixend
            local suffixstart,suffixend
            if prefix ~= "" then
                prefixstart,prefixend = playerMessage:find(prefix,1,true)
            end
            prefixend = (prefixend or 0 ) + 1
            if suffix ~= "" then
                suffixstart,suffixend = playerMessage:find(suffix,prefixend,true)
            end
            if suffixstart then
                suffixstart = suffixstart - 1
                return playerMessage:sub(prefixend,suffixstart)
            end
        end
        return ""
    end

    --this callin has never been implemented!
    --[[
    function gadget:AddConsoleLine(line)
        if line:len() == 0 then
            return
        end
        if getPlayerName(line) == myPlayerName then
            NotIdle()
        end
    end
    ]]--

else

-- SYNCED code
    local playerInfoTable = {}
    local currentGameFrame = 0

    local TransferUnit = Spring.TransferUnit
    local GetPlayerList = Spring.GetPlayerList
    local ShareTeamResource = Spring.ShareTeamResource
    local GetTeamResources = Spring.GetTeamResources
    local GetPlayerInfo = Spring.GetPlayerInfo
    local GetTeamList = Spring.GetTeamList
    local GetTeamLuaAI = Spring.GetTeamLuaAI
    local GetAIInfo = Spring.GetAIInfo
    local SetTeamRulesParam = Spring.SetTeamRulesParam
    local GetTeamRulesParam = Spring.GetTeamRulesParam
    local GetTeamUnits = Spring.GetTeamUnits
    local SetTeamShareLevel = Spring.SetTeamShareLevel
    local GetTeamInfo = Spring.GetTeamInfo
    local GetTeamList = Spring.GetTeamList
    local SendMessageToPlayer = Spring.SendMessageToPlayer
    local SendMessageToAllyTeam = Spring.SendMessageToAllyTeam
    local Echo = Spring.Echo
    local IsCheatingEnabled = Spring.IsCheatingEnabled

    local resourceList = {"metal","energy"}
    local gaiaTeamID = Spring.GetGaiaTeamID()
    local gameSpeed = Game.gameSpeed

    local min = math.min
    local max = math.max

    local charset = {}  do -- [0-9a-zA-Z]
        for c = 48, 57  do table.insert(charset, string.char(c)) end
        for c = 65, 90  do table.insert(charset, string.char(c)) end
        for c = 97, 122 do table.insert(charset, string.char(c)) end
    end
    local function randomString(length)
        if not length or length <= 0 then return '' end
        --math.randomseed(os.clock()^5)
        return randomString(length - 1) .. charset[math.random(1, #charset)]
    end

    local validation = randomString(2)
    _G.validationIdle = validation

    local function CheckPlayerState(playerID)
        local newval = playerInfoTable[playerID]
        if not newval then
            return false
        end
        local ok = true
        ok = ok and newval.connected
        ok = ok and newval.player
        ok = ok and newval.pingOK
        ok = ok and newval.present
        return ok
    end

    local function UpdatePlayerInfos()
        local TeamToRemainingPlayers = {}
        local aiOwners = {}
        for _,teamID in ipairs(GetTeamList()) do --initialize team count
            local _, _, _, isAI = GetTeamInfo(teamID)
            if isAI then
                --store who hosts that engine ai, team will be controlled if player is present
                local aiHost = select(3,GetAIInfo(teamID))
                local hostedAis = aiOwners[aiHost] or {}
                hostedAis[#hostedAis+1] = teamID
                aiOwners[aiHost] = hostedAis
            end
            --is luaai or is gaia
            if GetTeamLuaAI(teamID) ~= "" or teamID == gaiaTeamID then
                --luaai and gaia are always controlled
                TeamToRemainingPlayers[teamID] = 1
            else
                TeamToRemainingPlayers[teamID] = 0
            end
        end
        for _,playerID in ipairs(GetPlayerList()) do -- update player infos
            local name,active,spectator,teamID,allyTeamID,ping = GetPlayerInfo(playerID)
            local playerInfoTableEntry = playerInfoTable[playerID] or {}
            playerInfoTableEntry.connected = active
            playerInfoTableEntry.player = not spectator
            local pingTreshold = maxPing
            local oldPingOk = playerInfoTableEntry.pingOK
            if oldPingOk == false then
                pingTreshold = finishedResumingPing --use smaller threshold to determine finished resuming
            end
            playerInfoTableEntry.pingOK = ping < pingTreshold
            if not spectator then
                if oldPingOk and not playerInfoTableEntry.pingOK then
                    Echo("Player " .. name .. " is lagging behind")
                elseif oldPingOk == false and playerInfoTableEntry.pingOK and playerInfoTableEntry.connected then
                    Echo("Player " .. name .. " has finished resuming")
                end
            end
            if playerInfoTableEntry.present == nil then
                playerInfoTableEntry.present = false -- initialize to afk
            end
            playerInfoTable[playerID] = playerInfoTableEntry

            --mark hosted ais as controlled
            local hostedAis = aiOwners[playerID]
            if hostedAis then
                --a player only needs to be connected and low enough ping to host an ai
                if playerInfoTableEntry.connected  and playerInfoTableEntry.pingOK then
                    for _,aiTeamID in ipairs(hostedAis) do
                        TeamToRemainingPlayers[aiTeamID] = TeamToRemainingPlayers[aiTeamID] + 1
                    end
                end
            end

            if CheckPlayerState(playerID) then -- bump amount of active players in a team
                TeamToRemainingPlayers[teamID] = TeamToRemainingPlayers[teamID] + 1
            end
        end

        for teamID,teamCount in ipairs(TeamToRemainingPlayers) do
            -- set to a public readable value that there's nobody controlling the team
            SetTeamRulesParam(teamID, "numActivePlayers", teamCount )
        end
    end

    function gadget:Initialize()
          gadgetHandler:AddChatAction(takeCommand, TakeTeam, "Take control of units and resouces from inactive players")
          UpdatePlayerInfos()
    end

    function gadget:Shutdown()
        gadgetHandler:RemoveChatAction(takeCommand)
    end


    function gadget:GameFrame(currentFrame)
        currentGameFrame = currentFrame
        if currentFrame == 10 then
            SendToUnsynced("onGameStart")
        end
        if currentFrame%15 ~= 0 then
            return
        end
        UpdatePlayerInfos()
    end

    function gadget:RecvLuaMsg(msg, playerID)
        if msg:sub(1,2)~=validation and msg:sub(3,AFKMessageSize) ~= AFKMessage then --invalid message
            return
        end
        local afk = tonumber(msg:sub(2+AFKMessageSize+1))
        local playerInfoTableEntry = playerInfoTable[playerID] or {}
        local previousPresent = playerInfoTableEntry.present
        playerInfoTableEntry.present = afk == 0
        playerInfoTable[playerID] = playerInfoTableEntry
        local name,active,spectator,teamID,allyTeamID,ping = GetPlayerInfo(playerID)
        if not spectator and name ~= nil then
            if currentGameFrame > minTimeToTake*gameSpeed then
                if previousPresent and not playerInfoTableEntry.present then
                    SendMessageToAllyTeam(allyTeamID,"Player " .. name .. " went AFK")
                elseif not previousPresent and playerInfoTableEntry.present then
                    SendMessageToAllyTeam(allyTeamID,"Player " .. name .. " came back")
                end
            end
        end
    end

    function gadget:AllowResourceTransfer(fromTeamID, toTeamID, restype, level)
        -- prevent resources to leak to uncontrolled teams
        return GetTeamRulesParam(toTeamID,"numActivePlayers") ~= 0 or IsCheatingEnabled()
    end

    function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
        -- prevent units to be shared to uncontrolled teams
        return capture or GetTeamRulesParam(toTeamID,"numActivePlayers") ~= 0 or IsCheatingEnabled()
    end


    function TakeTeam(cmd, line, words, playerID)
        if not CheckPlayerState(playerID) then
            SendMessageToPlayer(playerID,"Cannot share to afk players")
            return -- exclude taking rights from lagged players, etc
        end
        local targetTeam = tonumber(words[1])
        local _,_,_,takerID,allyTeamID = GetPlayerInfo(playerID)
        local teamList = GetTeamList(allyTeamID)
        if targetTeam then
            local _,_,_,_,_,targetAllyTeamID = GetTeamInfo(targetTeam)
            if targetAllyTeamID ~= allyTeamID then
                --don't let enemies take
                SendMessageToPlayer(playerID,"Cannot take enemy players")
                return
            end
            teamList = {targetTeam}
        end
        local numToTake = 0
        for _,teamID in ipairs(teamList) do
            if GetTeamRulesParam(teamID,"numActivePlayers") == 0 then
                numToTake = numToTake + 1
                -- transfer all units
                for _,unitID in ipairs(GetTeamUnits(teamID)) do
                    TransferUnit(unitID,takerID)
                end
                --send all resources en-block to the taker
                for _,resourceName in ipairs(resourceList) do
                    local shareAmount = GetTeamResources( teamID, resourceName)
                    local current,storage,_,_,_,shareSlider = GetTeamResources(takerID,resourceName)
                    shareAmount = min(shareAmount,shareSlider*storage-current)
                    ShareTeamResource( teamID, takerID, resourceName, shareAmount )
                end
            end
        end
        if numToTake == 0 then
            SendMessageToPlayer(playerID,"Nothing to take")
        end
    end
end
