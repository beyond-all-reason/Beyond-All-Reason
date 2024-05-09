if not Spring.GetModOptions().unit_market then
    return
end

function widget:GetInfo() return {
    name    = "Unit Market",
    desc    = "Allows players to trade units with each other. Allies only. Fair price!",
    author  = "Tom Fyuri",
    date    = "2024",
    license = "GNU GPL v2",
    handler = true,
    layer   = 2, -- I want the command to be last in order queue
    enabled = true
} end

-- What's the general idea, the pitch, the plan, etc:
-- 1) Player A should be able to offer unit (any unit) for sale, for its fare metalCost market price.
-- 2) Player B should be able to offer to buy the unit. If playerB can afford it then we go to the next step.
-- 3) Gadget that oversees this takes the metal from the playerA and gives to playerB, and takes the unit from playerB and gives to playerA. That's it!
-- Why? So you can trade T2 cons without tracking who paid what/what/how much. Just flip the unit for sale and we are good to go.
-- Note: you can set for sale ANYTHING, even unfinished units. Be careful if you buy unfinished units though, you pay FULL PRICE for them. Hotkey/Button to toggle sale. Just alt + double-click to buy.
-- Extra feature: AI will remember your gifts and give you discount in kind for your purchases. In practise, this means you can swap units with AI for free, as long as you've given the AI more than you bought from AI.
-- AI will NOT draw any sale icons.

-- TODO: develop UI so that you can browse units that are for sale with a buy button maybe?

-- How to use:

-- As a seller:
-- 1) select units and do a) or b) or c) or d):
-- a) write in chat: /luaui sell_unit
-- b) write in chat: /sell_unit
-- c) bind a hotkey before hand: bind alt+c /sell_unit, then just press the hotkey.
-- d) press button "Sell Unit" at the bottom center part of your screen.
-- It works like a toggle, so you can toggle selling status by using any of the methods above.
-- Once you are done you (and your allies) will see that the unit is flashing green and is displaying the sign "$" above itself. The price is exactly the same as the unit metalCost.

-- As a buyer:
-- 1) hold alt and double-click over an ally unit that your ally is selling. make sure you have resources first. in case you don't have enough metal - nothing will happen.

--------------------------------
VFS.Include("luarules/configs/customcmds.h.lua")

local spGetPlayerInfo       = Spring.GetPlayerInfo
local spGetSpectatingState  = Spring.GetSpectatingState
local spGetTeamInfo         = Spring.GetTeamInfo
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitTeam			= Spring.GetUnitTeam
local spGetSelectedUnits    = Spring.GetSelectedUnits
local spAreTeamsAllied      = Spring.AreTeamsAllied
local spGetAllyTeamList     = Spring.GetAllyTeamList
local spGetTeamList         = Spring.GetTeamList
local spGetUnitPosition     = Spring.GetUnitPosition
local spSendLuaUIMsg        = Spring.SendLuaUIMsg
local spSendLuaRulesMsg     = Spring.SendLuaRulesMsg
local spValidUnitID         = Spring.ValidUnitID
local spGetCameraState      = Spring.GetCameraState
local spGetGameSeconds      = Spring.GetGameSeconds
local spEcho                = Spring.Echo
local spLog                 = Spring.Log
local spIsUnitInView        = Spring.IsUnitInView
local spGetPlayerList       = Spring.GetPlayerList
local spGetAIInfo           = Spring.GetAIInfo
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spTraceScreenRay      = Spring.TraceScreenRay
local spGetUnitsInCylinder  = Spring.GetUnitsInCylinder
local spGetModKeyState      = Spring.GetModKeyState
local spGetMouseState       = Spring.GetMouseState
local spGetUnitRulesParam  	= Spring.GetUnitRulesParam
local spSetUnitRulesParam   = Spring.SetUnitRulesParam
local spGetGameRulesParam   = Spring.GetGameRulesParam
local spMarkerAddPoint      = Spring.MarkerAddPoint
local spGetTeamColor		= Spring.GetTeamColor
local spGetTeamResources    = Spring.GetTeamResources
local spGetGameFrame        = Spring.GetGameFrame
local myTeamID     = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local gaiaTeamID   = Spring.GetGaiaTeamID()
local isSpectating, fullview = Spring.GetSpectatingState()
local myPlayerID   = Spring.GetMyPlayerID()
local tooltip = Spring.I18N('ui.orderMenu.sellunit_tooltip')
local unitMarket = Spring.GetModOptions().unit_market
local selectedUnits
local lastRequesterTime = 0
local lastRequesterID = nil
local lastBuyRuquestTime = 0
local notEnoughMetalTime = 3
local notEnoughMetalTimer = 0
local notEnoughForUnit = nil
local unitsForSale = {} -- Array to store units offered for sale {UnitID => metalCost}
local loneTeamPlayer = false
local ignoreTeam = {} -- Ignore teams that do not have human allies
local triedToBuy = nil
local triedToBuyTime = 0
local triedToBuyFrame = 0
-- settings
local buyWithoutHoldingAlt = false -- flip to true to buy with just a double-click
local see_prices = false -- Set to true for local testing to verify unit prices
local see_sales  = true  -- Set to false to never see console trade messages
local spec_sale_offers = false -- Disables spectators hearing about sale offers
local buy_requests = true -- Allow to place "Sell me this" $$$ pings
local show_ai_trade_icons = false -- This is a drain on resources
local buy_request_cooldown = 2 -- 2 seconds
--

