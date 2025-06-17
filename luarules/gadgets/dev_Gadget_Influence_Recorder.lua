local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Snapshot Recorder",
		desc = "Gathers and stores units info during game for replay and stats widget",
		author = "Mr_Chinny",
		date = "May 2025",
		license = "GNU GPL, v2 or later",
		layer = -99999,
		enabled = true,
	}
end

--todo
--check transfer units / capture working as it should.
--add transport logic for moving static.
--add antispam unit logic when mobile units > 1000? done
--add allowing list at end game. -> done
--interesting deaths? -> no, can be done in widget.
--remove all hardcoded units if possible. -> done
-- I think I can use .techlevel (which seems only exists for non T1 units as far as I can see) AND .speed>0) for the first list, but don't see anything convenient for the second list (maybe sightdistance ==1, mine ==true)
-- improve names eg masterNewUnitListMobile -> masterNewMobileUnitList.

if gadgetHandler:IsSyncedCode() then
    return
else
------------------------unsynced------------------------

    local masterNewUnitListStatic = {}      --All units made within last replay frame that have movement of 0.                  [udid,teamID,posX,posZ,]
    local masterNewUnitListMobile = {}      --All units made within last replay frame that have movement.                       [udid,teamID,posX,posZ,]
    local masterDeadUnitListAll = {}        --All units that died/removed within last replay Frame                              [udid,teamID]
    local masterExistingUnitListMobile = {} --Mobile living units that moved within last replay Frame (inc new mobile units)    [posX,poxZ]
    local masterTransferedUnitListAll = {}  --All living units that changed teamID (inc capture), within last frame.            [original teamID, New TeamID]
    local mobileTrackingList = {}           --Tracking all mobile, living units positions for internal gadget use.              [posX,poxZ]
    local mobileTrackingCount = 0           --Tracking all mobile, living units positions for internal gadget use.              [posX,poxZ]
    local teamAllyTeamIDCache = {}          --Cache of teamID/allyTeamIDS
    local replayFrame = 1                   --Saved frame number for replay (not game frame). default 300 gameframes. start at 1 for ipairs.
    local gaiaTeamId        = Spring.GetGaiaTeamID()
    local gaiaAllyTeamID    = select(6, Spring.GetTeamInfo(gaiaTeamId, false))
    local frameLengthModifierThreshold = 100--once this number of frames is reached, the time between frames can be increased so as to limit total stored frames.
    local gameEnded = false
    ---Configurables
    local replayFrameLength = 300           --length in frames. 300 = 10 seconds. xxx This will need to be dynamic - EG 10 seconds at start, 20 seconds once 200 frames, 30 seconds once 250 frames etc
    
    ---Excludable units---
    -- local excludeUnits = { --Units to ignore completly,currently. all flying, plus rez bots and walls XXX add legion
    --     [UnitDefNames["cordrag"].id]    = true, ---xxx need a unitdef to autopopulate
    --     [UnitDefNames["armdrag"].id]    = true
    -- }
    local spamDisabled = false
    local debugTable = {}
    local spamUnits = {}
    local excludeUnits  = {}

    for unitDefID, unitDef in pairs(UnitDefs) do
        if unitDef.customParams.fighter then -- air fighters
            excludeUnits[unitDefID] = true
        elseif unitDef.customParams.drone then --air drones
            excludeUnits[unitDefID] = true
        elseif unitDef.customParams.mine then --mines
            excludeUnits[unitDefID] = true
        elseif unitDef.customParams.objectify then --walls
            excludeUnits[unitDefID] = true
        end

        if unitDef.customParams.techlevel == "1" then --tech 1
            if unitDef.speed > 0 then --mobile
                spamUnits[unitDefID] = true
            end
        end     
    end

    
    -- local spamUnits = { --Units that are T1 spam, late game can set to be ignored to save on performance. xxx need a unitdef to autopopulate
    --     [UnitDefNames["armflea"].id]    =true,
    --     [UnitDefNames["armpw"].id]      =true,
    --     [UnitDefNames["corak"].id]      =true,
    --     [UnitDefNames["armfav"].id]     =true,
    --     [UnitDefNames["corfav"].id]     =true
    -- }

    

    ---------------------------------------
    local function PrimeNextReplayFrame()
        masterNewUnitListMobile[replayFrame] = {}
        masterNewUnitListStatic[replayFrame] = {}
        masterDeadUnitListAll[replayFrame] = {}
        masterExistingUnitListMobile[replayFrame] = {}
        masterTransferedUnitListAll[replayFrame] = {}
    end

    local function CacheTeams()
        for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
            for _, teamID in ipairs(Spring.GetTeamList(allyTeamID)) do
                teamAllyTeamIDCache[teamID] = allyTeamID
            end
        end
    end

    local function CheckForSkippables(allyTeamID, udID, checkSpam)
        local skippable = false
        if allyTeamID == nil then
            skippable = true
            Spring.Echo("Error 001; no AllyTeamID", udID,allyTeamID) --xxx remove 
        elseif allyTeamID == gaiaAllyTeamID then --gaia
            skippable = true
        elseif excludeUnits[udID] then --excluded
            skippable = true
        elseif spamDisabled and checkSpam then --ignore spam units when enabled.
                if spamUnits[udID] then
                    skippable = true
                end
        end 
        return skippable
    end

    local function UpdateNewMobileUnitListPosition() --call in just before changing to next replay frame
        for unitID,_ in pairs(masterNewUnitListMobile[replayFrame]) do
            if spamDisabled then
                if spamUnits[unitDefID] then --ignore spam units when option applied
                    break
                end
            end
            local posX,_,posZ = Spring.GetUnitPosition(unitID)
            if posX then --if unit died within the last replayframe this will be nil, so don't need to add
                masterNewUnitListMobile[replayFrame][unitID][3] = posX
                masterNewUnitListMobile[replayFrame][unitID][4] = posZ
                masterExistingUnitListMobile[replayFrame][unitID] = {posX, posZ}
                mobileTrackingList[unitID] = {posX, posZ}
                mobileTrackingCount = mobileTrackingCount + 1
            end
        end
    end

    local function UpdateExistingMobileUnitLists() --call in just before changing to next replay frame. checks all living mobile units, adds to masterlist only if moved. xxx should I ceiling this?
        local posX,_,posZ
        for unitID, posData in pairs(mobileTrackingList) do
            posX,_,posZ = Spring.GetUnitPosition(unitID)
            if posX ~= posData[1] or posZ ~= posData[2] then
                if not posX then--edge case when update() occurs on same gameframe that a unit dies 
                else 
                    masterExistingUnitListMobile[replayFrame][unitID] = {posX, posZ} --only added if unit has moved.
                    mobileTrackingList[unitID] = {posX, posZ}
                end
            end
        end
    end

    local function MakeListsAvalibleToWidgets()
        if Script.LuaUI("Influence") then
            Script.LuaUI.Influence(masterNewUnitListStatic,masterNewUnitListMobile,masterDeadUnitListAll,masterExistingUnitListMobile,masterTransferedUnitListAll)
        end
    end

    function gadget:UnitFinished(unitID, unitDefID, teamID)
        if not CheckForSkippables(teamAllyTeamIDCache[teamID],unitDefID, false) then
            local unitDef = UnitDefs[unitDefID]
            if unitDef.speed >0 then
                masterNewUnitListMobile[replayFrame][unitID] = {unitDefID, teamID,"X","Z"} --xxx can update to nils. note the unit position at time of creation may not match when the replay frame is recorded, so I must go through this list and update positions.
                -- if not spamDisabled then
                --     mobileTrackingList[unitID] = {"X","Z"}
                --     mobileTrackingCount = mobileTrackingCount + 1
                -- else
                --     if not spamUnits[unitDefID] then
                --         mobileTrackingList[unitID] = {"X","Z"}
                --         mobileTrackingCount = mobileTrackingCount + 1
                --     end
                -- end
            else
                local posX,_,posZ = Spring.GetUnitPosition(unitID)
                masterNewUnitListStatic[replayFrame][unitID] = {unitDefID, teamID,posX,posZ}
            end
        end
    end

    function gadget:UnitDestroyed (unitID, unitDefID, teamID, attUnitID, attUnitDefID, attTeamID)
        if not CheckForSkippables(teamAllyTeamIDCache[teamID],unitDefID, false) then
            masterDeadUnitListAll[replayFrame][unitID] = {unitDefID, teamID, attUnitDefID, attTeamID} --xxx this will add spam units to the dead list even if antispam enabled
            if mobileTrackingList[unitID] then
                mobileTrackingList[unitID] = nil
                mobileTrackingCount = mobileTrackingCount - 1
            end
        end
    end

    function gadget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID) --xxx what about incomplete units?
        if not CheckForSkippables(teamAllyTeamIDCache[oldTeamID],unitDefID, true) then
            if select(5,Spring.GetUnitHealth(unitID)) == 1 then
                masterTransferedUnitListAll[replayFrame][unitID] = {oldTeamID,newTeamID}
            end
        end
    end
    
    local function gbug() --xxx remove, just for debugging
        Spring.Echo("Gadget Bug Excluded:")
        for i, _ in pairs(excludeUnits) do
            Spring.Echo(UnitDefs[i].translatedHumanName, UnitDefs[i].name)
        end
        Spring.Echo("Gadget Bug spamUnits:")
        for i, _ in pairs(spamUnits) do
            Spring.Echo(UnitDefs[i].translatedHumanName, UnitDefs[i].name)
        end
        Spring.Echo("Gadget Bug true checker:", Script.LuaUI("Influence"),not gameEnded)
        Spring.Echo("debugTable",debugTable)
    end

    function gadget:Initialize()
        gadgetHandler:AddChatAction('bug', gbug)
        gadgetHandler:AddChatAction('allow', MakeListsAvalibleToWidgets)
        CacheTeams()
        PrimeNextReplayFrame()
    end

    

    function gadget:GameFrame(gf)
        if gf % replayFrameLength == 0 then --record every 10 seconds
            if Script.LuaUI("Influence") and not gameEnded then --record only if companion widget is running loaded
                UpdateExistingMobileUnitLists()
                UpdateNewMobileUnitListPosition()
                debugTable[replayFrame] = gf
                replayFrame = replayFrame + 1
                PrimeNextReplayFrame()
                Spring.Echo("mobileTrackingCount = ", gf ,replayFrame, mobileTrackingCount)
                if mobileTrackingCount > 1000 then --ignore T1 spam if tracking too many mobile units, reenable if lower threshhold is met
                    spamDisabled = true
                elseif mobileTrackingCount < 500 then
                    spamDisabled = false
                end
                if replayFrame % frameLengthModifierThreshold == 0 then --every [120] frames we will double the interval that a snapshot is taken, and half the next interval this is run. This will make stop the replay list getting too large in v long games.
                    replayFrameLength = replayFrameLength * 2
                    frameLengthModifierThreshold = math.max(frameLengthModifierThreshold / 2,15)
                    Spring.Echo("frameLengthModifierThreshold = ",replayFrame, frameLengthModifierThreshold)
                end
            end
        end
    end

    function gadget:GameOver()
        Spring.Echo("Game Ended IR") --xxx remove
        Spring.Echo(debugTable) --xxx remove
        MakeListsAvalibleToWidgets()
        gameEnded = true
    end

end
