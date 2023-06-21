function widget:GetInfo()
    return {
        name = "AdvPlayersList",
        desc = "List of players and spectators",
        author = "Marmoth. (spiced up by Floris)",
        date = "2008",
        version = 39,
        license = "GNU GPL, v2 or later",
        layer = -4,
        enabled = true, --  loaded by default?
    }
end

--[[Changelog
	before v8.0 developed outside of BA by Marmoth
	v9.0  (Bluestone): modifications to deal with twice as many players/specs; specs are rendered in a small font and cpu/ping does not show for them.
	v9.1  ([teh]decay): added notification about shared resources
	v10   (Bluestone): Better use of opengl for a big speed increase & less spaghetti
	v11   (Bluestone): Get take info from cmd_idle_players
	v11.1 (Bluestone): Added TrueSkill column
	v11.2 (Bluestone): Remove lots of hardcoded crap about module names/pictures
	v11.3 (Bluestone): More cleaning up
	v11.4 (Bluestone): Mute people with ctrl+click on their name
	v12   (Floris): Restyled looks + added imageDirectory var + HD-ified rank and some other icons
	v13   (Floris): Added scale buttons. Added grey cpu/ping icons for spectators. Resized elements. Textured bg. Spec label click to unfold/fold. Added guishader. Lockcamera on doubleclick. Ping in ms/sec/min. Shows dot icon in front of tracked player. HD-ified lots of other icons. Speccing/dead player keep their color. Improved e/m share gui responsiveness. + removed the m_spec option
	v14   (Floris): Added country flags + Added camera icons for locked camera + specs show bright when they are broadcasting new lockcamera positions + bugfixed lockcamera for specs. Added small gaps between in tweakui icons. Auto scales with resolution changes.
	v15   (Floris): Integrated LockCamers widget code
	v16	  (Floris): Added chips next to gambling-spectators for betting system
	v17	  (Floris): Added alliances display and button and /cputext option
	v18	  (Floris): Player system shown on tooltip + added FPS counter + replaced allycursor data with activity gadget data (all these features need gadgets too)
	v19   (Floris): added player resource bars
	v20   (Floris): added alwayshidespecs + fixed drawing when playerlist is at the leftside of the screen
	v21   (Floris): toggles LoS and /specfullview when camera tracking a player
	v22   (Floris): added auto collapse function
	v23   (Floris): hiding share buttons when you are alone
	v24   (Floris): cleanup and removed betting system
	v25   (Floris): added enemy collapse function
	v26   (Floris): make use of FlowUI draw functions
	v27   (Watch The Fort): i18n module integration
	v28   (Floris): when singleplayer: hide cpuping info + resources
	v29   (Floris): display resource bonus next to name
	v30   (Floris): display income values
	v31   (Floris): hover effect + click on player switches player pov / camera
	v32   (Floris): hide spectators by default
	v34   (Floris): share sliders use receivers max available free storage amount to prevent oversharing
	v35   (Floris): support anonymous mode: all same color + hide cpuping info
	v36   (Floris): show grey player name for missing + dead players
	v37   (Floris/Borg_King): add support for much larger player/spec counts  64 -> 256
	v38   (Floris): significant performance improvement, + fast updating resources
	v39   (Floris): auto compress when large amount (33+) of players are participating (same is seperately applied for spectator list)
]]
--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local customScale = 1
local pointDuration = 45
local drawAlliesLabel = false
local alwaysHideSpecs = true
local lockcameraHideEnemies = true            -- specfullview
local lockcameraLos = true                    -- togglelos
local minWidth = 190	-- for the sake of giving the addons some room

local hideDeadTeams = true
local absoluteResbarValues = false

local curFrame = Spring.GetGameFrame()

local vsx, vsy = Spring.GetViewGeometry()

local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font, font2

local AdvPlayersListAtlas
--------------------------------------------------------------------------------
-- SPEED UPS
--------------------------------------------------------------------------------

local Spring_GetGameSeconds = Spring.GetGameSeconds
local Spring_GetGameFrame = Spring.GetGameFrame
local Spring_GetAllyTeamList = Spring.GetAllyTeamList
local Spring_GetTeamInfo = Spring.GetTeamInfo
local Spring_GetTeamList = Spring.GetTeamList
local Spring_GetPlayerInfo = Spring.GetPlayerInfo
local Spring_GetPlayerList = Spring.GetPlayerList
local Spring_GetTeamColor = Spring.GetTeamColor
local Spring_GetLocalAllyTeamID = Spring.GetLocalAllyTeamID
local Spring_GetLocalTeamID = Spring.GetLocalTeamID
local Spring_GetLocalPlayerID = Spring.GetLocalPlayerID
local Spring_ShareResources = Spring.ShareResources
local Spring_GetTeamUnitCount = Spring.GetTeamUnitCount
local Spring_GetTeamResources = Spring.GetTeamResources
local Spring_SendCommands = Spring.SendCommands
local Spring_GetMouseState = Spring.GetMouseState
local Spring_GetAIInfo = Spring.GetAIInfo
local Spring_GetTeamRulesParam = Spring.GetTeamRulesParam
local Spring_GetMyTeamID = Spring.GetMyTeamID
local Spring_AreTeamsAllied = Spring.AreTeamsAllied

local GetCameraState = Spring.GetCameraState
local SetCameraState = Spring.SetCameraState

local gl_Texture = gl.Texture
local gl_Color = gl.Color
local gl_CreateList = gl.CreateList
local gl_DeleteList = gl.DeleteList
local gl_CallList = gl.CallList

local math_isInRect = math.isInRect

local RectRound, UiElement, elementCorner, UiSelectHighlight
local bgpadding = 3


local specOffset = 256

--------------------------------------------------------------------------------
-- IMAGES
--------------------------------------------------------------------------------
local imgDir = LUAUI_DIRNAME .. "Images/advplayerslist/"
local imageDirectory = ":lc:" .. imgDir
local flagsExt = '.png'
local flagHeight = 10

local pics = {
    currentPic = imageDirectory .. "indicator.dds",
    unitsPic = imageDirectory .. "units.dds",
    energyPic = imageDirectory .. "energy.dds",
    metalPic = imageDirectory .. "metal.dds",
    notFirstPic = imageDirectory .. "notfirst.dds",
    pingPic = imageDirectory .. "ping.dds",
    cpuPic = imageDirectory .. "cpu.dds",
    barPic = imageDirectory .. "bar.png",
    amountPic = imageDirectory .. "amount.png",
    pointPic = imageDirectory .. "point.dds",
    lowPic = imageDirectory .. "low.dds",
    arrowPic = imageDirectory .. "arrow.dds",
    takePic = imageDirectory .. "take.dds",
    indentPic = imageDirectory .. "indent.png",
    cameraPic = imageDirectory .. "camera.dds",
    countryPic = imageDirectory .. "country.dds",
    readyTexture = imageDirectory .. "indicator.dds",
    allyPic = imageDirectory .. "ally.dds",
    unallyPic = imageDirectory .. "unally.dds",
    resourcesPic = imageDirectory .. "res.png",
    resbarPic = imageDirectory .. "resbar.png",
    resbarBgPic = imageDirectory .. "resbarBg.png",
    incomePic = imageDirectory .. "res.png",
    barGlowCenterPic = imageDirectory .. "barglow-center.png",
    barGlowEdgePic = imageDirectory .. "barglow-edge.png",

    chatPic = imageDirectory .. "chat.dds",
    sidePic = imageDirectory .. "side.dds",
    sharePic = imageDirectory .. "share.dds",
    idPic = imageDirectory .. "id.dds",
    tsPic = imageDirectory .. "ts.dds",

    rank0 = imageDirectory .. "ranks/1.png",
    rank1 = imageDirectory .. "ranks/2.png",
    rank2 = imageDirectory .. "ranks/3.png",
    rank3 = imageDirectory .. "ranks/4.png",
    rank4 = imageDirectory .. "ranks/5.png",
    rank5 = imageDirectory .. "ranks/6.png",
    rank6 = imageDirectory .. "ranks/7.png",
    rank7 = imageDirectory .. "ranks/8.png",
}

local sidePics = {}  -- loaded in SetSidePics function
local originalColourNames = {} -- loaded in SetOriginalColourNames, format is originalColourNames['name'] = colourString

local apiAbsPosition = { 0, 0, 0, 0, 1, 1, false }

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousTeamColor = {Spring.GetConfigInt("anonymousColorR", 255)/255, Spring.GetConfigInt("anonymousColorG", 0)/255, Spring.GetConfigInt("anonymousColorB", 0)/255}

--------------------------------------------------------------------------------
-- Colors
--------------------------------------------------------------------------------

local pingLevelData = {
    [1] = { r = 0.25, g = 0.82, b = 0.25, cpuThreshold = 0.15, pingThreshold = 0.15 },
    [2] = { r = 0.45, g = 0.75, b = 0.33, cpuThreshold = 0.3,  pingThreshold = 0.3  },
    [3] = { r = 0.75, g = 0.75, b = 0.33, cpuThreshold = 0.45, pingThreshold = 0.7  },
    [4] = { r = 0.85, g = 0.33, b = 0.33, cpuThreshold = 0.65, pingThreshold = 1.5  },
    [5] = { r = 1,    g = 0.2,  b = 0.35, cpuThreshold = math.huge, pingThreshold = math.huge }
}

--------------------------------------------------------------------------------
-- Time Variables
--------------------------------------------------------------------------------

local blink = true
local lastTime = 0
local now = 0

local timeCounter = 9
local timeFastCounter = 9
local updateRate = 0.75
local updateFastRate = 0.09 -- only updates resources
local lastTakeMsg = -120
local hoverPlayerlist = false

--------------------------------------------------------------------------------
-- LockCamera variables
--------------------------------------------------------------------------------

local transitionTime = 1.3 -- how long it takes the camera to move when tracking a player
local listTime = 14 -- how long back to look for recent broadcasters

local totalTime = 0
local lastBroadcasts = {}
local recentBroadcasters = {}
local newBroadcaster = false
local aliveAllyTeams = {}
local allyTeamMaxStorage = {}

local tipTextTime = 0
local Background, ShareSlider, BackgroundGuishader, tipText, drawTipText, tipY, myLastCameraState
local specJoinedOnce, scheduledSpecFullView
local prevClickedPlayer
local lockPlayerID, leftPosX, lastSliderSound, release
local curFrame, PrevGameFrame, MainList, MainList2, MainList3, desiredLosmode, drawListOffset

local deadPlayerHeightReduction = 8

local reportTake = false
local tookTeamID
local tookTeamName
local tookFrame = -120

local playSounds = true
local sliderdrag = LUAUI_DIRNAME .. 'Sounds/buildbar_rem.wav'

local lastActivity = {}
local lastFpsData = {}
local lastSystemData = {}
local lastGpuMemData = {}

--------------------------------------------------------------------------------
-- Players counts and info
--------------------------------------------------------------------------------

-- local player info
local myPlayerID = Spring.GetMyPlayerID()
local myAllyTeamID = Spring.GetLocalAllyTeamID()
local myTeamID = Spring.GetLocalTeamID()
local myTeamPlayerID = select(2, Spring.GetTeamInfo(myTeamID))
local mySpecStatus, fullView, _ = Spring.GetSpectatingState()
local gaiaTeamID = Spring.GetGaiaTeamID()

--General players/spectator count and tables
local player = {}
local playerReadyState = {}
local numberOfSpecs = 0
local numberOfEnemies = 0

--To determine faction at start
local sideOneDefID = UnitDefNames.armcom.id
local sideTwoDefID = UnitDefNames.corcom.id
local sideThreeDefID = UnitDefNames.legcom.id

local teamSideOne = "armada"
local teamSideTwo = "cortex"
local teamSideThree = "legion"

--Name for absent/resigned players
local absentName = " --- "

local gameStarted = false
local gameStartRefreshed = Spring.GetGameFrame() > 30

local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()

local isSingle = false
if not mySpecStatus then
	local teamList = Spring.GetTeamList(myAllyTeamID) or {}
	isSingle = #teamList == 1
end
--------------------------------------------------------------------------------
-- Button check variable
--------------------------------------------------------------------------------

local energyPlayer    -- player to share energy with (nil when no energy sharing)
local metalPlayer    -- player to share metal with(nil when no metal sharing)
local shareAmount = 0      -- amount of metal/energy to share/ask
local maxShareAmount    -- max amount of metal/energy to share/ask
local sliderPosition = 0      -- slider position in metal and energy sharing
local shareSliderHeight = 80
local sliderOrigin   -- position of the cursor before dragging the widget

local firstclick = 0
local dblclickPeriod = 0.4
local backgroundMargin = 8
local widgetRelRight = 0

local desiredLosmodeChanged = 0

--------------------------------------------------------------------------------
-- GEOMETRY VARIABLES
--------------------------------------------------------------------------------

local widgetTop = 0
local widgetRight = 1
local widgetHeight = 0
local prevWidgetHeight = 0
local widgetWidth = 0
local prevWidgetWidth = 0
local widgetPosX = vsx - 200
local widgetPosY = 0
local widgetScale = 0

local expandDown = false
local expandLeft = true
local right = true

local labelOffset = 18
local separatorOffset = 4
local playerOffset = 17
local playerScale = 1
local specScale = 1
local specVertOffset = 12
local drawList = {}
local teamN
local prevClickTime = os.clock()
local specListShow = true
local enemyListShow = true
local forceMainListRefresh = true

--------------------------------------------------
-- Modules
--------------------------------------------------

local modules = {}
local m_indent, m_rank, m_side, m_ID, m_name, m_share, m_chat, m_cpuping, m_country, m_alliance, m_skill, m_resources, m_income

-- these are not considered as normal module since they dont take any place and wont affect other's position
-- (they have no module.width and are not part of modules)
local m_point, m_take

local position = 1
m_indent = {
    name = "indent",
    spec = true, --display for specs?
    play = true, --display for players?
    active = true, --display? (overrides above)
    default = true, --display by default?
    width = 9,
    position = position,
    posX = 0,
    pic = pics["indentPic"],
    noPic = true,
}
position = position + 1

m_ID = {
    name = "id",
    spec = true,
    play = true,
    active = false,
    width = 17,
    position = position,
    posX = 0,
    pic = pics["idPic"],
}
position = position + 1

m_rank = {
    name = "rank",
    spec = true, --display for specs?
    play = true, --display for players?
    active = true, --display? (overrides above)
    default = false, --display by default?
    width = 18,
    position = position,
    posX = 0,
    pic = pics["rank6"],
}
position = position + 1

m_country = {
    name = "country",
    spec = true,
    play = true,
    active = true,
    default = true,
    width = 20,
    position = position,
    posX = 0,
    pic = pics["countryPic"],
}
position = position + 1

m_side = {
    name = "side",
    spec = true,
    play = true,
    active = false,
    width = 18,
    position = position,
    posX = 0,
    pic = pics["sidePic"],
}
position = position + 1

m_skill = {
    name = "skill",
    spec = true,
    play = true,
    active = false,
    width = 18,
    position = position,
    posX = 0,
    pic = pics["tsPic"],
}
position = position + 1

m_name = {
    name = "name",
    spec = true,
    play = true,
    active = true,
    alwaysActive = true,
    width = 10,
    position = position,
    posX = 0,
    noPic = true,
    picGap = 7,
}
position = position + 1

m_cpuping = {
    name = "cpuping",
    spec = true,
    play = true,
    active = true,
    width = 24,
    position = position,
    posX = 0,
    pic = pics["cpuPic"],
}
position = position + 1

m_resources = {
    name = "resources",
    spec = true,
    play = true,
    active = true,
    width = 28,
    position = position,
    posX = 0,
    pic = pics["resourcesPic"],
    picGap = 7,
}
position = position + 1

m_income = {
    name = "income",
    spec = true,
    play = true,
    active = false,
    width = 28,
    position = position,
    posX = 0,
    pic = pics["incomePic"],
    picGap = 7,
}
position = position + 1

m_share = {
    name = "share",
    spec = false,
    play = true,
    active = true,
    width = 50,
    position = position,
    posX = 0,
    pic = pics["sharePic"],
}
position = position + 1

m_chat = {
    name = "chat",
    spec = false,
    play = true,
    active = false,
    width = 18,
    position = position,
    posX = 0,
    pic = pics["chatPic"],
}
position = position + 1

local drawAllyButton = not Spring.GetModOptions().fixedallies

m_alliance = {
    name = "ally",
    spec = false,
    play = true,
    active = true,
    width = 16,
    position = position,
    posX = 0,
    pic = pics["allyPic"],
    noPic = false,
}

if not drawAllyButton then
    m_alliance.width = 0
end

position = position + 1

modules = {
    m_indent,
    m_rank,
    m_country,
    m_ID,
    --m_side,
    m_name,
    m_skill,
    m_resources,
    m_income,
    m_cpuping,
    m_alliance,
    m_share,
    m_chat,
}

m_point = {
    active = true,
    defaut = true, -- defaults dont seem to be accesible on widget data load
}

m_take = {
    active = true,
    default = true,
    pic = pics["takePic"],
}

local specsLabelOffset = 0
local enemyLabelOffset = 0