--------------------------------
local function addUnitToSale(unitID, price)
    local index = #unitsForSale + 1
    unitsForSale[index] = {unitID = unitID, price = price}
end
local function removeUnitFromSale(unitID)
    for i, unitInfo in ipairs(unitsForSale) do
        if unitInfo.unitID == unitID then
            table.remove(unitsForSale, i)
            break
        end
    end
end
local function isUnitForSale(unitID)
    for i, unitInfo in ipairs(unitsForSale) do
        if unitInfo.unitID == unitID then
            return true
        end
    end
    return false
end
local function SetUnitPrice(unitID, price)
    for i, unitInfo in ipairs(unitsForSale) do
        if unitInfo.unitID == unitID then
            return true
        end
    end
    return false
end
local function GetUnitPrice(unitID)
    for i, unitInfo in ipairs(unitsForSale) do
        if unitInfo.unitID == unitID then
            return unitInfo.price
        end
    end
    return 0
end
--------------------------------
-- This is how the unit is set for sale, the "sendLuaRulesMsg unitID",
-- sending price as well doesn't do anything just yet (on backend), but if players demand different prices we can work on implementing that
local function OfferToSell(unitID)
    spSendLuaRulesMsg("unitOfferToSell " .. unitID) -- Tell gadget we are offering unit for sale
end

local function toggleSelectedUnitsForSale(selectedUnits)
	local anyUnitForSale = false
	for _, unitID in ipairs(selectedUnits) do
		if isUnitForSale(unitID) then
			anyUnitForSale = true
			OfferToSell(unitID)
		end
	end
	if not anyUnitForSale then
		for _, unitID in ipairs(selectedUnits) do
			OfferToSell(unitID)
		end
	end
end

local function OfferToSellAction()
    if #selectedUnits <= 0 then return end
    toggleSelectedUnitsForSale(selectedUnits)
end

local function ClearUnitData(unitID) -- if unit is no longer sold then remove it from being sold
    removeUnitFromSale(unitID)
end

local function Print(msg)
    if (see_sales) then
        spEcho(msg)
    end
end

local function InitFindSales()
    for _, unitID in ipairs(Spring.GetAllUnits()) do
        if spValidUnitID(unitID) then
            teamID = spGetUnitTeam(unitID)
            local _, _, _, isAITeam = spGetTeamInfo(teamID)
            if not ignoreTeam[teamID] and (fullview or spAreTeamsAllied(teamID, myTeamID)) then
                local price = spGetUnitRulesParam(unitID, "unitPrice")
                if (price > 0) then
                    addUnitToSale(unitID, price)
                else
                    ClearUnitData(unitID)
                end
            end
        end
    end
