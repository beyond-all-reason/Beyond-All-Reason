local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Snapshot Recorder",
		desc = "Gathers and stores units info positions during game for replay and stats widget",
		author = "Mr_Chinny",
		date = "June 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--stores all units made or destroyed within the last [10] seconds of game. Stores updated positions of the mobile units. Lists made avalible to widgets on game end.
--gadget designed to minimise performance cost.

--todo
--need for storing the game frame when a unit is created to allow cool build order tracking?
--check transfer units / capture working as it should
--add transport logic for moving static. Need to ensure widget tracks/works if a unit dies/changes hands etc while in the air.


if gadgetHandler:IsSyncedCode() then
    return
end

------------------------unsynced------------------------
local newStaticUnitList = {}            --Static Units made within last replay frame (that have movement of 0).             [udid,teamID,posX,posZ,]
local newMobileUnitList = {}            --Mobile units made within last replay frame (that have movement >0).               [udid,teamID,posX,posZ,]
local destroyedUnitList = {}            --All units that died/removed within last replay Frame                              [udid,teamID]
local movedMobileUnitList = {}          --Mobile living units that moved within last replay Frame (inc new mobile units)    [posX,poxZ]
local transferedUnitList = {}           --All living units that changed teamID (inc capture), within last frame.            [original teamID, New TeamID]
local transportedStaticUnitList = {}    --All static units that are loaded (true) or unloaded (false) into a transport      [udid,loaded,posX,posZ]

local recorder = true                   --When false whole gadget is defacto off. Only on if companion widget is activated.
local mobileTrackingList = {}           --Tracking all mobile, living units positions for internal gadget use.              [posX,poxZ]
local mobileTrackingCount = 0           --Tracking all mobile, living units positions for internal gadget use.              [posX,poxZ]

local teamIDToAllyTeamIDCache = {}          --Cache of teamID/allyTeamIDS
local gaiaTeamId = Spring.GetGaiaTeamID()
local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamId, false))

local replayFrame = 1                   --Saved frame number for replay. Default 300 gameframes. start at 1 for ipairs.
local frameLengthModifierThreshold = 100--Once this number of frames is reached, the time between frames can be increased so as to limit total stored frames.
local replayFrameLength = 300           --Length in frames. starts at 300 (= 10 seconds). Dynamic length based on length of game
local gameEnded = false
local spamDisabled = 0                  -- 0 -> off, 1 -> new T1 mobile units positions untracked, 2 -> all new units not tracked, 3 -> No units, including existing, are tracked 
local unitLimit = {850,1000,1500,1750}  --unitlimits for trigging which units are included in position update (to avoid chance of lagging).{All units, no new T1, No new units, stop all tracking}

---Excludable units---                    
local spamUnits = {}                    --mobile t1 units. Skips position update on these when there are too many units on map.
local doNotTrackUnits = {}              --fighter planes, drones.
local excludeUnits  = {}                --buildable Units/Things we don't need to track, eg walls, mines.

for unitDefID, unitDef in pairs(UnitDefs) do

    if unitDef.customParams.fighter then
        doNotTrackUnits[unitDefID] = true
    elseif unitDef.customParams.drone then
        doNotTrackUnits[unitDefID] = true
    elseif unitDef.customParams.mine then --mines
        excludeUnits[unitDefID] = true
    elseif unitDef.customParams.objectify then --walls
        excludeUnits[unitDefID] = true
    end

    if unitDef.customParams.techlevel == "1" then --tech 1, string
        if unitDef.speed > 0 then --mobile
            spamUnits[unitDefID] = true
        end
    end 
    
end

---------------------------------------
local function PrimeNextReplayFrame()
    newMobileUnitList[replayFrame] = {}
    newStaticUnitList[replayFrame] = {}
    destroyedUnitList[replayFrame] = {}
    movedMobileUnitList[replayFrame] = {}
    transferedUnitList[replayFrame] = {}
    transportedStaticUnitList[replayFrame] = {}
end

local function CacheTeams()
    for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
        for _, teamID in ipairs(Spring.GetTeamList(allyTeamID)) do
            teamIDToAllyTeamIDCache[teamID] = allyTeamID
        end
    end
end

local function CheckForSkippables(allyTeamID, unitDefID, checkSpam, checkTracking)
    local skippable = false

    if allyTeamID == nil or allyTeamID == gaiaAllyTeamID then
        skippable = true
    elseif excludeUnits[unitDefID] then
        skippable = true
    elseif checkTracking and doNotTrackUnits[unitDefID] then
        skippable = true
    elseif checkSpam and spamDisabled == 1 and spamUnits[unitDefID] then
        skippable = true
    elseif checkSpam and spamDisabled == 2 then
        skippable = true
    end 

    return skippable
end

local function UpdateNewMobileUnitListPosition() --call in just before changing to next replay frame
    for unitID,data in pairs(newMobileUnitList[replayFrame]) do
        local unitDefID = data[1]
        local allyTeamID = teamIDToAllyTeamIDCache[data[2]]
        if CheckForSkippables(allyTeamID, unitDefID, true, true) then
            break
        end

        local posX,_,posZ = Spring.GetUnitPosition(unitID)
        if posX then --if unit died within the last replayframe this will be nil, so don't need to add
            newMobileUnitList[replayFrame][unitID][3] = posX
            newMobileUnitList[replayFrame][unitID][4] = posZ
            movedMobileUnitList[replayFrame][unitID] = {posX, posZ}
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
            if not posX then--edge case when update() occurs on same gameframe that a unit dies.  
            else 
                movedMobileUnitList[replayFrame][unitID] = {posX, posZ} --only added if unit has moved.
                mobileTrackingList[unitID] = {posX, posZ}
            end
        end
    end