local hideShareIcons = false
local numTeamsInAllyTeam = #Spring.GetTeamList(myAllyTeamID)

if mySpecStatus or numTeamsInAllyTeam <= 1 then
    hideShareIcons = true
end

---------------------------------------------------------------------------------------------------
--  Geometry
---------------------------------------------------------------------------------------------------

function SetModulesPositionX()
    m_name.width = SetMaxPlayerNameWidth()
    table.sort(modules, function(v1, v2)
        return v1.position < v2.position
    end)
    local pos = 1

    local sizeMult = playerScale + ((1-playerScale)*0.25)
    for _, module in ipairs(modules) do
        module.posX = pos
        if module.active and (module.name ~= 'share' or not hideShareIcons) then
			if (module.name == 'cpuping' and isSinglePlayer) or (module.name == 'resources' and isSingle) then

			else
				if mySpecStatus then
					if module.spec then
                        if module.name == 'cpuping' or module.name == 'indent' or module.name == 'rank' or module.name == 'country' or module.name == 'side' or module.name == 'alliance' or module.name == 'id' or module.name == 'name' then
                            pos = pos + (module.width*sizeMult)
                        else
                            pos = pos + module.width
                        end
					end
				else
					if module.play then
                        if module.name == 'cpuping' or module.name == 'indent' or module.name == 'rank' or module.name == 'country' or module.name == 'side' or module.name == 'alliance' or module.name == 'id' or module.name == 'name' then
                            pos = pos + (module.width*sizeMult)
                        else
                            pos = pos + module.width
                        end
					end
				end
			end

            widgetWidth = pos + 1
            if widgetWidth < 20 then
                widgetWidth = 20
            end
            updateWidgetScale()
        end
    end
	if widgetWidth < minWidth then
		widgetWidth = minWidth
	end

    if widgetWidth ~= prevWidgetWidth then
        prevWidgetWidth = widgetWidth
        forceMainListRefresh = true
    end
end

function SetMaxPlayerNameWidth()
    -- determines the maximal player name width (in order to set the width of the widget)
    local t = Spring_GetPlayerList()
    local maxWidth = 14 * (font2 and font2:GetTextWidth(absentName) or 100) + 8 -- 8 is minimal width

    for _, wplayer in ipairs(t) do
        local name, _, spec, teamID = Spring_GetPlayerInfo(wplayer)
        if not select(4, Spring_GetTeamInfo(teamID, false)) then
            -- is not AI?
            local nextWidth = (spec and 11 or 14) * (font2 and font2:GetTextWidth(name) or 100) + 10
            if nextWidth > maxWidth then
                maxWidth = nextWidth
            end
        end
    end

    local teamList = Spring_GetTeamList()
    for i = 1, #teamList do
        local teamID = teamList[i]
        if teamID ~= gaiaTeamID then
            local _, _, _, isAiTeam = Spring_GetTeamInfo(teamID, false)
            if isAiTeam then
                local name = GetAIName(teamID)

                local nextWidth = 14 * (font2 and font2:GetTextWidth(name) or 100) + 10
                if nextWidth > maxWidth then
                    maxWidth = nextWidth
                end
            end
        end
    end

    return maxWidth
end


function GeometryChange()
    --check if disappeared off the edge of screen
    widgetRight = widgetWidth + widgetPosX
    if widgetRight > vsx - (backgroundMargin * widgetScale) then
        widgetRight = vsx - (backgroundMargin * widgetScale)
        widgetPosX = vsx - ((widgetWidth + backgroundMargin) * widgetScale) - widgetRelRight
    end
    if widgetRight > vsx / 2 then
        right = true
    else
        right = false
    end
end