end

local function FindPlayerIDFromTeamID(teamID)
    local playerList = spGetPlayerList()
    for i = 1, #playerList do
        local playerID = playerList[i]
        local team = select(4,spGetPlayerInfo(playerID))
        if team == teamID then
            return playerID
        end
    end
    return nil
end

local function getTeamName(teamID)
    local _, _, _, isAITeam = spGetTeamInfo(teamID)
    if isAITeam then
        local _, _, _, aiName = spGetAIInfo(teamID)
        if aiName then
            local niceName = spGetGameRulesParam('ainame_' .. teamID)
            if niceName then
                return niceName
            else
                return aiName
            end
        else
            return "AI Team (" .. tostring(teamID)..")"
        end
    else
        local playerID = FindPlayerIDFromTeamID(teamID)
        if playerID then
            local playerName, _ = spGetPlayerInfo(playerID, false)
            return playerName
        else
            return "Unknown Team (" .. tostring(teamID)..")"
        end
    end
end

local function unitSale(unitID, price, msgFromTeamID)
    if ignoreTeam[msgFromTeamID] then return end
    local unitDefID = spGetUnitDefID(unitID)
    if not unitDefID then return end
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return end
    local name = getTeamName(msgFromTeamID)
    if price > 0 then
        addUnitToSale(unitID, price)
        local msg = Spring.I18N('ui.unitMarket.sellingUnit', { name = name, unitName = unitDef.translatedHumanName, price = price })
        if (not isSpectating or spec_sale_offers) then
            Print(msg)
        end
    else
        ClearUnitData(unitID)
    end
end

local function unitSold(unitID, price, old_ownerID, msgFromTeamID)
    ClearUnitData(unitID)
    local unitDefID = spGetUnitDefID(unitID)
    if not unitDefID then return end
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return end
    local old_owner_name = getTeamName(old_ownerID)
    local new_owner_name = getTeamName(msgFromTeamID)
    if (old_owner_name and new_owner_name) then
        local msg = Spring.I18N('ui.unitMarket.unitSold', { oldName = old_owner_name, name = new_owner_name, unitName = unitDef.translatedHumanName, price = price })
        Print(msg)
    end
end

function widget:UnitSale(unitID, price, msgFromTeamID)
    unitSale(unitID, price, msgFromTeamID)
end

function widget:UnitSold(unitID, price, old_ownerID, msgFromTeamID)
    unitSold(unitID, price, old_ownerID, msgFromTeamID)
end

local function colourNames(teamID)
	local nameColourR, nameColourG, nameColourB, nameColourA = spGetTeamColor(teamID)
	local R255 = math.floor(nameColourR * 255)
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
	return "\255" .. string.char(R255) .. string.char(G255) .. string.char(B255)
end

local function OfferToBuy(unitID)
    spSendLuaRulesMsg("unitTryToBuy " .. unitID) -- Tell gadget we are buying (or trying to)
    triedToBuyTime = os.clock()+0.3
    triedToBuyFrame = spGetGameFrame()
    triedToBuy = unitID
end

-- only buyer and seller will recieve pings, nobody else, not even spectators
local function TriedToBuyUnit()
    if triedToBuy == nil then return end
    local unitID = triedToBuy
    local teamID = spGetUnitTeam(unitID)
    if teamID == myTeamID then
        triedToBuy = nil
        return -- already bought
    end
    local price = spGetUnitRulesParam(unitID, "unitPrice")
    if price > 0 then -- not enough metal
        local eCurrMy, eStorMy,_, _,_,_,_,_ = spGetTeamResources(myTeamID, "metal")
        if price > eStorMy or price > eCurrMy then
            notEnoughForUnit = unitID
            notEnoughMetalTimer = os.clock()+3
			Spring.PlaySoundFile("beep6", 0.6, 'ui')
        end
    else -- not for sale -> wtb msg
        if buy_requests and not isUnitForSale(unitID) and os.clock() >= lastBuyRuquestTime then
            local _, _, _, isAITeam = spGetTeamInfo(teamID)
            if not isAITeam then
                lastBuyRuquestTime = os.clock()+buy_request_cooldown
                spSendLuaUIMsg("unitWantToBuy " .. unitID)
                local teamName = getTeamName(myTeamID)
                local x,y,z = spGetUnitPosition(unitID)
                if x then
                    spMarkerAddPoint(x,y,z,colourNames(myTeamID)..teamName..": $$$",true) -- local ping
                end
            end
        end
    end
    triedToBuy = nil