end

local function MakeListsAvalibleToWidgets()
    Script.LuaUI.Influence(newStaticUnitList,newMobileUnitList,destroyedUnitList,movedMobileUnitList,transferedUnitList,transportedStaticUnitList)
end

function gadget:UnitFinished(unitID, unitDefID, teamID)
    if recorder and not CheckForSkippables(teamIDToAllyTeamIDCache[teamID],unitDefID, false, false) then
        local unitDef = UnitDefs[unitDefID]
        if unitDef.speed >0 then
            newMobileUnitList[replayFrame][unitID] = {unitDefID, teamID,"X","Z"} --deliberate placeholders, usually overwritten with position at end of replayframe.
        else
            local posX,_,posZ = Spring.GetUnitPosition(unitID)
            newStaticUnitList[replayFrame][unitID] = {unitDefID, teamID,posX,posZ}
        end
    end
end

function gadget:UnitDestroyed (unitID, unitDefID, teamID, attUnitID, attUnitDefID, attTeamID)
    if recorder and not CheckForSkippables(teamIDToAllyTeamIDCache[teamID],unitDefID, false,false) then
        destroyedUnitList[replayFrame][unitID] = {unitDefID, teamID, attUnitDefID, attTeamID}
        if mobileTrackingList[unitID] then
            mobileTrackingList[unitID] = nil
            mobileTrackingCount = mobileTrackingCount - 1
        end
    end
end

function gadget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
    if recorder and not CheckForSkippables(teamIDToAllyTeamIDCache[oldTeamID],unitDefID, true, true) then
        if select(5,Spring.GetUnitHealth(unitID)) == 1 then
            transferedUnitList[replayFrame][unitID] = {oldTeamID,newTeamID}
        end
    end
end

function gadget:UnitLoaded(unitID, unitDefID, teamID, transportId, transportTeam)
    if recorder and not CheckForSkippables(teamIDToAllyTeamIDCache[teamID],unitDefID, false, false) then
        local unitDef = UnitDefs[unitDefID]
        if unitDef.speed > 0 then
        else
            transportedStaticUnitList[replayFrame][unitID] = {unitDefID,true,nil,nil}
        end
    end
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportId, transportTeam)
    if recorder and not CheckForSkippables(teamIDToAllyTeamIDCache[teamID],unitDefID, false, false) then
        local unitDef = UnitDefs[unitDefID]
        if unitDef.speed > 0 then
        else
            local posX,_,posZ = Spring.GetUnitPosition(unitID)
            transportedStaticUnitList[replayFrame][unitID] = {unitDefID,false,posX,posZ}
        end
    end
end

-- local function gbug() --xxx remove, just for debugging
    -- Spring.Echo("Gadget Bug Excluded:")
    -- for i, _ in pairs(excludeUnits) do
    --     Spring.Echo(UnitDefs[i].translatedHumanName, UnitDefs[i].name)
    -- end
    -- Spring.Echo("Gadget Bug spamUnits:")
    -- for i, _ in pairs(spamUnits) do
    --     Spring.Echo(UnitDefs[i].translatedHumanName, UnitDefs[i].name)
    -- end
    -- Spring.Echo("Gadget Bug true checker:", Script.LuaUI("Influence"),not gameEnded)
-- end

function gadget:Initialize()
    -- gadgetHandler:AddChatAction('bug', gbug) --xxx remove, debugging only
    -- gadgetHandler:AddChatAction('allow', MakeListsAvalibleToWidgets) --xxx remove, debugging only
    CacheTeams()
    PrimeNextReplayFrame()
end

function gadget:GameFrame(gf)
    if gf % replayFrameLength == 0 then --record every 10 seconds, dynamic depending on total game length
        if Script.LuaUI("Influence") and not gameEnded then --record only if companion widget is running and loaded
            recorder = true
            if spamDisabled < 3 then
                UpdateExistingMobileUnitLists()
                UpdateNewMobileUnitListPosition()
            end
            replayFrame = replayFrame + 1
            PrimeNextReplayFrame()
            if mobileTrackingCount > unitLimit[4] then -- don't position update on any (existing or new) mobile units
                spamDisabled = 3
            elseif mobileTrackingCount > unitLimit[3] then --don't position update on (new) mobile units
                spamDisabled = 2
            elseif mobileTrackingCount > unitLimit[2] then --dont position update on (new) T1 spam only
                spamDisabled = 1
            elseif mobileTrackingCount < unitLimit[1] then --position update on all mobile units
                spamDisabled = 0
            end
            if replayFrame % frameLengthModifierThreshold == 0 then --every [120] frames we will double the interval that a snapshot is taken, and half the next interval this is run. This will make stop the replay list getting too large in v long games.
                replayFrameLength = replayFrameLength * 2
                frameLengthModifierThreshold = math.max(frameLengthModifierThreshold / 2,15)
            end
        else
            recorder = false
        end
    end
end

function gadget:GameOver()
    gameEnded = true
    MakeListsAvalibleToWidgets()
end
