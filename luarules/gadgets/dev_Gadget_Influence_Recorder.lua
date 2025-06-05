local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Snapshot Recorder",
		desc = "Gathers info on units in game every 5 seconds",
		author = "Mr_Chinny",
		date = "May 2025",
		license = "GNU GPL, v2 or later",
		layer = -99999,
		enabled = true,
	}
end

--todo
--check transfer units / capture working as it should
--add transport logic for moving static
--add antispam unit logic when mobile units > 1000?
--add allowing list at end game
--interesting deaths?
--remove all hardcoded units if possible

if gadgetHandler:IsSyncedCode() then
    return
else
------------------------unsynced------------------------

    local masterNewUnitListStatic = {}      --All units made within last replay frame that have movement of 0.                  [udid,teamID,posX,posY,posZ,]
    local masterNewUnitListMobile = {}      --All units made within last replay frame that have movement.                       [udid,teamID,posX,posY,posZ,]
    local masterDeadUnitListAll = {}        --All units that died/removed within last replay Frame                              [udid,teamID]
    local masterExistingUnitListMobile = {} --Mobile living units that moved within last replay Frame (inc new mobile units)    [posX,posY,poxZ]
    local masterTransferedUnitListAll = {}  --All living units that changed teamID (inc capture), within last frame.            [original teamID, New TeamID]
    local mobileTrackingList = {}           --Tracking all mobile, living units positions for internal gadget use.              [posX,posY,poxZ]
    local teamAllyTeamIDCache = {}          --Cache of teamID/allyTeamIDS
    local replayFrame = 1                   --Saved frame number for replay (not game frame). default 300 gameframes. start at 1 for ipairs.
    local gaiaTeamId        = Spring.GetGaiaTeamID()
    local gaiaAllyTeamID    = select(6, Spring.GetTeamInfo(gaiaTeamId, false))


    ---Configurables
    local replayFrameLength = 150           --length in frames. 300 = 10 seconds. xxx This will need to be dynamic - EG 10 seconds at start, 20 seconds once 200 frames, 30 seconds once 250 frames etc
    
    ---Excludable units---
    local excludeUnits = { --Units to ignore completly,currently. all flying, plus rez bots and walls XXX add legion 
        [UnitDefNames["cordrag"].id]    = true, ---xxx need a unitdef to autopopulate
        [UnitDefNames["armdrag"].id]    = true
    }

    for unitDefID, unitDef in pairs(UnitDefs) do
        if unitDef.canFly then
            excludeUnits[unitDefID] = true
            --XXX need to keep bombers/gunships etc.
        end
    end

    local spamDisabled = 0
    local spamUnits = { --Units that are T1 spam, late game can set to be ignored to save on performance. xxx need a unitdef to autopopulate
        [UnitDefNames["armflea"].id]    =true,
        [UnitDefNames["armpw"].id]      =true,
        [UnitDefNames["corak"].id]      =true,
        [UnitDefNames["armfav"].id]     =true,
        [UnitDefNames["corfav"].id]     =true
    }

    ---------------------------------------
    function PrimeNextReplayFrame()
        masterNewUnitListMobile[replayFrame] = {}
        masterNewUnitListStatic[replayFrame] = {}
        masterDeadUnitListAll[replayFrame] = {}
        masterExistingUnitListMobile[replayFrame] = {}
        masterTransferedUnitListAll[replayFrame] = {}
    end

    function CacheTeams()
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
            Spring.Echo("Error 001; no AllyTeamID", udID,allyTeamID)
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

    function UpdateNewMobileUnitListPosition() --call in just before changing to next replay frame
        for unitID,_ in pairs(masterNewUnitListMobile[replayFrame]) do
            local posX,posY,posZ = Spring.GetUnitPosition(unitID)
            masterNewUnitListMobile[replayFrame][unitID][3] = posX
            masterNewUnitListMobile[replayFrame][unitID][4] = posY
            masterNewUnitListMobile[replayFrame][unitID][5] = posZ
            masterExistingUnitListMobile[replayFrame][unitID] = {posX, posY, posZ} --only added if unit has moved.
            mobileTrackingList[unitID] = {posX, posY, posZ}
        end
    end

    function UpdateExistingMobileUnitLists() --call in just before changing to next replay frame. checks all living mobile units, adds to masterlist only if moved. xxx should I ceiling this?
        local posX,posY,posZ
        for unitID, posData in pairs(mobileTrackingList) do
            if not masterNewUnitListMobile[replayFrame][unitID] then --ignores new mobile units as these are already added in previous function
                posX,posY,posZ = Spring.GetUnitPosition(unitID)
                if posX ~= posData[1] or posZ ~= posData[3] then
                    masterExistingUnitListMobile[replayFrame][unitID] = {posX, posY, posZ} --only added if unit has moved.
                    mobileTrackingList[unitID] = {posX, posY, posZ}
                end
            end
        end
    end

    function MakeListsAvalibleToWidgets()
        if Script.LuaUI("Influence") then
            Script.LuaUI.Influence(masterNewUnitListStatic,masterNewUnitListMobile,masterDeadUnitListAll,masterExistingUnitListMobile,masterTransferedUnitListAll)
        end
    end

    function gadget:UnitFinished(unitID, unitDefID, teamID)
        if not CheckForSkippables(teamAllyTeamIDCache[teamID],unitDefID, true) then
            local unitDef = UnitDefs[unitDefID]
            if unitDef.speed >0 then
                masterNewUnitListMobile[replayFrame][unitID] = {unitDefID, teamID,"X","Y","Z"} --xxx can update to nils. note the unit position at time of creation may not match when the replay frame is recorded, so I must go through this list and update positions.
                mobileTrackingList[unitID] = {"X","Y","Z"}
                --Spring.Echo("log001: new mobile unit", unitID, mobileTrackingList[unitID])
            else
                local posX,posY,posZ = Spring.GetUnitPosition(unitID)
                masterNewUnitListStatic[replayFrame][unitID] = {unitDefID, teamID,posX,posY,posZ}
            end
        end
    end

    function gadget:UnitDestroyed (unitID, unitDefID, teamID, attUnitID, attUnitDefID, attTeamID)
        if not CheckForSkippables(teamAllyTeamIDCache[teamID],unitDefID, false) then
            masterDeadUnitListAll[replayFrame][unitID] = {unitDefID, teamID, attUnitDefID, attTeamID}
            if mobileTrackingList[unitID] then
                mobileTrackingList[unitID] = nil
            end
        end
    end

    function gadget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
        if not CheckForSkippables(teamAllyTeamIDCache[oldTeamID],unitDefID, true) then
            masterTransferedUnitListAll[replayFrame][unitID] = {oldTeamID,newTeamID}
        end
    end
    
    local function gbug()
        Spring.Echo("Gadget Bug:")
    end

    function gadget:Initialize()
        gadgetHandler:AddChatAction('bug', gbug)
        gadgetHandler:AddChatAction('allow', MakeListsAvalibleToWidgets)
        CacheTeams()
        PrimeNextReplayFrame()
        --widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
    end

    function gadget:GameFrame(gf)
        if gf % replayFrameLength == 0 then --record every 10 seconds
            UpdateNewMobileUnitListPosition()
            UpdateExistingMobileUnitLists()
            replayFrame = replayFrame + 1
            PrimeNextReplayFrame()   
        end
    end
end