end

function widget:RecvLuaMsg(msg, playerID)
    local _, _, mySpec, msgFromTeamID = spGetPlayerInfo(playerID)

    if not msgFromTeamID or mySpec or isSpectating or not spAreTeamsAllied(msgFromTeamID, myTeamID) or msgFromTeamID == myTeamID then return end

    local words = {}
    for word in msg:gmatch("%S+") do
        table.insert(words, word)
    end

    if words[1] == "unitWantToBuy" then
        local unitID = words[2]
        if unitID == nil then return end
        local teamName = getTeamName(msgFromTeamID)
        local x,y,z = spGetUnitPosition(unitID)
        if x then
            if (msgFromTeamID ~= lastRequesterID) or (msgFromTeamID == lastRequesterID and os.clock() >= lastRequesterTime) then
                spMarkerAddPoint(x,y,z,colourNames(msgFromTeamID)..teamName..": $$$",true) -- local ping
                lastRequesterID = msgFromTeamID
                lastRequesterTime = os.clock()+buy_request_cooldown
            end
        end
    end
end

local function DoIhaveAllies()
    local alliedTeams = spGetTeamList(myAllyTeamID)
    for i = 1, #alliedTeams do
        if myTeamID ~= alliedTeams[i] then
            return true
        end
    end
    return false
end

function widget:Initialize()
    -- if market is disabled, exit
    if not unitMarket or unitMarket ~= true then
        widgetHandler:RemoveWidget()
    end

    -- if you are debugging, comment this section
    loneTeamPlayer = not DoIhaveAllies()
    for _, allyTeamID in ipairs(spGetAllyTeamList()) do
        local allyTeamTeams = spGetTeamList(allyTeamID)
        local hasHumanPlayers = false
        for _, teamID in ipairs(allyTeamTeams) do
            local _, _, _, isAITeam = spGetTeamInfo(teamID)
            if not isAITeam then
                hasHumanPlayers = true
                break
            end
        end
        if not hasHumanPlayers then
            for _, teamID in ipairs(allyTeamTeams) do
                ignoreTeam[teamID] = true
            end
        end
        for _, teamID in ipairs(allyTeamTeams) do
            local _, _, _, isAITeam = spGetTeamInfo(teamID)
            if not show_ai_trade_icons and isAITeam then
                ignoreTeam[teamID] = true
            end
        end
    end
    --

	InitFindSales()
    widget:SelectionChanged(spGetSelectedUnits())
end

function widget:PlayerChanged(playerID)
    myPlayerID = Spring.GetMyPlayerID()
	myTeamID = Spring.GetMyTeamID()
    myAllyTeamID = Spring.GetMyAllyTeamID()
    isSpectating, fullview = spGetSpectatingState()
    loneTeamPlayer = not DoIhaveAllies()
    InitFindSales()
end

function widget:TextCommand(command)
    if (string.find(command, 'sell_unit') == 1) or (string.find(command, 'sell') == 1) then
        OfferToSellAction()
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	ClearUnitData(unitID)
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	ClearUnitData(unitID)
end

function widget:SelectionChanged(sel)
	selectedUnits = sel
end

function widget:CommandsChanged()
	if not loneTeamPlayer then
		if selectedUnits and #selectedUnits > 0 then
			local customCommands = widgetHandler.customCommands
			for i = 1, #selectedUnits do
                customCommands[#customCommands + 1] = {
                    id = CMD_SELL_UNIT,
                    type = CMDTYPE.ICON,
                    tooltip = tooltip,
                    name = 'Sell Unit',
                    cursor = 'sellunit',
                    action = 'sellunit',
                }
                return
			end
		end
	end