local function UpdateAlliances()
    local playerList = Spring_GetPlayerList()
    for _, playerID in pairs(playerList) do
        if player[playerID] and not player[playerID].spec then
            local alliances = {}
            for _, player2ID in pairs(playerList) do
                if player[player2ID] and not player[playerID].spec and not player[player2ID].spec and playerID ~= player2ID and player[playerID].team ~= nil and player[player2ID].team ~= nil and player[playerID].allyteam ~= player[player2ID].allyteam and Spring_AreTeamsAllied(player[player2ID].team, player[playerID].team) then
                    alliances[#alliances + 1] = player2ID
                end
            end
            player[playerID].alliances = alliances
        end
    end
end

---------------------------------------------------------------------------------------------------
--  LockCamera stuff
---------------------------------------------------------------------------------------------------

local function UpdateRecentBroadcasters()
    recentBroadcasters = {}

    for playerID, info in pairs(lastBroadcasts) do
        lastTime = info[1]
        if totalTime - lastTime <= listTime or playerID == lockPlayerID then
            if totalTime - lastTime <= listTime then
                recentBroadcasters[playerID] = totalTime - lastTime
            end
        end
    end
end

local function LockCamera(playerID)
    mySpecStatus, fullView, _ = Spring.GetSpectatingState()
    if playerID and playerID ~= myPlayerID and playerID ~= lockPlayerID and Spring_GetPlayerInfo(playerID) then
        if lockcameraHideEnemies and not select(3, Spring_GetPlayerInfo(playerID)) then
            Spring.SendCommands("specteam " .. select(4, Spring_GetPlayerInfo(playerID)))
            if not fullView then
                scheduledSpecFullView = 1 -- this is needed else the minimap/world doesnt update properly
                Spring.SendCommands("specfullview")
            else
                scheduledSpecFullView = 2 -- this is needed else the minimap/world doesnt update properly
                Spring.SendCommands("specfullview")
            end
            if lockcameraLos and mySpecStatus then
                desiredLosmode = 'los'
                desiredLosmodeChanged = os.clock()
            end
        elseif lockcameraHideEnemies and select(3, Spring_GetPlayerInfo(playerID)) then
            if not fullView then
                Spring.SendCommands("specfullview")
            end
            desiredLosmode = 'normal'
            desiredLosmodeChanged = os.clock()
        end
        lockPlayerID = playerID
        if lockcameraLos and mySpecStatus then
            desiredLosmode = 'los'
            desiredLosmodeChanged = os.clock()
        end
        myLastCameraState = myLastCameraState or GetCameraState()
        local info = lastBroadcasts[lockPlayerID]
        if info then
            SetCameraState(info[2], transitionTime)
        end
    else
        if myLastCameraState then
            SetCameraState(myLastCameraState, transitionTime)
            myLastCameraState = nil
        end
        if lockcameraHideEnemies and lockPlayerID and not select(3, Spring_GetPlayerInfo(lockPlayerID)) then
            if not fullView then
                Spring.SendCommands("specfullview")
            end
            if lockcameraLos and mySpecStatus then
                desiredLosmode = 'normal'
                desiredLosmodeChanged = os.clock()
            end
        end
        lockPlayerID = nil
        desiredLosmode = 'normal'
        desiredLosmodeChanged = os.clock()
    end
    UpdateRecentBroadcasters()
end

function GpuMemEvent(playerID, percentage)
    lastGpuMemData[playerID] = percentage
end

function FpsEvent(playerID, fps)
    lastFpsData[playerID] = fps

    WG.playerFPS = WG.playerFPS or {}
    WG.playerFPS[playerID] = fps
end

function SystemEvent(playerID, system)
    local lines, length = 0, 0
    local function helper(line)
        lines = lines + 1;
        if string.len(line) then
            length = string.len(line)
        end
        return ""
    end
    helper( system:gsub("(.-)\r?\n", helper) )
    lastSystemData[playerID] = system

    WG.playerSystemData = WG.playerSystemData or {}
    WG.playerSystemData[playerID] = system
end

function ActivityEvent(playerID)
    lastActivity[playerID] = os.clock()
end

function CameraBroadcastEvent(playerID, cameraState)
    --if cameraState is empty then transmission has stopped
    if not cameraState then
        if lastBroadcasts[playerID] then
            lastBroadcasts[playerID] = nil
            newBroadcaster = true
        end
        if lockPlayerID == playerID then
            LockCamera()
        end
        return
    end

    if not lastBroadcasts[playerID] and not newBroadcaster then
        newBroadcaster = true
    end

    lastBroadcasts[playerID] = { totalTime, cameraState }

    if playerID == lockPlayerID then
        SetCameraState(cameraState, transitionTime)
    end
end

---------------------------------------------------------------------------------------------------
--  Init/GameStart (creating players)
---------------------------------------------------------------------------------------------------

function widget:PlayerChanged(playerID)
    myPlayerID = Spring.GetMyPlayerID()
    myAllyTeamID = Spring.GetLocalAllyTeamID()
    myTeamID = Spring.GetLocalTeamID()
    myTeamPlayerID = select(2, Spring.GetTeamInfo(myTeamID))
    mySpecStatus, fullView, _ = Spring.GetSpectatingState()
    if mySpecStatus then
        hideShareIcons = true
    end
    GetAllPlayers()
    CreateLists()
end

function widget:PlayerAdded(playerID)
    GetAllPlayers()
    CreateLists()
end

function widget:PlayerRemoved(playerID, reason)
    GetAllPlayers()
    CreateLists()
end

function widget:Initialize()
    widget:ViewResize()

    widgetHandler:RegisterGlobal('CameraBroadcastEvent', CameraBroadcastEvent)
    widgetHandler:RegisterGlobal('ActivityEvent', ActivityEvent)
    widgetHandler:RegisterGlobal('FpsEvent', FpsEvent)
    widgetHandler:RegisterGlobal('GpuMemEvent', GpuMemEvent)
    widgetHandler:RegisterGlobal('SystemEvent', SystemEvent)
    UpdateRecentBroadcasters()

    mySpecStatus, fullView, _ = Spring.GetSpectatingState()
    if Spring.GetGameFrame() <= 0 then
        if mySpecStatus and not alwaysHideSpecs then
            specListShow = true
        else
            specListShow = false
        end
    end
    if Spring.GetConfigInt("ShowPlayerInfo") == 1 then
        Spring.SendCommands("info 0")
    end

    if Spring.GetGameFrame() > 0 then
        gameStarted = true
    end

    GeometryChange()
    SetModulesPositionX()
    SetSidePics()
    InitializePlayers()
    SortList()

    WG['advplayerlist_api'] = {}
	WG['advplayerlist_api'].GetAlwaysHideSpecs = function()
		return alwaysHideSpecs
	end
	WG['advplayerlist_api'].SetAlwaysHideSpecs = function(value)
		alwaysHideSpecs = value
		if alwaysHideSpecs and specListShow then
			specListShow = false
			SetModulesPositionX() --why?
			SortList()
			CreateLists()
		end
	end
    WG['advplayerlist_api'].GetScale = function()
        return customScale
    end
    WG['advplayerlist_api'].SetScale = function(value)
        customScale = value
        updateWidgetScale()
    end
    WG['advplayerlist_api'].GetPosition = function()
        return apiAbsPosition
    end
    WG['advplayerlist_api'].GetAbsoluteResbars = function()
        return absoluteResbarValues
    end
    WG['advplayerlist_api'].SetAbsoluteResbars = function(value)
        absoluteResbarValues = value
    end
    WG['advplayerlist_api'].GetLockPlayerID = function()
        return lockPlayerID
    end
    WG['advplayerlist_api'].SetLockPlayerID = function(playerID)
        LockCamera(playerID)
    end
    WG['advplayerlist_api'].GetLockHideEnemies = function()
        return lockcameraHideEnemies
    end
    WG['advplayerlist_api'].SetLockHideEnemies = function(value)
        lockcameraHideEnemies = value
        if lockPlayerID and not select(3, Spring_GetPlayerInfo(lockPlayerID)) then
            if not lockcameraHideEnemies then
                if not fullView then
                    Spring.SendCommands("specfullview")
                    if lockcameraLos and mySpecStatus then
                        desiredLosmode = 'normal'
                        desiredLosmodeChanged = os.clock()
                        Spring.SendCommands("togglelos")
                    end
                end
            else
                if fullView then
                    Spring.SendCommands("specfullview")
                    if lockcameraLos and mySpecStatus then
                        desiredLosmode = 'los'
                        desiredLosmodeChanged = os.clock()
                    end
                end
            end
        end
    end
    WG['advplayerlist_api'].GetLockTransitionTime = function()
        return transitionTime
    end
    WG['advplayerlist_api'].SetLockTransitionTime = function(value)
        transitionTime = value
    end
    WG['advplayerlist_api'].GetLockLos = function()
        return lockcameraLos
    end
    WG['advplayerlist_api'].SetLockLos = function(value)
        lockcameraLos = value
        if lockcameraHideEnemies and mySpecStatus and lockPlayerID and not select(3, Spring_GetPlayerInfo(lockPlayerID)) then
            if lockcameraLos and mySpecStatus then
                desiredLosmode = 'los'
                desiredLosmodeChanged = os.clock()
                Spring.SendCommands("togglelos")
            elseif not lockcameraLos and Spring.GetMapDrawMode() == "los" then
                desiredLosmode = 'normal'
                desiredLosmodeChanged = os.clock()
                Spring.SendCommands("togglelos")
            end
        end
    end
    WG['advplayerlist_api'].SetLosMode = function(value)
        desiredLosmode = value
        desiredLosmodeChanged = os.clock()
    end
    WG['advplayerlist_api'].GetModuleActive = function(module)
        return modules[module].active
    end
    WG['advplayerlist_api'].SetModuleActive = function(value)
        for n, module in pairs(modules) do
            if module.name == value[1] then
                modules[n].active = value[2]
                SetModulesPositionX()
                SortList()
                CreateLists()
                break
            end
        end
    end
end

function widget:GameFrame(n)
    if n > 0 and not gameStarted then
        if mySpecStatus and not alwaysHideSpecs then
            specListShow = true
        else
            specListShow = false
        end

        gameStarted = true
        SetSidePics()
        InitializePlayers()
        SetOriginalColourNames()
        SortList()
        forceMainListRefresh = true
    end
end

function widget:Shutdown()
    if WG['guishader'] then
        WG['guishader'].RemoveDlist('advplayerlist')
    end
    WG['advplayerlist_api'] = nil
    widgetHandler:DeregisterGlobal('CameraBroadcastEvent')
    widgetHandler:DeregisterGlobal('ActivityEvent')
    widgetHandler:DeregisterGlobal('FpsEvent')
    widgetHandler:DeregisterGlobal('GpuMemEvent')
    widgetHandler:DeregisterGlobal('SystemEvent')
    if ShareSlider then
        gl_DeleteList(ShareSlider)
    end
    if MainList then
        gl_DeleteList(MainList)
        gl_DeleteList(MainList2)
        gl_DeleteList(MainList3)
    end
    if Background then
        gl_DeleteList(Background)
    end
    if lockPlayerID then
        LockCamera()
    end
end

function widget:GameOver()
    if lockPlayerID then
        LockCamera()
    end
end

function SetSidePics()
    --record readyStates
    local playerList = Spring.GetPlayerList()
    for _, playerID in pairs(playerList) do
        playerReadyState[playerID] = Spring.GetGameRulesParam("player_" .. tostring(playerID) .. "_readyState")
    end

    --set factions, from TeamRulesParam when possible and from initial info if not
    local teamList = Spring_GetTeamList()
    for _, team in ipairs(teamList) do
        local teamSide
        if Spring_GetTeamRulesParam(team, 'startUnit') then
            local startunit = Spring_GetTeamRulesParam(team, 'startUnit')
            if startunit == sideOneDefID then
                teamSide = teamSideOne
            end
            if startunit == sideTwoDefID then
                teamSide = teamSideTwo
            end
            if startunit == sideThreeDefID then
                teamSide = teamSideThree
            end
        else
            _, _, _, _, teamSide = Spring_GetTeamInfo(team, false)
        end

        if teamSide then
            sidePics[team] = imageDirectory .. teamSide .. "_default.png"
        else
            sidePics[team] = imageDirectory .. "default.png"
        end
    end
end

function GetAllPlayers()
    local allteams = Spring_GetTeamList()
    teamN = table.maxn(allteams) - 1 --remove gaia
    for i = 0, teamN - 1 do
        local teamPlayers = Spring_GetPlayerList(i, true)
        player[i + specOffset] = CreatePlayerFromTeam(i)
        for _, playerID in ipairs(teamPlayers) do
            player[playerID] = CreatePlayer(playerID)
        end
    end
    local specPlayers = Spring_GetTeamList()
    for _, playerID in ipairs(specPlayers) do
        local active, _, spec = Spring_GetPlayerInfo(playerID, false)
        if spec then
            if active then
                player[playerID] = CreatePlayer(playerID)
            end
        end
    end
end

function InitializePlayers()
    myPlayerID = Spring_GetLocalPlayerID()
    myTeamID = Spring_GetLocalTeamID()
    myAllyTeamID = Spring_GetLocalAllyTeamID()
    for i = 0, specOffset*2 do
        player[i] = {}
    end
    GetAllPlayers()
end

function GetAliveAllyTeams()
    aliveAllyTeams = {}
    local allteams = Spring_GetTeamList()
    teamN = table.maxn(allteams) - 1 --remove gaia
    for i = 0, teamN - 1 do
        local _, _, isDead, _, _, tallyteam = Spring_GetTeamInfo(i, false)
        if not isDead then
            aliveAllyTeams[tallyteam] = true
        end
    end
end

function round(num, idp)
    local mult = 10 ^ (idp or 0)
    return math.floor(num * mult + 0.5) / mult
end

function GetSkill(playerID)
    local customtable = select(11, Spring.GetPlayerInfo(playerID))
    local tsMu = customtable.skill
    local tsSigma = customtable.skilluncertainty
    local tskill = ""
    if tsMu then
        tskill = tsMu and tonumber(tsMu:match("-?%d+%.?%d*")) or 0
        tskill = round(tskill, 0)
        if string.find(tsMu, ")", nil, true) then
            tskill = "\255" .. string.char(190) .. string.char(140) .. string.char(140) .. tskill -- ')' means inferred from lobby rank
        else
            -- show privacy mode
            local priv = ""
            if string.find(tsMu, "~", nil, true) then
                -- '~' means privacy mode is on
                priv = "\255" .. string.char(200) .. string.char(200) .. string.char(200) .. "*"
            end

            --show sigma
            local tsRed, tsGreen, tsBlue = 195, 195, 195
            if tsSigma and type(tsSigma) == 'number' then
                -- 0 is low sigma, 3 is high sigma
                tsSigma = tonumber(tsSigma)
                if tsSigma > 2 then
                    tsRed, tsGreen, tsBlue = 190, 130, 130
                elseif tsSigma == 2 then
                    tsRed, tsGreen, tsBlue = 140, 140, 140
                elseif tsSigma == 1 then
                    tsRed, tsGreen, tsBlue = 195, 195, 195
                elseif tsSigma < 1 then
                    tsRed, tsGreen, tsBlue = 250, 250, 250
                end
            end
            tskill = priv .. "\255" .. string.char(tsRed) .. string.char(tsGreen) .. string.char(tsBlue) .. tskill
        end
    else
        tskill = "\255" .. string.char(160) .. string.char(160) .. string.char(160) .. "?"
    end
    return tskill
end

function CreatePlayer(playerID)
    --generic player data
    local tname, _, tspec, tteam, tallyteam, tping, tcpu, tcountry, trank, _, _, desynced = Spring_GetPlayerInfo(playerID, false)
    local _, _, _, _, tside, tallyteam, tincomeMultiplier = Spring_GetTeamInfo(tteam, false)
    local tred, tgreen, tblue = Spring_GetTeamColor(tteam)
	if (not mySpecStatus) and anonymousMode ~= "disabled" and playerID ~= myPlayerID then
		tred, tgreen, tblue = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
	end

    --skill
    local tskill
    tskill = GetSkill(playerID)

    --cpu/ping
    local tpingLvl = GetPingLvl(tping)
    local tcpuLvl = GetCpuLvl(tcpu)
    tping = tping * 1000 - ((tping * 1000) % 1)
    tcpu = tcpu * 100 - ((tcpu * 100) % 1)

    -- resources
    local energy, energyStorage, energyIncome, metal, metalStorage, metalIncome = 0, 1, 0, 1, 0, 0
    if aliveAllyTeams[tallyteam] ~= nil and (mySpecStatus or myAllyTeamID == tallyteam) then
        energy, energyStorage, _, energyIncome = Spring_GetTeamResources(tteam, "energy")
        metal, metalStorage, _, metalIncome = Spring_GetTeamResources(tteam, "metal")
        if energy then
            energy = math.floor(energy)
            metal = math.floor(metal)
            if energy < 0 then
                energy = 0
            end
            if metal < 0 then
                metal = 0
            end
        else
            energy = 0
            metal = 0
        end
    end
    return {
        rank = trank,
        skill = tskill,
        name = tname,
        team = tteam,
        allyteam = tallyteam,
        red = tred,
        green = tgreen,
        blue = tblue,
        dark = GetDark(tred, tgreen, tblue),
        side = tside,
        pingLvl = tpingLvl,
        cpuLvl = tcpuLvl,
        ping = tping,
        cpu = tcpu,
        country = tcountry,
        dead = false,
        spec = tspec,
        ai = false,
        energy = energy,
        energyStorage = energyStorage,
        metal = metal,
        metalStorage = metalStorage,
        incomeMultiplier = tincomeMultiplier,
		desynced = desynced,
    }
end

function GetAIName(teamID)
    local _, _, _, name, _, options = Spring_GetAIInfo(teamID)
    local niceName = Spring.GetGameRulesParam('ainame_' .. teamID)

    if niceName then
        name = niceName

        if Spring.Utilities.ShowDevUI() and options.profile then
            name = name .. " [" .. options.profile .. "]"
        end
    end

    return Spring.I18N('ui.playersList.aiName', { name = name })
end

function CreatePlayerFromTeam(teamID)
    -- for when we don't have a human player occupying the slot, also when a player changes team (dies)
    local _, _, isDead, isAI, tside, tallyteam, tincomeMultiplier = Spring_GetTeamInfo(teamID, false)
    local tred, tgreen, tblue = Spring_GetTeamColor(teamID)
	if (not mySpecStatus) and anonymousMode ~= "disabled" and playerID ~= myPlayerID then
		tred, tgreen, tblue = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
	end
    local tname, ttotake, tskill, tai
    local tdead = true

    if isAI then
        tname = GetAIName(teamID)

        ttotake = false
        tdead = false
        tai = true
    else
        if Spring_GetGameSeconds() < 0.1 then
            tname = absentName
            ttotake = false
            tdead = false
        else
            ttotake = IsTakeable(teamID)
        end

        tai = false
    end

    if tname == nil then
        tname = absentName
    end
    tskill = ""

    -- resources
    local energy, energyStorage, energyIncome, metal, metalStorage, metalIncome = 0, 1, 0, 1, 0, 0
    if aliveAllyTeams[tallyteam] ~= nil and (mySpecStatus or myAllyTeamID == tallyteam) then
        energy, energyStorage, _, energyIncome = Spring_GetTeamResources(teamID, "energy")
        metal, metalStorage, _, metalIncome = Spring_GetTeamResources(teamID, "metal")
        energy = math.floor(energy or 0)
        metal = math.floor(metal or 0)
        if energy < 0 then
            energy = 0
        end
        if metal < 0 then
            metal = 0
        end
    end

    return {
        rank = 8, -- "don't know which" value
        skill = tskill,
        name = tname,
        team = teamID,
        allyteam = tallyteam,
        red = tred,
        green = tgreen,
        blue = tblue,
        dark = GetDark(tred, tgreen, tblue),
        side = tside,
        totake = ttotake,
        dead = tdead,
        spec = false,
        ai = tai,
        energy = energy,
        energyStorage = energyStorage,
        metal = metal,
        metalStorage = metalStorage,
        incomeMultiplier = tincomeMultiplier,
    }
end

function UpdatePlayerResources()
    allyTeamMaxStorage = {}
    local energy, energyStorage, metal, metalStorage = 0, 1, 0, 1
    local energyIncome, metalIncome
    for playerID, _ in pairs(player) do
        if player[playerID].name and not player[playerID].spec and player[playerID].team then
            if aliveAllyTeams[player[playerID].allyteam] ~= nil and (mySpecStatus or myAllyTeamID == player[playerID].allyteam) then
                energy, energyStorage, _, energyIncome = Spring_GetTeamResources(player[playerID].team, "energy")
                metal, metalStorage, _, metalIncome = Spring_GetTeamResources(player[playerID].team, "metal")
                if energy == nil then
                    -- need to be there for when you do /specfullview
                    energy, energyStorage, energyIncome, metal, metalStorage, metalIncome = 0, 0, 0, 0, 0, 0
                else
                    energy = math.floor(energy)
                    metal = math.floor(metal)
                    if energy < 0 then
                        energy = 0
                    end
                    if metal < 0 then
                        metal = 0
                    end
                end
                player[playerID].energy = energy
                player[playerID].energyIncome = energyIncome
                player[playerID].energyStorage = energyStorage
                player[playerID].metal = metal
                player[playerID].metalIncome = metalIncome
                player[playerID].metalStorage = metalStorage
                if not allyTeamMaxStorage[player[playerID].allyteam] then
                    allyTeamMaxStorage[player[playerID].allyteam] = {}
                end
                if not allyTeamMaxStorage[player[playerID].allyteam][1] or energyStorage > allyTeamMaxStorage[player[playerID].allyteam][1] then
                    allyTeamMaxStorage[player[playerID].allyteam][1] = energyStorage
                end
                if not allyTeamMaxStorage[player[playerID].allyteam][2] or metalStorage > allyTeamMaxStorage[player[playerID].allyteam][2] then
                    allyTeamMaxStorage[player[playerID].allyteam][2] = metalStorage
                end
            end
        end
    end
end

function GetDark(red, green, blue)
    -- Determines if the player color is dark (i.e. if a white outline for the sidePic is needed)
    --
    -- Threshold was changed since the new SPADS colors include green and blue which were
    -- just below the old threshold of 0.8
    -- https://github.com/Yaribz/SPADS/commit/e95f4480b98aafd03420ba3de19feb5494ef0b7e
    if red + green * 1.2 + blue * 0.4 < 0.65 then
        return true
    end
    return false
end

function SetOriginalColourNames()
    -- Saves the original team colours associated to team teamID
    for playerID, _ in pairs(player) do
        if player[playerID].name then
            if not player[playerID].spec then
                originalColourNames[playerID] = colourNames(player[playerID].team)
            end
        end
    end
end

---------------------------------------------------------------------------------------------------
--  Sorting player data
-- note: SPADS ensures that order of playerIDs/teams/allyteams as appropriate reflects TS (mu) order
---------------------------------------------------------------------------------------------------

function SortList()
    local myOldSpecStatus = mySpecStatus

    mySpecStatus = select(3, Spring_GetPlayerInfo(myPlayerID, false))

    -- checks if a team has died
    local teamList = Spring_GetTeamList()
    if mySpecStatus ~= myOldSpecStatus then
        if mySpecStatus then
            for _, team in ipairs(teamList) do
                if not select(3, Spring_GetTeamInfo(team, false)) then
                    -- not dead
                    Spec(team)
                    break
                end
            end
        end
    end

    myAllyTeamID = Spring_GetLocalAllyTeamID()
    myTeamID = Spring_GetLocalTeamID()

    drawList = {}
    drawListOffset = {}
    local vOffset = 0


    local aliveTeams = 0
    for _, team in ipairs(teamList) do
        if not select(3, Spring_GetTeamInfo(team, false)) then
            aliveTeams = aliveTeams  + 1
        end
    end
    playerScale = math.max(0.5, math.min(1, 33 / ((aliveTeams+((#teamList-aliveTeams)*0.5))-1)))

    -- calls the (cascade) sorting for players
    vOffset = SortAllyTeams(vOffset)

    -- calls the sortings for specs if see spec is on
    vOffset = SortSpecs(vOffset)

    -- set the widget height according to space needed to show team
    widgetHeight = vOffset + 3
    if widgetHeight ~= prevWidgetHeight then
        prevWidgetHeight = widgetHeight
        forceMainListRefresh = true
    end

    updateWidgetScale()
end

function SortAllyTeams(vOffset)
    -- adds ally teams to the draw list (own ally team first)
    -- (labels and separators are drawn)
    local allyTeamID
    local allyTeamList = Spring_GetAllyTeamList()
    local allyTeamsCount = table.maxn(allyTeamList) - 1

    --find own ally team
    vOffset = 12 / 2.66
    for allyTeamID = 0, allyTeamsCount - 1 do
        if allyTeamID == myAllyTeamID then
            vOffset = vOffset + (labelOffset*playerScale) - 3
            if drawAlliesLabel then
                drawListOffset[#drawListOffset + 1] = vOffset
                drawList[#drawList + 1] = -2  -- "Allies" label
                vOffset = SortTeams(allyTeamID, vOffset) + 2    -- Add the teams from the allyTeam
            else
                vOffset = SortTeams(allyTeamID, vOffset - (labelOffset*playerScale))
            end
            break
        end
    end

    -- add the others
    local firstenemy = true
    for allyTeamID = 0, allyTeamsCount - 1 do
        if allyTeamID ~= myAllyTeamID then
            if firstenemy then
                vOffset = vOffset + 13
                vOffset = vOffset + labelOffset - 3
                drawListOffset[#drawListOffset + 1] = vOffset
                drawList[#drawList + 1] = -3 -- "Enemies" label
                firstenemy = false
            else
                vOffset = vOffset + (separatorOffset*playerScale)
                drawListOffset[#drawListOffset + 1] = vOffset
                drawList[#drawList + 1] = -4 -- Enemy teams separator
            end
            vOffset = SortTeams(allyTeamID, vOffset) + 2 -- Add the teams from the allyTeam
        end
    end

    return vOffset
end

function SortTeams(allyTeamID, vOffset)
    -- Adds teams to the draw list (own team first)
    -- (teams are not visible as such unless they are empty or AI)
    local teamsList = Spring_GetTeamList(allyTeamID)

    --add teams
    for _, teamID in ipairs(teamsList) do
        drawListOffset[#drawListOffset + 1] = vOffset
        drawList[#drawList + 1] = -1
        vOffset = SortPlayers(teamID, allyTeamID, vOffset) -- adds players form the team
    end

    return vOffset
end

function SortPlayers(teamID, allyTeamID, vOffset)
    -- Adds players to the draw list (self first)
    local playersList = Spring_GetPlayerList(teamID, true)
    local noPlayer = true

    -- add own player (if not spec)
    if myTeamID == teamID then
        if player[myPlayerID].name ~= nil then
            if mySpecStatus == false then
                vOffset = vOffset + (playerOffset*playerScale)
                drawListOffset[#drawListOffset + 1] = vOffset
                drawList[#drawList + 1] = myPlayerID -- new player (with ID)
                player[myPlayerID].posY = vOffset
                noPlayer = false
            end
        end
    end

    -- add other players (if not spec)
    for _, playerID in ipairs(playersList) do
        if playerID ~= myPlayerID then
            if player[playerID].name ~= nil then
                if player[playerID].spec ~= true then
                    if enemyListShow or player[playerID].allyteam == myAllyTeamID then
                        vOffset = vOffset + (playerOffset*playerScale)
                        drawListOffset[#drawListOffset + 1] = vOffset
                        drawList[#drawList + 1] = playerID -- new player (with ID)
                        player[playerID].posY = vOffset
                        noPlayer = false
                    end
                end
            end
        end
    end

    -- add AI teams
    if select(4, Spring_GetTeamInfo(teamID, false)) then
        if enemyListShow or player[specOffset + teamID].allyteam == myAllyTeamID then
            -- is AI
            vOffset = vOffset + (playerOffset*playerScale)
            drawListOffset[#drawListOffset + 1] = vOffset
            drawList[#drawList + 1] = specOffset + teamID -- new AI team (instead of players)
            player[specOffset + teamID].posY = vOffset
            noPlayer = false
        end
    end

    -- add no player token if no player found in this team at this point
    if noPlayer then
        if enemyListShow or player[specOffset + teamID].allyteam == myAllyTeamID then
            vOffset = vOffset + ((playerOffset - deadPlayerHeightReduction)*playerScale)
            drawListOffset[#drawListOffset + 1] = vOffset
            drawList[#drawList + 1] = specOffset + teamID  -- no players team
            player[specOffset + teamID].posY = vOffset
            if Spring_GetGameFrame() > 0 then
                player[specOffset + teamID].totake = IsTakeable(teamID)
            end
        end
    end

    return vOffset
end

function SortSpecs(vOffset)
    local playersList = Spring_GetPlayerList(-1, true)
    local numSpecs = 0
    for _, playerID in ipairs(playersList) do
        local _, active, spec = Spring_GetPlayerInfo(playerID, false)
        if spec and active then
            numSpecs = numSpecs + 1
        end
    end
    specScale = math.max(0.45, math.min(1, 45 / numSpecs))

    -- Adds specs to the draw list
    local noSpec = true
    for _, playerID in ipairs(playersList) do
        local _, active, spec = Spring_GetPlayerInfo(playerID, false)
        if spec and active then
            if player[playerID] and player[playerID].name ~= nil then

                -- add "Specs" label if first spec
                if noSpec then
                    vOffset = vOffset + ((specVertOffset+1)*specScale)
                    vOffset = vOffset + labelOffset - (2*specScale)
                    drawListOffset[#drawListOffset + 1] = vOffset
                    drawList[#drawList + 1] = -5
                    noSpec = false
                    specJoinedOnce = true
                    vOffset = vOffset + 4
                end

                -- add spectator
                if specListShow then
                    vOffset = vOffset + (specVertOffset*specScale)
                    drawListOffset[#drawListOffset + 1] = vOffset
                    drawList[#drawList + 1] = playerID
                    player[playerID].posY = vOffset
                end
            end
        end
    end

    -- add "Specs" label
    if specJoinedOnce and noSpec then
        vOffset = vOffset + 13
        vOffset = vOffset + labelOffset - 2
        drawListOffset[#drawListOffset + 1] = vOffset
        drawList[#drawList + 1] = -5
        vOffset = vOffset + 4
    end

    return vOffset
end

---------------------------------------------------------------------------------------------------
--  Draw control
---------------------------------------------------------------------------------------------------

function widget:DrawScreen()
	AdvPlayersListAtlas:RenderTasks()
	--AdvPlayersListAtlas:DrawToScreen()
    local mouseX, mouseY, mouseButtonL, mmb, rmb, mouseOffScreen, cameraPanMode = Spring.GetMouseState()

    -- draws the background
    if Background then
        gl_CallList(Background)
    else
        CreateBackground()
    end

    local scaleDiffX = -((widgetPosX * widgetScale) - widgetPosX) / widgetScale
    local scaleDiffY = -((widgetPosY * widgetScale) - widgetPosY) / widgetScale
    gl.Scale(widgetScale, widgetScale, 0)
    gl.Translate(scaleDiffX, scaleDiffY, 0)

    if not MainList2 then
        CreateMainList(true, true, true)
    end
    if MainList and MainList2 and MainList3 then
        gl_CallList(MainList)
        gl_CallList(MainList2)
        gl_CallList(MainList3)
    end

    -- handle/draw hover highlight
    if mySpecStatus then
        local posY
        local x, y, b = Spring.GetMouseState()
        for _, i in ipairs(drawList) do
            if i > -1 then -- and i < specOffset
                posY = widgetPosY + widgetHeight - (player[i].posY or 0)
                if myTeamID ~= player[i].team and not player[i].spec and not player[i].dead and player[i].name ~= absentName and IsOnRect(x, y, m_name.posX + widgetPosX + 1, posY, m_name.posX + widgetPosX + m_name.width, posY + (playerOffset*playerScale)) then
                    UiSelectHighlight(widgetPosX, posY, widgetPosX + widgetPosX + 2 + 4, posY + (playerOffset*playerScale), nil, b and 0.28 or 0.14)
                end
            end
        end
    end

    -- draws share energy/metal sliders
    if not ShareSlider then
        CreateShareSlider()
    end
    if ShareSlider then
        gl_CallList(ShareSlider)
    end

    local scaleReset = widgetScale / widgetScale / widgetScale
    gl.Translate(-scaleDiffX, -scaleDiffY, 0)
    gl.Scale(scaleReset, scaleReset, 0)
end

function CreateLists(onlyMainList, onlyMainList2, onlyMainList3)
    if not onlyMainList and not onlyMainList2 and not onlyMainList3 then
        onlyMainList = true
        onlyMainList2 = true
        if m_resources.active or m_income.active then
            onlyMainList3 = true
        end
    end
    if onlyMainList2 then
        timeCounter = 0
    end
    if onlyMainList3 then
        timeFastCounter = 0
    end
    if onlyMainList2 then
        if tipTextTime+updateFastRate < os.clock() then
            tipText = nil
            drawTipText = nil
            tipTextTime = 0
        end
        CheckTime() --this also calls CheckPlayers
        UpdateRecentBroadcasters()
        UpdateAlliances()
    end
    if not onlyMainList3 then
        GetAliveAllyTeams()
    end
    if onlyMainList2 or onlyMainList3 then
        if m_resources.active or m_income.active then
            UpdateResources()
            UpdatePlayerResources()
        end
    end
    if onlyMainList then
        CreateBackground()
    end
    CreateMainList(onlyMainList, onlyMainList2, onlyMainList3)
    if onlyMainList2 then
        CreateShareSlider()
    end
end

---------------------------------------------------------------------------------------------------
--  Background gllist
---------------------------------------------------------------------------------------------------

function CreateBackground()
    local margin = backgroundMargin

    local BLcornerX = widgetPosX - margin
    local BLcornerY = widgetPosY - margin
    local TRcornerX = widgetPosX + widgetWidth + margin
    local TRcornerY = widgetPosY + widgetHeight - 1 + margin

    local absLeft = math.floor(BLcornerX - ((widgetPosX - BLcornerX) * (widgetScale - 1)))
    local absBottom = math.floor(BLcornerY - ((widgetPosY - BLcornerY) * (widgetScale - 1)))
    local absRight = math.ceil(TRcornerX - ((widgetPosX - TRcornerX) * (widgetScale - 1)))
    local absTop = math.ceil(TRcornerY - ((widgetPosY - TRcornerY) * (widgetScale - 1)))

    local prevApiAbsPosition = apiAbsPosition
    if prevApiAbsPosition[1] ~= absTop or prevApiAbsPosition[2] ~= absLeft or prevApiAbsPosition[3] ~= absBottom or prevApiAbsPosition[4] ~= absRight then
        forceMainListRefresh = true
    end
    apiAbsPosition = { absTop, absLeft, absBottom, absRight, widgetScale, right, false }

    local paddingBottom = bgpadding
    local paddingRight = bgpadding
    local paddingTop = bgpadding
    local paddingLeft = bgpadding
    if absBottom <= 0.2 then
        paddingBottom = 0
    end
    if absRight >= vsx - 0.2 then
        paddingRight = 0
    end
    if absTop <= 0.2 then
        paddingTop = 0
    end
    if absLeft <= 0.2 then
        paddingLeft = 0
    end

    if forceMainListRefresh or not Background or (WG['guishader'] and not BackgroundGuishader) then
        if WG['guishader'] then
            BackgroundGuishader = gl_DeleteList(BackgroundGuishader)
            BackgroundGuishader = gl_CreateList(function()
                RectRound(absLeft, absBottom, absRight, absTop, elementCorner, math.min(paddingLeft, paddingTop), math.min(paddingTop, paddingRight), math.min(paddingRight, paddingBottom), math.min(paddingBottom, paddingLeft))
            end)
            WG['guishader'].InsertDlist(BackgroundGuishader, 'advplayerlist', true)
        end
        if Background then
            Background = gl_DeleteList(Background)
        end
        Background = gl_CreateList(function()
            UiElement(absLeft, absBottom, absRight, absTop, math.min(paddingLeft, paddingTop), math.min(paddingTop, paddingRight), math.min(paddingRight, paddingBottom), math.min(paddingBottom, paddingLeft))
            gl_Color(1, 1, 1, 1)
        end)
    end
end

---------------------------------------------------------------------------------------------------
--  Main (player) gllist
---------------------------------------------------------------------------------------------------

function UpdateResources()
    if sliderPosition then
        if energyPlayer ~= nil then
			if energyPlayer.team == myTeamID then
				local current, storage = Spring_GetTeamResources(myTeamID, "energy")
				maxShareAmount = storage - current
				shareAmount = maxShareAmount * sliderPosition / shareSliderHeight
				shareAmount = shareAmount - (shareAmount % 1)
			else
				maxShareAmount = Spring_GetTeamResources(myTeamID, "energy")
				local energy, energyStorage, _, _, _, shareSliderPos = Spring_GetTeamResources(energyPlayer.team, "energy")
				maxShareAmount = math.min(maxShareAmount, ((energyStorage*shareSliderPos) - energy))
                shareAmount = maxShareAmount * sliderPosition / shareSliderHeight
                shareAmount = shareAmount - (shareAmount % 1)
            end
        end

        if metalPlayer ~= nil then
            if metalPlayer.team == myTeamID then
                local current, storage = Spring_GetTeamResources(myTeamID, "metal")
                maxShareAmount = storage - current
                shareAmount = maxShareAmount * sliderPosition / shareSliderHeight
                shareAmount = shareAmount - (shareAmount % 1)
            else
                maxShareAmount = Spring_GetTeamResources(myTeamID, "metal")
				local metal, metalStorage, _, _, _, shareSliderPos = Spring_GetTeamResources(metalPlayer.team, "metal")
				maxShareAmount = math.min(maxShareAmount, ((metalStorage*shareSliderPos) - metal))
                shareAmount = maxShareAmount * sliderPosition / shareSliderHeight
                shareAmount = shareAmount - (shareAmount % 1)
            end
        end
    end
end

function CheckTime()
    local period = 0.5
    now = os.clock()
    if now > (lastTime + period) then
        lastTime = now
        CheckPlayersChange()
        blink = not blink
        for playerID = 0, specOffset-1 do
            if player[playerID] ~= nil then
                if player[playerID].pointTime ~= nil then
                    if player[playerID].pointTime <= now then
                        player[playerID].pointX = nil
                        player[playerID].pointY = nil
                        player[playerID].pointZ = nil
                        player[playerID].pointTime = nil
                    end
                end
            end
        end
    end
end

function CreateMainList(onlyMainList, onlyMainList2, onlyMainList3)
    forceMainListRefresh = false

    local mouseX, mouseY = Spring_GetMouseState()

    local prevNumberOfSpecs = numberOfSpecs
    local prevNumberOfEnemies = numberOfEnemies
    numberOfSpecs = 0
    numberOfEnemies = 0
    local active, spec
    local playerList = Spring_GetPlayerList()
    for _, playerID in ipairs(playerList) do
        _, active, spec = Spring_GetPlayerInfo(playerID)
        if active and spec then
            numberOfSpecs = numberOfSpecs + 1
        end
    end
    local playerID, isAiTeam, allyTeamID
    local teamList = Spring_GetTeamList()
    for i = 1, #teamList do
        local teamID = teamList[i]
        if teamID ~= gaiaTeamID then
            _, playerID, _, isAiTeam, _, allyTeamID = Spring_GetTeamInfo(teamID, false)
            if aliveAllyTeams[allyTeamID] then
                _, active = Spring_GetPlayerInfo(playerID)
                if active or isAiTeam then
                    if allyTeamID ~= myAllyTeamID then
                        numberOfEnemies = numberOfEnemies + 1
                    end
                end
            end
        end
    end
    if prevNumberOfSpecs ~= numberOfSpecs or prevNumberOfEnemies ~= numberOfEnemies then
        prevNumberOfSpecs = numberOfSpecs
        prevNumberOfEnemies = numberOfEnemies
        forceMainListRefresh = true
    end
    if onlyMainList then
        local leader
        if MainList then
            MainList = gl_DeleteList(MainList)
        end
        MainList = gl_CreateList(function()
            for i, drawObject in ipairs(drawList) do
                if drawObject == -5 then
                    specsLabelOffset = drawListOffset[i]
                    local specAmount = numberOfSpecs
                    if numberOfSpecs == 0 or (specListShow and numberOfSpecs < 10) then
                        specAmount = ""
                    end
                    DrawLabel(" ".. Spring.I18N('ui.playersList.spectators', { amount = specAmount }), drawListOffset[i], specListShow)
                    if Spring.GetGameFrame() <= 0 then
                        if specListShow then
                            DrawLabelTip( Spring.I18N('ui.playersList.hideSpecs'), drawListOffset[i], 95)
                        else
                            DrawLabelTip(Spring.I18N('ui.playersList.showSpecs'), drawListOffset[i], 95)
                        end
                    end
                elseif drawObject == -4 then
                    DrawSeparator(drawListOffset[i])
                elseif drawObject == -3 then
                    enemyLabelOffset = drawListOffset[i]
                    local enemyAmount = numberOfEnemies
                    if numberOfEnemies == 0 or enemyListShow then
                        enemyAmount = ""
                    end
                    DrawLabel(" "..Spring.I18N('ui.playersList.enemies', { amount = enemyAmount }), drawListOffset[i], true)
                    DrawLabel(" "..Spring.I18N('ui.playersList.enemies', { amount = enemyAmount }), drawListOffset[i], true)
                    if Spring.GetGameFrame() <= 0 then
                        if enemyListShow then
                            DrawLabelTip( Spring.I18N('ui.playersList.hideEnemies'), drawListOffset[i], 95)
                        else
                            DrawLabelTip(Spring.I18N('ui.playersList.showEnemies'), drawListOffset[i], 95)
                        end
                    end
                elseif drawObject == -2 then
                    DrawLabel(" " .. Spring.I18N('ui.playersList.allies'), drawListOffset[i], true)
                    if Spring.GetGameFrame() <= 0 then
                        DrawLabelTip(Spring.I18N('ui.playersList.trackPlayer'), drawListOffset[i], 46)
                    end
                elseif drawObject == -1 then
                    leader = true
                else
                    DrawPlayer(drawObject, leader, drawListOffset[i], mouseX, mouseY, true, false, false)
                end

                -- draw player tooltip later so they will be on top of players drawn below
                if tipText ~= nil then
                    drawTipText = tipText
                end
            end

            if drawTipText ~= nil then
                tipText = drawTipText
                tipTextTime = os.clock()
            end
        end)
    end

    if onlyMainList2 then
        if MainList2 then
            MainList2 = gl_DeleteList(MainList2)
        end
        MainList2 = gl_CreateList(function()
            local leader
            for i, drawObject in ipairs(drawList) do
                if drawObject == -1 then
                    leader = true
                elseif drawObject >= 0 then
                    DrawPlayer(drawObject, leader, drawListOffset[i], mouseX, mouseY, false, true, false)
                end
            end
        end)
    end

    if onlyMainList3 then
        if MainList3 then
            MainList3 = gl_DeleteList(MainList3)
        end
        MainList3 = gl_CreateList(function()
            local leader
            for i, drawObject in ipairs(drawList) do
                if drawObject == -1 then
                    leader = true
                elseif drawObject >= 0 then
                    DrawPlayer(drawObject, leader, drawListOffset[i], mouseX, mouseY, false, false, true)
                end
            end
        end)
    end
end

function DrawLabel(text, vOffset, drawSeparator)
    if widgetWidth < 67 then
        text = string.sub(text, 0, 1)
    end

    font:Begin()
    font:SetTextColor(0.87, 0.87, 0.87, 1)
    font:Print(text, widgetPosX, widgetPosY + widgetHeight - vOffset + 7.5, 12, "on")
    font:End()
end

function DrawLabelTip(text, vOffset, xOffset)
    if widgetWidth < 67 then
        text = string.sub(text, 0, 1)
    end

    font:Begin()
    font:SetTextColor(0.9, 0.9, 0.9, 0.66)
    font:Print(text, widgetPosX + xOffset, widgetPosY + widgetHeight - vOffset + 7.5, 10, "on")
    font:End()
end

function DrawSeparator(vOffset)
    vOffset = vOffset - 2
    RectRound(widgetPosX + 2, widgetPosY + widgetHeight - vOffset - (1.5 / widgetScale), widgetPosX + widgetWidth - 2, widgetPosY + widgetHeight - vOffset + (1.5 / widgetScale), (0.5 / widgetScale), 1, 1, 1, 1, { 0.66, 0.66, 0.66, 0.35 }, { 0, 0, 0, 0.35 })
end

-- onlyMainList2 to only draw dynamic stuff like ping/alliances/buttons
-- onlyMainList3 to only draw resources
function DrawPlayer(playerID, leader, vOffset, mouseX, mouseY, onlyMainList, onlyMainList2, onlyMainList3)
    --if hideDeadTeams and player[playerID].dead then --and not player[playerID].totake then   -- totake is still active when teammates
    --    return
    --end

    player[playerID].posY = vOffset

    tipY = nil

    local dark, rank, skill, country
    if onlyMainList then
        --local red = player[playerID].red
        --local green = player[playerID].green
        --local blue = player[playerID].blue
        dark = player[playerID].dark
        rank = player[playerID].rank
        skill = player[playerID].skill
        country = player[playerID].country
    end

    local name = player[playerID].name
    local team = player[playerID].team
    local allyteam = player[playerID].allyteam
    local pingLvl = player[playerID].pingLvl
    local cpuLvl = player[playerID].cpuLvl
    local ping = player[playerID].ping
    local cpu = player[playerID].cpu
    local spec = player[playerID].spec
    local totake = player[playerID].totake
    local needm = player[playerID].needm
    local neede = player[playerID].neede
    local dead = player[playerID].dead
    local ai = player[playerID].ai
    local alliances = player[playerID].alliances
    local posY = widgetPosY + widgetHeight - vOffset
    local tipPosY = widgetPosY + ((widgetHeight - vOffset) * widgetScale)
	local desynced = player[playerID].desynced

    local alpha = 0.33
    local alphaActivity = 0

    -- keyboard/mouse activity
    if lastActivity[playerID] ~= nil and type(lastActivity[playerID]) == "number" then
        alphaActivity = math.max(0, math.min(1, (8 - math.floor(now - lastActivity[playerID])) / 5.5))
        alphaActivity = 0.33 + (alphaActivity * 0.21)
        alpha = alphaActivity
    end
    -- camera activity
    if recentBroadcasters[playerID] ~= nil and type(recentBroadcasters[playerID]) == "number" then
        local alphaCam =  math.max(0, math.min(1, (13 - math.floor(recentBroadcasters[playerID])) / 8.5))
        alpha = 0.33 + (alphaCam * 0.42)
        if alpha < alphaActivity then
            alpha = alphaActivity
        end
    end

    if mouseY >= tipPosY and mouseY <= tipPosY + (16 * widgetScale) then
        tipY = true
    end

    if onlyMainList and lockPlayerID ~= nil and lockPlayerID == playerID then
        -- active
        DrawCamera(posY, true)
    end

    if not spec then
        --player
        if onlyMainList2 and drawAllyButton and not dead and alliances ~= nil and #alliances > 0 then
            DrawAlliances(alliances, posY)
        end
        if leader then
            -- take / share buttons
            if mySpecStatus == false then
                if onlyMainList2 then
                    if allyteam == myAllyTeamID then
                        if m_take.active then
                            if totake then
                                DrawTakeSignal(posY)
                                if tipY then
                                    TakeTip(mouseX)
                                end
                            end
                        end
                        if m_share.active and not dead and not hideShareIcons then
                            DrawShareButtons(posY, needm, neede)
                            if tipY then
                                ShareTip(mouseX, playerID)
                            end
                        end
                    end
                    if drawAllyButton and not dead then
                        if tipY then
                            AllyTip(mouseX, playerID)
                        end
                    end
                end
            else
                if onlyMainList and m_indent.active and Spring_GetMyTeamID() == team then
                    DrawDot(posY)
                end
            end
            if onlyMainList then
                if m_ID.active and not dead then
                    DrawID(team, posY, dark, dead)
                end
                if m_skill.active then
                    DrawSkill(skill, posY, dark)
                end
            end
        end

        if onlyMainList then
            if m_rank.active then
                DrawRank(tonumber(rank), posY)
            end
            if m_country.active and country ~= "" then
                DrawCountry(country, posY)
            end
            if name ~= absentName and m_side.active then
                DrawSidePic(team, playerID, posY, leader, dark, ai)
            end
            if m_name.active then
                DrawName(name, team, posY, dark, playerID, desynced)
            end
        end

        if onlyMainList2 and m_alliance.active and drawAllyButton and not mySpecStatus and not dead and team ~= myTeamID then
            DrawAlly(posY, player[playerID].team)
        end

        if (onlyMainList2 or onlyMainList3) and not isSingle and (m_resources.active or m_income.active) and aliveAllyTeams[allyteam] ~= nil and player[playerID].energy ~= nil then
            if mySpecStatus or myAllyTeamID == allyteam then
                local e = player[playerID].energy
                local es = player[playerID].energyStorage
                local ei = player[playerID].energyIncome
                local m = player[playerID].metal
                local ms = player[playerID].metalStorage
                local mi = player[playerID].metalIncome
                if es > 0 then
                    if onlyMainList3 and m_resources.active and (not dead or (e > 0 or m > 0)) then
                        DrawResources(e, es, m, ms, posY, dead, (absoluteResbarValues and (allyTeamMaxStorage[allyteam] and allyTeamMaxStorage[allyteam][1])), (absoluteResbarValues and (allyTeamMaxStorage[allyteam] and allyTeamMaxStorage[allyteam][2])))
                        if tipY then
                            ResourcesTip(mouseX, e, es, ei, m, ms, mi)
                        end
                    end
                    if onlyMainList2 and m_income.active then
                        DrawIncome(ei, mi, posY, dead)
                        if tipY then
                            IncomeTip(mouseX, ei, mi)
                        end
                    end
                end
            end
        end
    else
        -- spectator
        if specListShow and m_name.active then
            DrawSmallName(name, team, posY, false, playerID, alpha)
        end
    end

    if onlyMainList2 and m_cpuping.active and not isSinglePlayer then
        if cpuLvl ~= nil then
            -- draws CPU usage and ping icons (except AI and ghost teams)
            DrawPingCpu(pingLvl, cpuLvl, posY, spec, 1, cpu, lastFpsData[playerID])
            if tipY then
                PingCpuTip(mouseX, ping, cpu, lastFpsData[playerID], lastGpuMemData[playerID], lastSystemData[playerID], name, team, spec)
            end
        end
    end

    if playerID < specOffset then
        if onlyMainList then
            if m_chat.active and mySpecStatus == false and spec == false then
                if playerID ~= myPlayerID then
                    DrawChatButton(posY)
                end
            end
        else
            if m_point.active then
                if player[playerID].pointTime ~= nil then
                    if player[playerID].allyteam == myAllyTeamID or mySpecStatus then
                        DrawPoint(posY, player[playerID].pointTime - now)
                        if tipY then
                            PointTip(mouseX)
                        end
                    end
                end
            end
        end
    end

    gl_Texture(false)
end

function DrawTakeSignal(posY)
    if blink then
        -- Draws a blinking rectangle if the player of the same team left (/take option)
        if right then
            gl_Color(0.7, 0.7, 0.7)
            gl_Texture(pics["arrowPic"])
            DrawRect(widgetPosX - 14, posY, widgetPosX, posY + 16)
            gl_Color(1, 1, 1)
            gl_Texture(pics["takePic"])
            DrawRect(widgetPosX - 57, posY - 15, widgetPosX - 12, posY + 32)
        else
            local leftPosX = widgetPosX + widgetWidth
            gl_Color(0.7, 0.7, 0.7)
            gl_Texture(pics["arrowPic"])
            DrawRect(leftPosX + 14, posY, leftPosX, posY + 16)
            gl_Color(1, 1, 1)
            gl_Texture(pics["takePic"])
            DrawRect(leftPosX + 12, posY - 15, leftPosX + 57, posY + 32)
        end
    end
end

function DrawShareButtons(posY, needm, neede)
    gl_Color(1, 1, 1, 1)
    gl_Texture(pics["unitsPic"])
    DrawRect(m_share.posX + widgetPosX + (1*playerScale), posY, m_share.posX + widgetPosX + (17*playerScale), posY + (16*playerScale))
    gl_Texture(pics["energyPic"])
    DrawRect(m_share.posX + widgetPosX + (17*playerScale), posY, m_share.posX + widgetPosX + (33*playerScale), posY + (16*playerScale))
    gl_Texture(pics["metalPic"])
    DrawRect(m_share.posX + widgetPosX + (33*playerScale), posY, m_share.posX + widgetPosX + (49*playerScale), posY + (16*playerScale))
    gl_Texture(pics["lowPic"])

    if needm then
        DrawRect(m_share.posX + widgetPosX + (33*playerScale), posY, m_share.posX + widgetPosX + (49*playerScale), posY + (16*playerScale))
    end

    if neede then
        DrawRect(m_share.posX + widgetPosX + (17*playerScale), posY, m_share.posX + widgetPosX + (33*playerScale), posY + (16*playerScale))
    end

    gl_Texture(false)
end

function DrawChatButton(posY)
    gl_Texture(pics["chatPic"])
    DrawRect(m_chat.posX + widgetPosX + (1*playerScale), posY, m_chat.posX + widgetPosX + (17*playerScale), posY + (16*playerScale))
end

function DrawResources(energy, energyStorage, metal, metalStorage, posY, dead, maxAllyTeamEnergyStorage, maxAllyTeamMetalStorage)
    -- limit to prevent going out of bounds when losing storage
    energy = math.min(energy, energyStorage)
    metal = math.min(metal, metalStorage)

    local paddingLeft = 2
    local paddingRight = 2
    local barWidth = m_resources.width - paddingLeft - paddingRight
    local y1Offset
    local y2Offset
    local sizeMult = playerScale + ((1-playerScale)*0.5)
    if not dead then
        y1Offset = 11 * sizeMult
        y2Offset = 9 * sizeMult
    else
        y1Offset = 10 * sizeMult
        y2Offset = 8.6 * sizeMult
    end
    local maxStorage = (maxAllyTeamMetalStorage and maxAllyTeamMetalStorage or metalStorage)
    gl_Color(1, 1, 1, 0.18)
    gl_Texture(pics["resbarBgPic"])
    DrawRect(m_resources.posX + widgetPosX + paddingLeft, posY + y1Offset, m_resources.posX + widgetPosX + paddingLeft + (barWidth * (metalStorage/maxStorage)), posY + y2Offset)
    gl_Color(1, 1, 1, 1)
    gl_Texture(pics["resbarPic"])
    DrawRect(m_resources.posX + widgetPosX + paddingLeft, posY + y1Offset, m_resources.posX + widgetPosX + paddingLeft + ((barWidth / maxStorage) * metal), posY + y2Offset)

    if (barWidth / maxStorage) * metal > 0.8 then
        local glowsize = 10
        gl_Color(1, 1, 1.2, 0.08)
        gl_Texture(pics["barGlowCenterPic"])
        DrawRect(m_resources.posX + widgetPosX + paddingLeft, posY + y1Offset + glowsize, m_resources.posX + widgetPosX + paddingLeft + ((barWidth / maxStorage) * metal), posY + y2Offset - glowsize)

        gl_Texture(pics["barGlowEdgePic"])
        DrawRect(m_resources.posX + widgetPosX + paddingLeft - (glowsize * 1.8), posY + y1Offset + glowsize, m_resources.posX + widgetPosX + paddingLeft, posY + y2Offset - glowsize)
        DrawRect(m_resources.posX + widgetPosX + paddingLeft + ((barWidth / maxStorage) * metal) + (glowsize * 1.8), posY + y1Offset + glowsize, m_resources.posX + widgetPosX + paddingLeft + ((barWidth / maxStorage) * metal), posY + y2Offset - glowsize)
    end

    if dead then
        y1Offset = 7.4 * sizeMult
        y2Offset = 6 * sizeMult
    else
       y1Offset = 7 * sizeMult
       y2Offset = 5 * sizeMult
    end
    maxStorage = (maxAllyTeamEnergyStorage and maxAllyTeamEnergyStorage or energyStorage)
    gl_Color(1, 1, 0, 0.18)
    gl_Texture(pics["resbarBgPic"])
    DrawRect(m_resources.posX + widgetPosX + paddingLeft, posY + y1Offset, m_resources.posX + widgetPosX + paddingLeft + (barWidth * (energyStorage/maxStorage)), posY + y2Offset)
    gl_Color(1, 1, 0, 1)
    gl_Texture(pics["resbarPic"])
    DrawRect(m_resources.posX + widgetPosX + paddingLeft, posY + y1Offset, m_resources.posX + widgetPosX + paddingLeft + ((barWidth / maxStorage) * energy), posY + y2Offset)

    if (barWidth / maxStorage) * energy > 0.8 then
        local glowsize = 10
        gl_Color(1, 1, 0.2, 0.08)
        gl_Texture(pics["barGlowCenterPic"])
        DrawRect(m_resources.posX + widgetPosX + paddingLeft, posY + y1Offset + glowsize, m_resources.posX + widgetPosX + paddingLeft + ((barWidth / maxStorage) * energy), posY + y2Offset - glowsize)

        gl_Texture(pics["barGlowEdgePic"])
        DrawRect(m_resources.posX + widgetPosX + paddingLeft - (glowsize * 1.8), posY + y1Offset + glowsize, m_resources.posX + widgetPosX + paddingLeft, posY + y2Offset - glowsize)
        DrawRect(m_resources.posX + widgetPosX + paddingLeft + ((barWidth / maxStorage) * energy) + (glowsize * 1.8), posY + y1Offset + glowsize, m_resources.posX + widgetPosX + paddingLeft + ((barWidth / maxStorage) * energy), posY + y2Offset - glowsize)
    end
end

local function formatRes(number)
    local label
    if number > 10000 then
        label = table.concat({ math.floor(math.round(number / 1000)), "k" })
    elseif number > 1000 then
        label = table.concat({ string.sub(math.round(number / 1000, 1), 1, 2 + (string.find(math.round(number / 1000, 1), ".", nil, true) or 0)), "k" })
    elseif number > 10 then
        label = string.sub(math.round(number, 0), 1, 3 + (string.find(math.round(number, 0), ".", nil, true) or 0))
    else
        label = string.sub(math.round(number, 1), 1, 2 + (string.find(math.round(number, 1), ".", nil, true) or 0))
    end
    return tostring(label)
end

function DrawIncome(energy, metal, posY, dead)
    local fontsize = dead and 4.5 or 8.5
    local sizeMult = playerScale + ((1-playerScale)*0.33)
    fontsize = fontsize * sizeMult
    font:Begin()
    if energy > 0 then
        font:Print('\255\255\255\050'..formatRes(math.floor(energy)), m_income.posX + widgetPosX + m_income.width - 2, posY + ((fontsize*0.2)*sizeMult) + (dead and 1 or 0), fontsize, "or")
    end
    if metal > 0 then
        font:Print('\255\235\235\235'..formatRes(math.floor(metal)), m_income.posX + widgetPosX + m_income.width - 2, posY + ((fontsize*1.15)*sizeMult) + (dead and 1 or 0), fontsize, "or")
    end
    font:End()
end

function DrawSidePic(team, playerID, posY, leader, dark, ai)
    gl_Color(1, 1, 1, 1)
    if gameStarted then
        if leader then
            gl_Texture(sidePics[team]) -- sets side image (for leaders)
        else
            gl_Texture(pics["notFirstPic"]) -- sets image for not leader of team players
        end
        DrawRect(m_side.posX + widgetPosX + (2*playerScale), posY + (1*playerScale), m_side.posX + widgetPosX + (16*playerScale), posY + (15*playerScale)) -- draws side image
        gl_Texture(false)
    else
        DrawState(playerID, m_side.posX + widgetPosX, posY)
    end
end

function DrawRank(rank, posY)
    if rank == 0 then
        DrawRankImage(pics["rank0"], posY)
    elseif rank == 1 then
        DrawRankImage(pics["rank1"], posY)
    elseif rank == 2 then
        DrawRankImage(pics["rank2"], posY)
    elseif rank == 3 then
        DrawRankImage(pics["rank3"], posY)
    elseif rank == 4 then
        DrawRankImage(pics["rank4"], posY)
    elseif rank == 5 then
        DrawRankImage(pics["rank5"], posY)
    elseif rank == 6 then
        DrawRankImage(pics["rank6"], posY)
    elseif rank == 7 then
        DrawRankImage(pics["rank7"], posY)
    else

    end
end

function DrawRankImage(rankImage, posY)
    gl_Color(1, 1, 1, 1)
    gl_Texture(rankImage)
    DrawRect(m_rank.posX + widgetPosX + (3*playerScale), posY + 8 - (7.5*playerScale), m_rank.posX + widgetPosX + (17*playerScale), posY + 8 + (7.5*playerScale))
end

local function RectQuad(px, py, sx, sy)
    local o = 0.008        -- texture offset, because else grey line might show at the edges
    gl.TexCoord(o, 1 - o)
    gl.Vertex(px, py, 0)
    gl.TexCoord(1 - o, 1 - o)
    gl.Vertex(sx, py, 0)
    gl.TexCoord(1 - o, o)
    gl.Vertex(sx, sy, 0)
    gl.TexCoord(o, o)
    gl.Vertex(px, sy, 0)
end

function DrawRect(px, py, sx, sy)
    gl.BeginEnd(GL.QUADS, RectQuad, px, py, sx, sy)
end

function DrawAlly(posY, team)
    gl_Color(1, 1, 1, 0.66)
    if Spring_AreTeamsAllied(team, myTeamID) then
        gl_Texture(pics["unallyPic"])
    else
        gl_Texture(pics["allyPic"])
    end
    DrawRect(m_alliance.posX + widgetPosX + (3*playerScale), posY + (1*playerScale), m_alliance.posX + widgetPosX + (playerOffset*playerScale), posY + (15*playerScale))
end

function DrawCountry(country, posY)
    if country ~= nil and country ~= "??" and VFS.FileExists(imgDir .. "flags/"  .. string.upper(country) .. flagsExt) then
        gl_Texture(imgDir .. "flags/" .. string.upper(country) .. flagsExt)
        gl_Color(1, 1, 1, 1)
        DrawRect(m_country.posX + widgetPosX + (3*playerScale), posY + 8 - ((flagHeight/2)*playerScale), m_country.posX + widgetPosX + (17*playerScale), posY + 8 + ((flagHeight/2)*playerScale))
    end
end

function DrawDot(posY)
    gl_Color(1, 1, 1, 0.70)
    gl_Texture(pics["currentPic"])
    DrawRect(m_indent.posX + widgetPosX - 1, posY + 3, m_indent.posX + widgetPosX + (7*playerScale), posY + 11)
end

function DrawCamera(posY, active)
    if active ~= nil and active then
        gl_Color(1, 1, 1, 0.7)
    else
        gl_Color(1, 1, 1, 0.13)
    end
    gl_Texture(pics["cameraPic"])
    DrawRect(m_indent.posX + widgetPosX - (1.5*playerScale), posY + (2*playerScale), m_indent.posX + widgetPosX + (9*playerScale), posY + (12.4*playerScale))
end

function colourNames(teamID)
    local nameColourR, nameColourG, nameColourB, nameColourA = Spring_GetTeamColor(teamID)
	if (not mySpecStatus) and anonymousMode ~= "disabled" and playerID ~= myPlayerID then
		nameColourR, nameColourG, nameColourB = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
	end
    local R255 = math.floor(nameColourR * 255)  --the first \255 is just a tag (not colour setting) no part can end with a zero due to engine limitation (C)
    local G255 = math.floor(nameColourG * 255)
    local B255 = math.floor(nameColourB * 255)
    if R255 % 10 == 0 then
        R255 = R255 + 1
    end
    if G255 % 10 == 0 then
        G255 = G255 + 1
    end
    if B255 % 10 == 0 then
        B255 = B255 + 1
    end
    return "\255" .. string.char(R255) .. string.char(G255) .. string.char(B255) --works thanks to zwzsg
end

function DrawState(playerID, posX, posY)
    -- note that adv pl list uses a phantom pID for absent players, so this will always show unready for players not ingame
    local ready = (playerReadyState[playerID] == 1) or (playerReadyState[playerID] == 2) or (playerReadyState[playerID] == -1)
    local hasStartPoint = (playerReadyState[playerID] == 4)
    if ai then
        gl_Color(0.1, 0.1, 0.97, 1)
    else
        if ready then
            gl_Color(0.1, 0.95, 0.2, 1)
        else
            if hasStartPoint then
                gl_Color(1, 0.65, 0.1, 1)
            else
                gl_Color(0.8, 0.1, 0.1, 1)
            end
        end
    end
    gl_Texture(pics["readyTexture"])
    DrawRect(posX, posY - (1*playerScale), posX + (16*playerScale), posY + (16*playerScale))
    gl_Color(1, 1, 1, 1)
end

function DrawAlliances(alliances, posY)
    -- still a problem is that teams with the same/similar color can be misleading
    local posX = widgetPosX + m_name.posX
    local width = m_name.width / #alliances
    local padding = 2
    local drawn = false
    for i, playerID in pairs(alliances) do
        if player[playerID] ~= nil and player[playerID].red ~= nil then
            gl_Color(0, 0, 0, 0.25)
            RectRound(posX + (width * (i - 1)), posY - (3*playerScale), posX + (width * i), posY + (19*playerScale), (2*playerScale))
            gl_Color(player[playerID].red, player[playerID].green, player[playerID].blue, 0.5)
            RectRound(posX + (width * (i - 1)) + padding, posY - (3*playerScale) + padding, posX + (width * i) - padding, posY + (19*playerScale) - padding, (2*playerScale))
            drawn = true
        end
    end
    if drawn then
        gl_Color(1, 1, 1, 1)
    end
end

function DrawName(name, team, posY, dark, playerID, desynced)
    local willSub = ""
    local ignored = WG.ignoredPlayers and WG.ignoredPlayers[name]

    local isAbsent = false
    if name == absentName then
        isAbsent = true
        local playerName = Spring.GetPlayerInfo(select(2,Spring.GetTeamInfo(team, false)), false)
        if playerName then --and aliveAllyTeams[player[playerID].allyteam] then
            name = player[playerID].name
        end
    end

    if not gameStarted then
        if playerID >= specOffset then
            willSub = (Spring.GetGameRulesParam("Player" .. (playerID - specOffset) .. "willSub") == 1) and " (sub)" or "" --pID-specOffset because apl uses dummy playerIDs for absent players
        else
            willSub = (Spring.GetGameRulesParam("Player" .. (playerID) .. "willSub") == 1) and " (sub)" or ""
        end
    end

    local nameText = name .. willSub
    local xPadding = 0

    -- includes readystate icon if factions arent shown
    if not gameStarted and not m_side.active then
        xPadding = 16
        DrawState(playerID, m_name.posX + widgetPosX, posY)
    end

    font2:Begin()
    local fontsize = isAbsent and 9 or 14
    fontsize = fontsize * (playerScale + ((1-playerScale)*0.4))
    if dark then
        font2:SetOutlineColor(0.8, 0.8, 0.8, math.max(0.8, 0.75 * widgetScale))
    else
        font2:SetTextColor(0, 0, 0, 0.4)
        font2:SetOutlineColor(0, 0, 0, 0.4)
        font2:Print(nameText, m_name.posX + widgetPosX + 2 + xPadding, posY + 3, fontsize, "n") -- draws name
        font2:Print(nameText, m_name.posX + widgetPosX + 4 + xPadding, posY + 3, fontsize, "n") -- draws name
        font2:SetOutlineColor(0, 0, 0, 1)
    end
    if (not mySpecStatus) and anonymousMode ~= "disabled" and playerID ~= myPlayerID then
        font2:SetTextColor(anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3], 1)
    else
        font2:SetTextColor(Spring_GetTeamColor(team))
    end
    if isAbsent then
        font2:SetOutlineColor(0, 0, 0, 0.4)
        font2:SetTextColor(0.45,0.45,0.45,1)
    end
    font2:Print(nameText, m_name.posX + widgetPosX + 3 + xPadding, posY + 4, fontsize, dark and "o" or "n")

    --desynced = playerID == 1
	if desynced then
		font2:SetTextColor(1,0.45,0.45,1)
		font2:Print(Spring.I18N('ui.playersList.desynced'), m_name.posX + widgetPosX + 5 + xPadding + (font2:GetTextWidth(nameText)*14), posY + 5.7 , 8, "o")
	elseif player[playerID] and not player[playerID].dead and player[playerID].incomeMultiplier and player[playerID].incomeMultiplier > 1 then
        font2:SetTextColor(0.5,1,0.5,1)
        font2:Print('+'..math.floor((player[playerID].incomeMultiplier-1)*100)..'%', m_name.posX + widgetPosX + 5 + xPadding + (font2:GetTextWidth(nameText)*14), posY + 5.7 , 8, "o")
    end
    font2:End()

    if ignored or desynced then
        local x = m_name.posX + widgetPosX + 2 + xPadding
        local y = posY + 7
        local w = font2:GetTextWidth(nameText) * 14 + 2
        local h = 2
		if desynced then
			gl_Color(1, 0.2, 0.2, 0.9)
		else
			gl_Color(1, 1, 1, 0.9)
		end
        gl_Texture(false)
        DrawRect(x, y, x + w, y + h)
        gl_Color(1, 1, 1, 1)
    end
end

function DrawSmallName(name, team, posY, dark, playerID, alpha)
    if team == nil then
        return
    end

    local ignored = WG.ignoredPlayers and WG.ignoredPlayers[name]

    local textindent = 4
    if m_indent.active or m_rank.active or m_side.active or m_ID.active then
        textindent = 0
    end

    if originalColourNames[playerID] then
        name = originalColourNames[playerID] .. name
    end

    font2:Begin()
    font2:SetOutlineColor(0, 0, 0, 0.3)
    font2:SetTextColor(1, 1, 1, alpha)
    font2:Print(name, m_name.posX + textindent + widgetPosX + 3, posY + (4*specScale), (10*specScale), "n")
    font2:End()

    if ignored then
        local x = m_name.posX + textindent + widgetPosX + 2.2
        local y = posY + (6*specScale)
        local w = font2:GetTextWidth(name) * 10 + 2
        local h = 2
        gl_Texture(false)
        gl_Color(1, 1, 1, 0.7)
        DrawRect(x, y, x + w, y + h)
        gl_Color(1, 1, 1, 1)
    end

end

function DrawID(playerID, posY, dark, dead)
    local spacer = ""
    if playerID < 10 then
        spacer = " "
    end
    local fontsize = 10
    fontsize = fontsize * (playerScale + ((1-playerScale)*0.25))
    local deadspace = 0
    font:Begin()
    if dead then
        font:SetTextColor(1, 1, 1, 0.4)
    else
        font:SetTextColor(1, 1, 1, 0.66)
    end
    font:Print(spacer .. playerID, m_ID.posX + deadspace + widgetPosX + 4.5, posY + 5, fontsize, "on")
    font:End()
end

function DrawSkill(skill, posY, dark)
    local fontsize = 9.5
    fontsize = fontsize * (playerScale + ((1-playerScale)*0.25))
    font:Begin()
    font:Print(skill, m_skill.posX + widgetPosX + m_skill.width - 2, posY + 5.3, fontsize, "or")
    font:End()
end

function DrawPingCpu(pingLvl, cpuLvl, posY, spec, alpha, cpu, fps)
    gl_Texture(pics["pingPic"])
    local grayvalue
    if spec then
        grayvalue = 0.5 + (pingLvl / 20)
        gl_Color(grayvalue, grayvalue, grayvalue, (0.2 * pingLvl))
        DrawRect(m_cpuping.posX + widgetPosX + (12*specScale), posY + (1*specScale), m_cpuping.posX + widgetPosX + (21*specScale), posY + (14*specScale))
    else
        gl_Color(pingLevelData[pingLvl].r, pingLevelData[pingLvl].g, pingLevelData[pingLvl].b)
        DrawRect(m_cpuping.posX + widgetPosX + (12*playerScale), posY + (1*playerScale), m_cpuping.posX + widgetPosX + (24*playerScale), posY + (15*playerScale))
    end

    grayvalue = 0.7 + (cpu / 135)

    -- display user fps
    font:Begin()
    if fps ~= nil then
        if fps > 99 then
            fps = 99
        end
        grayvalue = 0.95 - (math.min(fps, 99) / 400)
        if fps < 0 then
            fps = 0
            greyvalue = 1
        end
        if spec then
            font:SetTextColor(grayvalue, grayvalue, grayvalue, 0.87 * alpha * grayvalue)
            font:Print(fps, m_cpuping.posX + widgetPosX + (11*specScale), posY + (5.3*specScale), 9*specScale, "ro")
        else
            font:SetTextColor(grayvalue, grayvalue, grayvalue, alpha * grayvalue)
            font:Print(fps, m_cpuping.posX + widgetPosX + (11*playerScale), posY + (5.3*playerScale), 9.5*playerScale, "ro")
        end
    else
        gl_Texture(pics["cpuPic"])
        if spec then
            gl_Color(grayvalue, grayvalue, grayvalue, 0.1 + (0.14 * cpuLvl))
            DrawRect(m_cpuping.posX + widgetPosX + (2*specScale), posY + (1*specScale), m_cpuping.posX + widgetPosX + (13*specScale), posY + (14*specScale))
        else
            gl_Color(pingLevelData[cpuLvl].r, pingLevelData[cpuLvl].g, pingLevelData[cpuLvl].b)
            DrawRect(m_cpuping.posX + widgetPosX + (1*playerScale), posY + (1*playerScale), m_cpuping.posX + widgetPosX + (14*playerScale), posY + (15*playerScale))
        end
        gl_Color(1, 1, 1, 1)
    end
    font:End()
end

function DrawPoint(posY, pointtime)
    if right then
        gl_Color(1, 0, 0, pointtime / pointDuration)
        gl_Texture(pics["arrowPic"])
        DrawRect(widgetPosX - (18*playerScale), posY, widgetPosX - (2*playerScale), posY + (14*playerScale))
        gl_Color(1, 1, 1, pointtime / pointDuration)
        gl_Texture(pics["pointPic"])
        DrawRect(widgetPosX - (33*playerScale), posY - (1*playerScale), widgetPosX - (17*playerScale), posY + (15*playerScale))
    else
        leftPosX = widgetPosX + widgetWidth
        gl_Color(1, 0, 0, pointtime / pointDuration)
        gl_Texture(pics["arrowPic"])
        DrawRect(leftPosX + (18*playerScale), posY, leftPosX + (2*playerScale), posY + (14*playerScale))
        gl_Color(1, 1, 1, pointtime / pointDuration)
        gl_Texture(pics["pointPic"])
        DrawRect(leftPosX + (33*playerScale), posY - (1*playerScale), leftPosX + (17*playerScale), posY + (15*playerScale))
    end
    gl_Color(1, 1, 1, 1)
end

function TakeTip(mouseX)
    if right then
        if mouseX >= widgetPosX - 57 * widgetScale and mouseX <= widgetPosX - 1 * widgetScale then
            tipText = Spring.I18N('ui.playersList.takeUnits')
            tipTextTime = os.clock()
        end
    else
        local leftPosX = widgetPosX + widgetWidth
        if mouseX >= leftPosX + 1 * widgetScale and mouseX <= leftPosX + 57 * widgetScale then
            tipText = Spring.I18N('ui.playersList.takeUnits')
            tipTextTime = os.clock()
        end
    end
end

function ShareTip(mouseX, playerID)
    if playerID == myPlayerID then
        if mouseX >= widgetPosX + (m_share.posX + (1*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (17*playerScale)) * widgetScale then
            tipText = Spring.I18N('ui.playersList.requestSupport')
            tipTextTime = os.clock()
        elseif mouseX >= widgetPosX + (m_share.posX + (19*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (35*playerScale)) * widgetScale then
            tipText = Spring.I18N('ui.playersList.requestEnergy')
            tipTextTime = os.clock()
        elseif mouseX >= widgetPosX + (m_share.posX + (37*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (53*playerScale)) * widgetScale then
            tipText = Spring.I18N('ui.playersList.requestMetal')
            tipTextTime = os.clock()
        end
    else
        if mouseX >= widgetPosX + (m_share.posX + (1*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (17*playerScale)) * widgetScale then
            tipText = Spring.I18N('ui.playersList.shareUnits')
            tipTextTime = os.clock()
        elseif mouseX >= widgetPosX + (m_share.posX + (19*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (35*playerScale)) * widgetScale then
            tipText = Spring.I18N('ui.playersList.shareEnergy')
            tipTextTime = os.clock()
        elseif mouseX >= widgetPosX + (m_share.posX + (37*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (53*playerScale)) * widgetScale then
            tipText = Spring.I18N('ui.playersList.shareMetal')
            tipTextTime = os.clock()
        end
    end
end

function AllyTip(mouseX, playerID)
    if mouseX >= widgetPosX + (m_alliance.posX + (1*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_alliance.posX + (11*playerScale)) * widgetScale then
        if Spring_AreTeamsAllied(player[playerID].team, myTeamID) then
            tipText = Spring.I18N('ui.playersList.becomeEnemy')
            tipTextTime = os.clock()
        else
            tipText = Spring.I18N('ui.playersList.becomeAlly')
            tipTextTime = os.clock()
        end
    end
end

function ResourcesTip(mouseX, energy, energyStorage, energyIncome, metal, metalStorage, metalIncome)
    if mouseX >= widgetPosX + (m_resources.posX + 1) * widgetScale and mouseX <= widgetPosX + (m_resources.posX + m_resources.width) * widgetScale then
        if energy > 1000 then
            energy = math.floor(energy / 100) * 100
        else
            energy = math.floor(energy / 10) * 10
        end
        if metal > 1000 then
            metal = math.floor(metal / 100) * 100
        else
            metal = math.floor(metal / 10) * 10
        end
        if energyIncome == nil then
            energyIncome = 0
            metalIncome = 0
        end
        energyIncome = math.floor(energyIncome)
        metalIncome = math.floor(metalIncome)
        if energyIncome > 1000 then
            energyIncome = math.floor(energyIncome / 100) * 100
        elseif energyIncome > 100 then
            energyIncome = math.floor(energyIncome / 10) * 10
        end
        if metalIncome > 200 then
            metalIncome = math.floor(metalIncome / 10) * 10
        end
        if energy >= 10000 then
            energy =  Spring.I18N('ui.playersList.thousands', { number = math.floor(energy / 1000) })
        end
        if metal >= 10000 then
            metal = Spring.I18N('ui.playersList.thousands', { number = math.floor(metal / 1000) })
        end
        if energyIncome >= 10000 then
            energyIncome = Spring.I18N('ui.playersList.thousands', { number = math.floor(energyIncome / 1000) })
        end
        if metalIncome >= 10000 then
            metalIncome = Spring.I18N('ui.playersList.thousands', { number = math.floor(metalIncome / 1000) })
        end
        tipText = "\255\255\255\255+" .. metalIncome.. "\n\255\255\255\255" .. metal .. "\n\255\255\255\000" .. energy .. "\n\255\255\255\000+" .. energyIncome
        tipTextTime = os.clock()
    end
end

function IncomeTip(mouseX, energyIncome, metalIncome)
    if mouseX >= widgetPosX + (m_income.posX + (1*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_income.posX + m_resources.width) * widgetScale then
        if energyIncome == nil then
            energyIncome = 0
            metalIncome = 0
        end
        energyIncome = math.floor(energyIncome)
        metalIncome = math.floor(metalIncome)
        if energyIncome > 1000 then
            energyIncome = math.floor(energyIncome / 100) * 100
        elseif energyIncome > 100 then
            energyIncome = math.floor(energyIncome / 10) * 10
        end
        if metalIncome > 200 then
            metalIncome = math.floor(metalIncome / 10) * 10
        end
        if energyIncome >= 10000 then
            energyIncome = Spring.I18N('ui.playersList.thousands', { number = math.floor(energyIncome / 1000) })
        end
        if metalIncome >= 10000 then
            metalIncome = Spring.I18N('ui.playersList.thousands', { number = math.floor(metalIncome / 1000) })
        end
        tipText = Spring.I18N('ui.playersList.resincome') .. "\n\255\255\255\000+" .. energyIncome .. "\n\255\255\255\255+" .. metalIncome
        tipTextTime = os.clock()
    end
end

function PingCpuTip(mouseX, pingLvl, cpuLvl, fps, gpumem, system, name, teamID, spec)
    if mouseX >= widgetPosX + (m_cpuping.posX + (13*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_cpuping.posX + (23*playerScale)) * widgetScale then
        if pingLvl < 2000 then
            pingLvl = Spring.I18N('ui.playersList.milliseconds', { number = pingLvl })
        elseif pingLvl >= 2000 then
            pingLvl = Spring.I18N('ui.playersList.seconds', { number = round(pingLvl / 1000, 0) })
        end
        tipText = Spring.I18N('ui.playersList.commandDelay', { labelColor = "\255\190\190\190", delayColor = "\255\255\255\255", delay = pingLvl })
        tipTextTime = os.clock()
    elseif mouseX >= widgetPosX + (m_cpuping.posX + (1*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_cpuping.posX + (11*playerScale)) * widgetScale then
        tipText = Spring.I18N('ui.playersList.cpu', { cpuUsage = cpuLvl })
        if fps ~= nil then
            tipText = Spring.I18N('ui.playersList.framerate', { fps = fps }) .. "    " .. tipText
        end
        if gpumem ~= nil then
            tipText = tipText .. "    " .. Spring.I18N('ui.playersList.gpuMemory', { gpuUsage = gpumem })
        end
        if system ~= nil then
            tipText = (spec and "\255\240\240\240" or colourNames(teamID)) .. name .. "\n\255\215\255\215" .. tipText .. "\n\255\240\240\240" .. system
        end
        tipTextTime = os.clock()
    end
end

function PointTip(mouseX)
    if right then
        if mouseX >= widgetPosX - 28 * widgetScale and mouseX <= widgetPosX - 1 * widgetScale then
            tipText = Spring.I18N('ui.playersList.pointClickTooltip')
            tipTextTime = os.clock()
        end
    else
        local leftPosX = widgetPosX + widgetWidth
        if mouseX >= leftPosX + 1 * widgetScale and mouseX <= leftPosX + 28 * widgetScale then
            tipText = Spring.I18N('ui.playersList.pointClickTooltip')
            tipTextTime = os.clock()
        end
    end
end

---------------------------------------------------------------------------------------------------
--  Share slider gllist
---------------------------------------------------------------------------------------------------

function CreateShareSlider()
    if ShareSlider then
        gl_DeleteList(ShareSlider)
    end

    ShareSlider = gl_CreateList(function()
        if sliderPosition then
            font:Begin()
            local posY
            if energyPlayer ~= nil then
                posY = widgetPosY + widgetHeight - energyPlayer.posY
                gl_Texture(pics["barPic"])
                DrawRect(m_share.posX + widgetPosX + (16*playerScale), posY - (3*playerScale), m_share.posX + widgetPosX + (34*playerScale), posY + shareSliderHeight + (18*playerScale))
                gl_Texture(pics["energyPic"])
                DrawRect(m_share.posX + widgetPosX + (17*playerScale), posY + sliderPosition, m_share.posX + widgetPosX + (33*playerScale), posY + (16*playerScale) + sliderPosition)
                gl_Texture(pics["amountPic"])
                if right then
                    DrawRect(m_share.posX + widgetPosX - (28*playerScale), posY - 1 + sliderPosition, m_share.posX + widgetPosX + (19*playerScale), posY + (17*playerScale) + sliderPosition)
                    gl_Texture(false)
                    font:Print(shareAmount, m_share.posX + widgetPosX - (5*playerScale), posY + (3*playerScale) + sliderPosition, 14, "ocn")
                else
                    DrawRect(m_share.posX + widgetPosX + (76*playerScale), posY - 1 + sliderPosition, m_share.posX + widgetPosX + (31*playerScale), posY + (17*playerScale) + sliderPosition)
                    gl_Texture(false)
                    font:Print(shareAmount, m_share.posX + widgetPosX + (55*playerScale), posY + (3*playerScale) + sliderPosition, 14, "ocn")
                end
            elseif metalPlayer ~= nil then
                posY = widgetPosY + widgetHeight - metalPlayer.posY
                gl_Texture(pics["barPic"])
                DrawRect(m_share.posX + widgetPosX + (32*playerScale), posY - 3, m_share.posX + widgetPosX + (50*playerScale), posY + shareSliderHeight + (18*playerScale))
                gl_Texture(pics["metalPic"])
                DrawRect(m_share.posX + widgetPosX + (33*playerScale), posY + sliderPosition, m_share.posX + widgetPosX + (49*playerScale), posY + (16*playerScale) + sliderPosition)
                gl_Texture(pics["amountPic"])
                if right then
                    DrawRect(m_share.posX + widgetPosX - (12*playerScale), posY - 1 + sliderPosition, m_share.posX + widgetPosX + (35*playerScale), posY + (17*playerScale) + sliderPosition)
                    gl_Texture(false)
                    font:Print(shareAmount, m_share.posX + widgetPosX + (11*playerScale), posY + (3*playerScale) + sliderPosition, 14, "ocn")
                else
                    DrawRect(m_share.posX + widgetPosX + (88*playerScale), posY - 1 + sliderPosition, m_share.posX + widgetPosX + (47*playerScale), posY + (17*playerScale) + sliderPosition)
                    gl_Texture(false)
                    font:Print(shareAmount, m_share.posX + widgetPosX + (71*playerScale), posY + (3*playerScale) + sliderPosition, 14, "ocn")
                end
            end
            font:End()
        end
    end)
end

function GetCpuLvl(cpuUsage)
    for level, data in ipairs(pingLevelData) do
        if cpuUsage < data.cpuThreshold then
            return level
        end
    end
end

function GetPingLvl(ping)
    for level, data in ipairs(pingLevelData) do
        if ping < data.pingThreshold then
            return level
        end
    end
end

---------------------------------------------------------------------------------------------------
--  Mouse
---------------------------------------------------------------------------------------------------

function widget:MousePress(x, y, button)
    --super ugly code here
    local t = false       -- true if the object is a team leader
    local clickedPlayer
    local posY
    local clickTime = os.clock()

    if IsOnRect(x, y, apiAbsPosition[2], apiAbsPosition[3], apiAbsPosition[4], apiAbsPosition[1]) then
        forceMainListRefresh = true
    end

    if button == 1 then
        local alt, ctrl, meta, shift = Spring.GetModKeyState()
        sliderPosition = 0
        shareAmount = 0

        -- spectators label onclick
        posY = widgetPosY + widgetHeight - specsLabelOffset
        if numberOfSpecs > 0 and IsOnRect(x, y, widgetPosX + 2, posY + 2, widgetPosX + widgetWidth - 2, posY + 20) then
            specListShow = not specListShow
            SetModulesPositionX() --why?
            SortList()
            CreateLists()
            return true
        end

        -- enemies label onclick
        posY = widgetPosY + widgetHeight - enemyLabelOffset
        if numberOfEnemies > 0 and IsOnRect(x, y, widgetPosX + 2, posY + 2, widgetPosX + widgetWidth - 2, posY + 20) then
            enemyListShow = not enemyListShow
            SetModulesPositionX() --why?
            SortList()
            CreateLists()
            return true
        end

        for _, i in ipairs(drawList) do
            -- i = object #
            if i > -1 then
                clickedPlayer = player[i]
                clickedPlayer.id = i
                posY = widgetPosY + widgetHeight - (clickedPlayer.posY or 0)
            end

            if mySpecStatus then
                if i == -1 then
                    t = true
                else
                    t = false
                    if m_point.active then
                        if i > -1 and i < specOffset then
                            if clickedPlayer.pointTime ~= nil then
                                if right then
                                    if IsOnRect(x, y, widgetPosX - 33, posY - 2, widgetPosX - 17, posY + (playerOffset*playerScale)) then
                                        --point button
                                        Spring.SetCameraTarget(clickedPlayer.pointX, clickedPlayer.pointY, clickedPlayer.pointZ, 1)
                                        return true
                                    end
                                else
                                    if IsOnRect(x, y, widgetPosX + widgetWidth + 17, posY - 2, widgetPosX + widgetWidth + 33, posY + (playerOffset*playerScale)) then
                                        Spring.SetCameraTarget(clickedPlayer.pointX, clickedPlayer.pointY, clickedPlayer.pointZ, 1)
                                        return true
                                    end
                                end
                            end
                        end
                    end
                end
                if i > -1 then -- and i < specOffset
                    if m_name.active and clickedPlayer.name ~= absentName and IsOnRect(x, y, m_name.posX + widgetPosX + 1, posY, m_name.posX + widgetPosX + m_name.width, posY + (playerOffset*playerScale)) then
                        if ctrl and i < specOffset then
                            Spring_SendCommands("toggleignore " .. clickedPlayer.name)
                            return true
                        elseif not player[i].spec then
                            if i ~= myTeamPlayerID then
                                local curMapDrawMode = Spring.GetMapDrawMode()
                                Spring_SendCommands("specteam " .. player[i].team)
                                if lockPlayerID then
                                    LockCamera(player[i].ai and nil or i)
                                else
                                    if not fullView then
                                        desiredLosmode = 'los'
                                        desiredLosmodeChanged = os.clock()
                                        if Spring.GetMapDrawMode() ~= 'los' then
                                            Spring.SendCommands("togglelos")
                                        end
                                    end
                                end
                                CreateMainList()
                                return true
                            end
                        end

                        if i < specOffset and (mySpecStatus or player[i].allyteam == myAllyTeamID) and clickTime - prevClickTime < dblclickPeriod and clickedPlayer == prevClickedPlayer then
                            LockCamera(i)
                            prevClickedPlayer = {}
                            SortList()
                            CreateLists()
                            return true
                        end
                        prevClickedPlayer = clickedPlayer
                    end
                end

            else
                if t then
                    if clickedPlayer.allyteam == myAllyTeamID then
                        if m_take.active then
                            if clickedPlayer.totake then
                                if right then
                                    if IsOnRect(x, y, widgetPosX - 57, posY, widgetPosX - 12, posY + 17) then
                                        --take button
                                        Take(clickedPlayer.team, clickedPlayer.name, i)
                                        return true
                                    end
                                else
                                    if IsOnRect(x, y, widgetPosX + widgetWidth + 12, posY, widgetPosX + widgetWidth + 57, posY + 17) then
                                        Take(clickedPlayer.team, clickedPlayer.name, i)
                                        return true
                                    end
                                end
                            end
                        end
                        if m_share.active and clickedPlayer.dead ~= true and not hideShareIcons then
                            if IsOnRect(x, y, m_share.posX + widgetPosX + 1, posY, m_share.posX + widgetPosX + 17, posY + (playerOffset*playerScale)) then
                                -- share units button
                                if release ~= nil then
                                    if release >= now then
                                        if clickedPlayer.team == myTeamID then
                                            Spring_SendCommands("say a: " .. Spring.I18N('ui.playersList.chat.needSupport'))
                                        else
                                            local unitsCount = Spring.GetSelectedUnitsCount()
                                            Spring_SendCommands("say a: " .. Spring.I18N('ui.playersList.chat.giveUnits', { count = unitsCount, name = clickedPlayer.name }))
                                            local selectedUnits = Spring.GetSelectedUnits()
                                            for i = 1, #selectedUnits do
                                                local ux, uy, uz = Spring.GetUnitPosition(selectedUnits[i])
                                                Spring.MarkerAddPoint(ux, uy, uz)
                                            end
                                            Spring_ShareResources(clickedPlayer.team, "units")
                                        end
                                    end
                                    release = nil
                                else
                                    firstclick = now + 1
                                end
                                return true
                            end
                            if IsOnRect(x, y, m_share.posX + widgetPosX + 17, posY, m_share.posX + widgetPosX + 33, posY + (playerOffset*playerScale)) then
                                -- share energy button (initiates the slider)
                                energyPlayer = clickedPlayer
                                return true
                            end
                            if IsOnRect(x, y, m_share.posX + widgetPosX + 33, posY, m_share.posX + widgetPosX + 49, posY + (playerOffset*playerScale)) then
                                -- share metal button (initiates the slider)
                                metalPlayer = clickedPlayer
                                return true
                            end
                        end
                    end
                end
                if i == -1 then
                    t = true
                else
                    t = false
                    if i > -1 and i < specOffset then
                        --chat button
                        if m_chat.active then
                            if IsOnRect(x, y, m_chat.posX + widgetPosX + 1, posY, m_chat.posX + widgetPosX + 17, posY + (playerOffset*playerScale)) then
                                Spring_SendCommands("chatall", "pastetext /w " .. clickedPlayer.name .. ' \1')
                                return true
                            end
                        end
                        --ally button
                        if m_alliance.active and drawAllyButton and not mySpecStatus and player[i] ~= nil and player[i].dead ~= true and i ~= myPlayerID then
                            if IsOnRect(x, y, m_alliance.posX + widgetPosX + 1, posY, m_alliance.posX + widgetPosX + m_alliance.width, posY + (playerOffset*playerScale)) then
                                if Spring_AreTeamsAllied(player[i].team, myTeamID) then
                                    Spring_SendCommands("ally " .. player[i].allyteam .. " 0")
                                else
                                    Spring_SendCommands("ally " .. player[i].allyteam .. " 1")
                                end
                                return true
                            end
                        end
                        --point
                        if m_point.active then
                            if clickedPlayer.pointTime ~= nil then
                                if clickedPlayer.allyteam == myAllyTeamID then
                                    if right then
                                        if IsOnRect(x, y, widgetPosX - 28, posY - 1, widgetPosX - 12, posY + 17) then
                                            Spring.SetCameraTarget(clickedPlayer.pointX, clickedPlayer.pointY, clickedPlayer.pointZ, 1)
                                            return true
                                        end
                                    else
                                        if IsOnRect(x, y, widgetPosX + widgetWidth + 12, posY - 1, widgetPosX + widgetWidth + 28, posY + 17) then
                                            Spring.SetCameraTarget(clickedPlayer.pointX, clickedPlayer.pointY, clickedPlayer.pointZ, 1)
                                            return true
                                        end
                                    end
                                end
                            end
                        end
                        --name
                        if m_name.active and clickedPlayer.name ~= absentName and IsOnRect(x, y, m_name.posX + widgetPosX + 1, posY, m_name.posX + widgetPosX + m_name.width, posY + 12) then
                            if ctrl then
                                Spring_SendCommands("toggleignore " .. clickedPlayer.name)
                                SortList()
                                CreateLists()
                                return true
                            end
                            if (mySpecStatus or player[i].allyteam == myAllyTeamID) and clickTime - prevClickTime < dblclickPeriod and clickedPlayer == prevClickedPlayer then
                                LockCamera(clickedPlayer.team)
                                prevClickedPlayer = {}
                                SortList()
                                CreateLists()
                                return true
                            end
                            prevClickedPlayer = clickedPlayer
                        end
                    end
                end
            end
        end
    end
    prevClickTime = clickTime
    if hoverPlayerlist then
        return true
    end
end

function widget:MouseMove(x, y, dx, dy, button)
    if energyPlayer ~= nil or metalPlayer ~= nil then
        -- move energy/metal share slider
        if sliderOrigin == nil then
            sliderOrigin = y
        end
        sliderPosition = (y - sliderOrigin) * (1 / widgetScale)
        if sliderPosition < 0 then
            sliderPosition = 0
        end
        if sliderPosition > shareSliderHeight then
            sliderPosition = shareSliderHeight
        end
        local prevAmountEM = shareAmount
        UpdateResources()
        if playSounds and (lastSliderSound == nil or os.clock() - lastSliderSound > 0.05) and shareAmount ~= prevAmountEM then
            lastSliderSound = os.clock()
            Spring.PlaySoundFile(sliderdrag, 0.3, 'ui')
        end
    end
end

function widget:MouseRelease(x, y, button)
    if button == 1 then
        if firstclick ~= nil then
            -- double click system for share units
            release = firstclick
            firstclick = nil
        else
            release = nil
        end
        if energyPlayer ~= nil then
            -- share energy/metal mouse release
            if energyPlayer.team == myTeamID then
                if shareAmount == 0 then
                    Spring_SendCommands("say a:" .. Spring.I18N('ui.playersList.chat.needEnergy'))
                else
                    Spring_SendCommands("say a:" .. Spring.I18N('ui.playersList.chat.needEnergyAmount', { amount = shareAmount }))
                end
            elseif shareAmount > 0 then
                Spring_ShareResources(energyPlayer.team, "energy", shareAmount)
                Spring_SendCommands("say a:" .. Spring.I18N('ui.playersList.chat.giveEnergy', { amount = shareAmount, name = energyPlayer.name }))
                WG.sharedEnergyFrame = Spring.GetGameFrame()
            end
            sliderOrigin = nil
            maxShareAmount = nil
            sliderPosition = nil
            shareAmount = nil
            energyPlayer = nil
        end

        if metalPlayer ~= nil and shareAmount then
            if metalPlayer.team == myTeamID then
                if shareAmount == 0 then
                    Spring_SendCommands("say a:" .. Spring.I18N('ui.playersList.chat.needMetal'))
                else
                    Spring_SendCommands("say a:" .. Spring.I18N('ui.playersList.chat.needMetalAmount', { amount = shareAmount }))
                end
            elseif shareAmount > 0 then
                Spring_ShareResources(metalPlayer.team, "metal", shareAmount)
                Spring_SendCommands("say a:" .. Spring.I18N('ui.playersList.chat.giveMetal', { amount = shareAmount, name = metalPlayer.name }))
                WG.sharedMetalFrame = Spring.GetGameFrame()
            end
            sliderOrigin = nil
            maxShareAmount = nil
            sliderPosition = nil
            shareAmount = nil
            metalPlayer = nil
        end
    end
end

function Spec(teamID)
    Spring_SendCommands("specteam " .. teamID)
    SortList()
end

function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
    -- calc scale offset
    BLcornerX = BLcornerX - ((widgetPosX - BLcornerX) * (widgetScale - 1))
    BLcornerY = BLcornerY - ((widgetPosY - BLcornerY) * (widgetScale - 1))
    TRcornerX = TRcornerX - ((widgetPosX - TRcornerX) * (widgetScale - 1))
    TRcornerY = TRcornerY - ((widgetPosY - TRcornerY) * (widgetScale - 1))

    return x >= BLcornerX and x <= TRcornerX
            and y >= BLcornerY
            and y <= TRcornerY
end

---------------------------------------------------------------------------------------------------
--  Save/load
---------------------------------------------------------------------------------------------------

local version = 1
function widget:GetConfigData()
    -- save
    if m_name ~= nil then
        local m_active_Table = {}
        for n, module in pairs(modules) do
            m_active_Table[module.name] = module.active
        end

        local settings = {
            --view
            customScale = customScale,
            vsx = vsx,
            vsy = vsy,
            widgetRelRight = widgetRelRight,
            widgetPosX = widgetPosX,
            widgetPosY = widgetPosY,
            widgetRight = widgetRight,
            widgetTop = widgetTop,
            expandDown = expandDown,
            expandLeft = expandLeft,
            m_pointActive = m_point.active,
            m_takeActive = m_take.active,
            m_active_Table = m_active_Table,
            lockPlayerID = lockPlayerID,
            specListShow = specListShow,
            enemyListShow = enemyListShow,
            gameFrame = Spring.GetGameFrame(),
            lastSystemData = lastSystemData,
            alwaysHideSpecs = alwaysHideSpecs,
            transitionTime = transitionTime,
            lockcameraHideEnemies = lockcameraHideEnemies,
            lockcameraLos = lockcameraLos,
            hasresetskill = true,
            absoluteResbarValues = absoluteResbarValues,
            originalColourNames = originalColourNames,
			version = version,
        }

        return settings
    end
end

function widget:SetConfigData(data)
    if data.customScale ~= nil then
        customScale = data.customScale
    end

    if data.specListShow ~= nil then
        specListShow = data.specListShow
    end

    if data.absoluteResbarValues ~= nil then
        absoluteResbarValues = data.absoluteResbarValues
    end

    if data.enemyListShow ~= nil then
        enemyListShow = data.enemyListShow
    end

    if data.version ~= nil and data.alwaysHideSpecs ~= nil then
        alwaysHideSpecs = data.alwaysHideSpecs
    end

    if data.lockcameraHideEnemies ~= nil then
        lockcameraHideEnemies = data.lockcameraHideEnemies
    end

    if data.lockcameraLos ~= nil then
        lockcameraLos = data.lockcameraLos
    end

    if data.lockcameraLos ~= nil then
        transitionTime = data.transitionTime
    end

    --view
    if data.expandDown ~= nil and data.widgetRight ~= nil then
        expandDown = data.expandDown
        expandLeft = data.expandLeft
        local oldvsx = data.vsx
        local oldvsy = data.vsy
        if oldvsx == nil then
            oldvsx = vsx
            oldvsy = vsy
        end
        local dy = vsy - oldvsy
        if expandDown then
            widgetTop = data.widgetTop + dy
            if widgetTop > vsy then
                widgetTop = vsy
            end
        else
            widgetPosY = data.widgetPosY
        end
        if expandLeft then
            widgetRelRight = data.widgetRelRight or 0
            widgetRight = vsx - (widgetWidth * (widgetScale - 1)) - widgetRelRight --align right of widget to right of screen
            widgetPosX = widgetRight - (widgetWidth * widgetScale)
            if widgetRight > vsx then
                widgetRight = vsx
            end
        else
            widgetPosX = data.widgetPosX --align left of widget to left of screen
        end
    end

    if Spring.GetGameFrame() > 0 then
        if data.originalColourNames then
            originalColourNames = data.originalColourNames
        end

        if data.lockPlayerID ~= nil then
            lockPlayerID = data.lockPlayerID
            if lockPlayerID and not select(3, Spring_GetPlayerInfo(lockPlayerID), false) then
                if not lockcameraHideEnemies then
                    if not fullView then
                        Spring.SendCommands("specfullview")
                        if lockcameraLos and mySpecStatus and Spring.GetMapDrawMode() == "los" then
                            desiredLosmode = 'normal'
                            desiredLosmodeChanged = os.clock()
                        end
                    end
                else
                    if fullView then
                        Spring.SendCommands("specfullview")
                        if lockcameraLos and mySpecStatus then
                            desiredLosmode = 'los'
                            desiredLosmodeChanged = os.clock()
                        end
                    end
                end
            end
        end
    end

    --not technically modules
    m_point.active = true -- m_point.default doesnt work
    if data.m_pointActive ~= nil then
        m_point.active = data.m_pointActive
    end
    m_take.active = true -- m_take.default doesnt work
    if data.m_takeActive ~= nil then
        m_take.active = data.m_takeActive
    end

    local m_active_Table = data.m_active_Table or {}
    for name, active in pairs(m_active_Table) do
        for _, module in pairs(modules) do
            if module.name == name then
                if name == "ally" then
                    -- needs to be always active (some aready stored it as false before, this makes sure its corrected)
                    module.active = true
                else
                    module.active = module.default
                    if active ~= nil then
                        module.active = active
                    end
                end
            end
        end
    end

    if not data.hasresetskill then
        m_skill.active = false
    end

    SetModulesPositionX()

    if data.lastSystemData ~= nil and data.gameFrame ~= nil and data.gameFrame <= Spring.GetGameFrame() and data.gameFrame > Spring.GetGameFrame() - 300 then
        lastSystemData = data.lastSystemData
    end
end

---------------------------------------------------------------------------------------------------
--  Player related changes
---------------------------------------------------------------------------------------------------

function CheckPlayersChange()
    local sorting = false
    for i = 0, specOffset-1 do
        local name, active, spec, teamID, allyTeamID, pingTime, cpuUsage, country, rank, _, _, desynced = Spring_GetPlayerInfo(i, false)
        if active == false then
            if player[i].name ~= nil then
                -- NON SPEC PLAYER LEAVING
                if player[i].spec == false then
                    if table.maxn(Spring_GetPlayerList(player[i].team, true)) == 0 then
                        player[player[i].team + specOffset] = CreatePlayerFromTeam(player[i].team)
                        sorting = true
                    end
                end
                player[i].name = nil
                player[i] = {}
                sorting = true
            end
        elseif active and name ~= nil then
            if spec ~= player[i].spec then
                -- PLAYER SWITCHING TO SPEC STATUS
                if spec then
                    if table.maxn(Spring_GetPlayerList(player[i].team, true)) == 0 then
                        -- (update the no players team)
                        player[player[i].team + specOffset] = CreatePlayerFromTeam(player[i].team)
                    end
                    player[i].team = nil -- remove team
                end
                player[i].spec = spec -- consider player as spec
                sorting = true
            end
            if teamID ~= player[i].team then
                -- PLAYER CHANGING TEAM
                if table.maxn(Spring_GetPlayerList(player[i].team, true)) == 0 then
                    -- check if there is no more player in the team + update
                    player[player[i].team + specOffset] = CreatePlayerFromTeam(player[i].team)
                end
                player[i].team = teamID
				if (not mySpecStatus) and anonymousMode ~= "disabled" and playerID ~= myPlayerID then
					player[i].red, player[i].green, player[i].blue = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
				else
					player[i].red, player[i].green, player[i].blue = Spring_GetTeamColor(teamID)
				end
                player[i].dark = GetDark(player[i].red, player[i].green, player[i].blue)
                player[i].skill = GetSkill(i)
                sorting = true
            end
            if player[i].name == nil then
                player[i] = CreatePlayer(i)
            end
            if allyTeamID ~= player[i].allyteam then
                player[i].allyteam = allyTeamID
                updateTake(allyTeamID)
                sorting = true
            end

            -- Update stall / cpu / ping info for each player
            if player[i].spec == false then
                player[i].needm = GetNeed("metal", player[i].team)
                player[i].neede = GetNeed("energy", player[i].team)
                player[i].rank = rank
            else
                player[i].needm = false
                player[i].neede = false
            end

            player[i].pingLvl = GetPingLvl(pingTime)
            player[i].cpuLvl = GetCpuLvl(cpuUsage)
            player[i].ping = pingTime * 1000 - ((pingTime * 1000) % 1)
            player[i].cpu = cpuUsage * 100 - ((cpuUsage * 100) % 1)
			player[i].desynced = desynced
        end

        if teamID and Spring_GetGameFrame() > 0 then
            local totake = IsTakeable(teamID)
            player[i].totake = totake
            if totake then
                sorting = true
            else
                player[i].name = name
            end
        end
    end

    if sorting then
        -- sorts the list again if change needs it
        SortList()
        SetModulesPositionX()    -- change the X size if needed (change of widest name)
    end

end

function GetNeed(resType, teamID)
    local current, _, pull, income = Spring_GetTeamResources(teamID, resType)
    if current == nil then
        return false
    end
    local loss = pull - income
    if loss > 0 then
        if loss * 5 > current then
            return true
        end
    end
    return false
end

function updateTake(allyTeamID)
    for i = 0, teamN - 1 do
        if player[i + specOffset].allyTeam == allyTeamID then
            player[i + specOffset] = CreatePlayerFromTeam(i)
        end
    end
end

function Take(teamID, name, i)
    reportTake = true
    tookTeamID = teamID
    tookTeamName = name
    tookFrame = Spring.GetGameFrame()

    Spring_SendCommands("luarules take2 " .. teamID)
end

function widget:TeamDied(teamID)
    player[teamID + specOffset] = CreatePlayerFromTeam(teamID)
    SortList()
end

---------------------------------------------------------------------------------------------------
--  Take related stuff
---------------------------------------------------------------------------------------------------

function IsTakeable(teamID)
    if Spring_GetTeamRulesParam(teamID, "numActivePlayers") == 0 then
        local units = Spring_GetTeamUnitCount(teamID)
        local energy = Spring_GetTeamResources(teamID, "energy")
        local metal = Spring_GetTeamResources(teamID, "metal")
        if units and energy and metal then
            if units > 0 or energy > 1000 or metal > 100 then
                return true
            end
        end
    else
        return false
    end
end


function widget:Update(delta)
    --handles takes & related messages
    local mx, my = Spring.GetMouseState()
    hoverPlayerlist = false
    if math_isInRect(mx, my, apiAbsPosition[2] - 1, apiAbsPosition[3] - 1, apiAbsPosition[4] + 1, apiAbsPosition[1] + 1 ) then
        hoverPlayerlist = true
        if tipText and WG['tooltip'] then
            WG['tooltip'].ShowTooltip('advplayerlist', tipText)
        end
        Spring.SetMouseCursor('cursornormal')
    end

    totalTime = totalTime + delta
    timeCounter = timeCounter + delta
    timeFastCounter = timeFastCounter + delta
    curFrame = Spring_GetGameFrame()
    mySpecStatus, fullView, _ = Spring.GetSpectatingState()

    if scheduledSpecFullView ~= nil then
        -- this is needed else the minimap/world doesnt update properly
        Spring.SendCommands("specfullview")
        scheduledSpecFullView = scheduledSpecFullView - 1
        if scheduledSpecFullView == 0 then
            scheduledSpecFullView = nil
        end
    end

    if desiredLosmode and desiredLosmodeChanged + 0.9 > os.clock() then
        if (desiredLosmode == "los" and Spring.GetMapDrawMode() == "normal") or (desiredLosmode == "normal" and Spring.GetMapDrawMode() == "los") then
            -- this is needed else the minimap/world doesnt update properly
            Spring.SendCommands("togglelos")
        end
        if desiredLosmodeChanged + 2 < os.clock() then
            desiredLosmode = nil
        end
    end

    if lockPlayerID ~= nil then
        Spring.SetCameraState(Spring.GetCameraState(), transitionTime)
    end

    if energyPlayer ~= nil or metalPlayer ~= nil then
        CreateShareSlider()
    end

    if curFrame >= 30 + tookFrame then
        if lastTakeMsg + 120 < tookFrame and reportTake then
            local teamID = tookTeamID
            local afterE = Spring_GetTeamResources(teamID, "energy")
            local afterM = Spring_GetTeamResources(teamID, "metal")
            local afterU = Spring_GetTeamUnitCount(teamID)
            local toSay = "say a:" .. Spring.I18N('ui.playersList.chat.takeTeam', { name = tookTeamName })

            if afterE and afterM and afterU then
                if afterE > 1.0 or afterM > 1.0 or afterU > 0 then
                    toSay = "say a:" .. Spring.I18N('ui.playersList.chat.takeTeamAmount', { name = tookTeamName, units = math.floor(afterU), energy = math.floor(afterE), metal = math.floor(afterM) })
                end
            end

            Spring_SendCommands(toSay)

            for j = 0, (specOffset*2)-1 do
                if player[j].allyteam == myAllyTeamID then
                    if player[j].totake then
                        player[j] = CreatePlayerFromTeam(player[j].team)
                        SortList()
                    end
                end
            end

            lastTakeMsg = tookFrame
            reportTake = false
        else
            reportTake = false
        end
    end
    if curFrame <= 0 and timeCounter > updateRate then
        SetSidePics() -- if the game hasn't started, update factions
    elseif curFrame > 15 and not gameStartRefreshed then
        gameStartRefreshed = true
        forceMainListRefresh = true
    end
    if forceMainListRefresh then
        CreateLists()
    else
        local updateMainList2 = timeCounter > updateRate
        local updateMainList3 = ((m_resources.active or m_income.active) and timeFastCounter > updateFastRate)
        if updateMainList2 or updateMainList3 then
            CreateLists(curFrame==0, updateMainList2, updateMainList3)
        end
    end
end

---------------------------------------------------------------------------------------------------
--  Other callins
---------------------------------------------------------------------------------------------------

function updateWidgetScale()
    if customScale < 0.65 then
        customScale = 0.65
    end
    local prevWidgetScale = widgetScale
    widgetScale = (vsy / 980) * (1 + ((vsx / vsy) * 0.065)) * customScale
    widgetScale = widgetScale * (1 + (Spring.GetConfigFloat("ui_scale", 1) - 1) / 1.25)
    if prevWidgetScale ~= widgetScale then
        prevWidgetScale = widgetScale
        forceMainListRefresh = true
    end
    widgetPosX = vsx - (widgetWidth * widgetScale) - bgpadding
    widgetRight = vsx - bgpadding
    widgetPosY = bgpadding
    widgetTop = widgetPosY + widgetHeight + bgpadding
end

function widget:ViewResize()
    vsx, vsy = Spring.GetViewGeometry()

    bgpadding = WG.FlowUI.elementPadding
    elementCorner = WG.FlowUI.elementCorner

    RectRound = WG.FlowUI.Draw.RectRound
    UiElement = WG.FlowUI.Draw.Element
    UiSelectHighlight = WG.FlowUI.Draw.SelectHighlight

    updateWidgetScale()

    font = WG['fonts'].getFont()
    font2 = WG['fonts'].getFont(fontfile2, 1.1, math.max(0.16, 0.25 / widgetScale), math.max(4.5, 6 / widgetScale))

	local MakeAtlasOnDemand = VFS.Include("LuaUI/Widgets/include/AtlasOnDemand.lua")
	if AdvPlayersListAtlas then 
		--AdvPlayersListAtlas:Delete()
	end
	
	local cellheight = math.min(32, math.ceil(math.max(font.size, font2.size) + 4))
	local cellwidth = math.ceil(cellheight*1.25)
	local cellcount = math.ceil(math.sqrt(32+32 + 200))
	local atlasconfig = {sizex = cellheight * cellcount, sizey =  cellwidth*cellcount, xresolution = cellheight, yresolution = cellwidth, name = "AdvPlayersListAtlas", defaultfont = {font = font, options = 'o'}}
	AdvPlayersListAtlas = MakeAtlasOnDemand(atlasconfig)
	for i = 0, 99 do 
		AdvPlayersListAtlas:AddText(string.format("%02d", i))
	end
    forceMainListRefresh = true
end

function widget:MapDrawCmd(playerID, cmdType, px, py, pz)
    -- get the points drawn (to display point indicator)
    if m_point.active then
        if cmdType == "point" then
            player[playerID].pointX = px
            player[playerID].pointY = py
            player[playerID].pointZ = pz
            player[playerID].pointTime = now + pointDuration
        end
    end
end


function widget:TextCommand(command)
    if string.sub(command, 1, 8) == 'speclist' then
        local words = {}
        for w in command:gmatch("%S+") do
            words[#words+1] = w
        end
        if string.sub(command, 10, 10) ~= '' then
            if string.sub(command, 10, 10) == '0' then
                specListShow = false
				alwaysHideSpecs = true
            elseif string.sub(command, 10, 10) == '1' then
                specListShow = true
				alwaysHideSpecs = false
            end
        else
            specListShow = not specListShow
        end
        SetModulesPositionX() --why?
        SortList()
        CreateLists()
    end
end