end

function widget:CommandNotify(id, params, options)
	if id ~= CMD_SELL_UNIT then
		return
	end
	toggleSelectedUnitsForSale(selectedUnits)
	return true
end

local math_sqrt = math.sqrt
-------------------------------------------------------- UI code ---
local doubleClickTime = 1 -- Maximum time in seconds between two clicks for them to be considered a double-click
local maxDistanceForDoubleClick = 10 -- Maximum distance between two clicks for them to be considered a double-click
local rangeBuy = 30 -- Maximum range for units to buy over a double-click.
-- TODO - investigate whether players want to double-click and drag to start drawing a circle to buy everything inside circle for mass buying purposes.

local lastClickCoords = nil
local lastClickTime = nil
function widget:MousePress(mx, my, button)
    if isSpectating then return false end

    local alt, ctrl, meta, shift = spGetModKeyState()
    if buyWithoutHoldingAlt or alt then
        if button == 1 then
            local currentTime = spGetGameSeconds()
            local rType, cUnitID = spTraceScreenRay(mx, my)
            if lastClickTime ~= nil and currentTime - lastClickTime <= doubleClickTime then -- Double-click detected
                local distance = math_sqrt((mx - lastClickCoords[1])^2 + (my - lastClickCoords[2])^2)
                if distance <= maxDistanceForDoubleClick then -- Distance OK
                    if rType == 'unit' and spValidUnitID(cUnitID) and spGetUnitTeam(cUnitID) ~= myTeamID then
						OfferToBuy(cUnitID)
                    else
                        _, cUnitID = spTraceScreenRay(mx, my, true)
                        local buyingUnits = spGetUnitsInCylinder(cUnitID[1], cUnitID[3], rangeBuy)
                        for _, unitID in ipairs(buyingUnits) do
                            if spValidUnitID(unitID) and spGetUnitTeam(unitID) ~= myTeamID then
                                OfferToBuy(unitID)
                            end
                        end
                    end
                end
            end
            lastClickTime = currentTime
            lastClickCoords = {mx, my}
        end
    end
end

local spIsGUIHidden = Spring.IsGUIHidden
local spGetCameraDirection = Spring.GetCameraDirection
local gl_PushMatrix = gl.PushMatrix
local gl_Billboard = gl.Billboard
local gl_Translate = gl.Translate
local gl_Color = gl.Color
local gl_BeginText = gl.BeginText
local gl_Text = gl.Text
local gl_EndText = gl.EndText
local gl_Vertex = gl.Vertex
local gl_PopMatrix = gl.PopMatrix
local gl_TRIANGLE_FAN = GL.TRIANGLE_FAN
local gl_DrawGroundCircle = gl.DrawGroundCircle
local gl_BeginEnd = gl.BeginEnd
local gl_CreateList = gl.CreateList
local gl_DeleteList = gl.DeleteList
local gl_DrawListAtUnit = gl.DrawListAtUnit
local gl_Texture = gl.Texture
local gl_TexRect = gl.TexRect
local gl_DepthTest = gl.DepthTest
local math_sin = math.sin
local math_cos = math.cos
local math_pi = math.pi
local drawLists = {}
local vsx,vsy = Spring.GetViewGeometry()
local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 45
local fontfileOutlineSize = 4.5
local fontfileOutlineStrength = 9
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
local uiScale = (0.7 + (vsx * vsy / 6500000))
local unitConf = {}
for udid, unitDef in pairs(UnitDefs) do
	local xsize, zsize = unitDef.xsize, unitDef.zsize
	local scale = 6*( xsize^2 + zsize^2 )^0.5
	unitConf[udid] = 7 +(scale/2.5)
end
local DrawIcon
local yellowBoldFont = '\255\255\255\76'
local DrawUnitTradeInfo
if see_prices then
    DrawUnitTradeInfo = function()
        local unitScale
        for i = 1, #unitsForSale do
            local unitID, price = unitsForSale[i].unitID, unitsForSale[i].price
            local x, y, z = spGetUnitPosition(unitID)
            local _, _, _, isAITeam = spGetTeamInfo(teamID)
            if x and spIsUnitInView(unitID) then
                if not drawLists[unitID] then
                    drawLists[unitID] = gl_CreateList(DrawIcon, price)
                end
                unitScale = unitConf[unitDefID]
                gl_DrawListAtUnit(unitID, drawLists[unitID], false, unitScale, unitScale, unitScale)
            end
        end
    end
    DrawIcon = function(text)
        local iconSize = 25
        gl_PushMatrix()
        gl_Color(0.9, 0.9, 0.9, 1)
        gl_Texture(':n:LuaUI/Images/trade_offer.png')
        gl_Billboard()
        gl_Translate(12.0, 18.0, 24.0)
        gl_TexRect(-iconSize/2, -iconSize/2, iconSize/2, iconSize/2)
        if text ~= 0 then
            gl_Texture(false)
            gl_Translate(iconSize/2, -iconSize/2, 0)
            font:Begin()
            font:Print(yellowBoldFont..text, 2.0, 15.0, 12.0)--, "o")
            font:End()
        end
        gl_PopMatrix()
    end
else
    DrawUnitTradeInfo = function()
        local unitScale
        for i = 1, #unitsForSale do
            local unitID = unitsForSale[i].unitID
            local x, y, z = spGetUnitPosition(unitID)
            if x and spIsUnitInView(unitID) then
                if not drawLists[unitID] then
                    drawLists[unitID] = gl_CreateList(DrawIcon, _)
                end
                unitScale = unitConf[unitDefID]
                gl_DrawListAtUnit(unitID, drawLists[unitID], false, unitScale, unitScale, unitScale)
            end
        end
    end
    DrawIcon = function(_)
        local iconSize = 25
        gl_PushMatrix()
        gl_Color(0.9, 0.9, 0.9, 1)
        gl_Texture(':n:LuaUI/Images/trade_offer.png')
        gl_Billboard()
        gl_Translate(12.0, 18.0, 24.0)
        gl_TexRect(-iconSize/2, -iconSize/2, iconSize/2, iconSize/2)
        gl_PopMatrix()
    end
end
function widget:ViewResize(n_vsx,n_vsy)
	vsx,vsy = Spring.GetViewGeometry()
	uiScale = (0.75 + (vsx * vsy / 6000000))
	local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
	end
end
function widget:DrawWorld()
    if spIsGUIHidden() or #unitsForSale <= 0 then
        return
    end
    local cameraState = spGetCameraState()
    local camHeight = cameraState and cameraState.dist or nil
    if camHeight and camHeight > 9000 then
        return
    end
	gl_DepthTest(false)
    DrawUnitTradeInfo()
	gl_DepthTest(true)
end
function widget:DrawScreen()
    if notEnoughForUnit then
        local text = Spring.I18N('ui.unitMarket.notEnoughMetal')
        font:Begin()
        font:Print(text, vsx * 0.5, vsy * 0.66, 26 * uiScale, "co")
        font:End()
    end
end
function widget:Shutdown()
	for k,_ in pairs(drawLists) do
		gl_DeleteList(drawLists[k])
	end
end
local sec = 0
local prevCam = {spGetCameraDirection()}
function widget:Update(dt)
	sec = sec + dt
	if sec > 0.15 then
		sec = 0
		local camX, camY, camZ = spGetCameraDirection()
		if camX ~= prevCam[1] or camY ~= prevCam[2] or camZ ~= prevCam[3] then
			for k,_ in pairs(drawLists) do
				gl_DeleteList(drawLists[k])
				drawLists[k] = nil
			end
		end
		prevCam = {camX,camY,camZ}
	end

    if notEnoughForUnit and os.clock()>=notEnoughMetalTimer then
        notEnoughForUnit = nil
    end

    if triedToBuy and os.clock() >= triedToBuyTime and triedToBuyFrame ~= spGetGameFrame() then
        TriedToBuyUnit()
    end
end
