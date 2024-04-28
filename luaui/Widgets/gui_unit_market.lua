function widget:GetInfo() return {
	name    = "Unit Market",
	desc    = "Allows players to trade units with each other. Allies only. Fair price!",
	author  = "Tom Fyuri",
	date    = "2024",
	license = "GNU GPL v2",
	layer   = 0,
	enabled = true,
} end

-- What's the general idea, the pitch, the plan, etc:
-- 1) Player A should be able to offer unit (any unit) for sale, for its fare metalCost market price.
-- 2) Player B should be able to offer to buy the unit. If playerB can afford it then we go to the next step.
-- 3) Gadget that oversees this takes the metal from the playerA and gives to playerB, and takes the unit from playerB and gives to playerA. That's it!
-- Why? So you can trade T2 cons without tracking who paid what/what/how much. Just flip the unit for sale and we are good to go.
-- Note: you can set for sale ANYTHING as long as its a finished unit. Hotkey/Button to toggle sale. Just alt + double-click to buy.
-- TODO: develop UI so that you can browse units that are for sale with a buy button maybe?
-- TODO: maybe a button in a unitstate window "this unit is for sale" toggle so you can start selling units without hotkey or separate button?
-- Extra feature: AI will remember your gifts and give you discount in kind for your purchases. In practise, this means you can swap units with AI for free, as long as you've given the AI more than you bought from AI.
-- But as it is, it should be fine for the first version.

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
local spGetPlayerInfo       = Spring.GetPlayerInfo
local spGetSpectatingState  = Spring.GetSpectatingState
local spGetTeamInfo         = Spring.GetTeamInfo
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitTeam			= Spring.GetUnitTeam
local spGetSelectedUnits    = Spring.GetSelectedUnits
local spAreTeamsAllied      = Spring.AreTeamsAllied
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
local myTeamID     = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local gaiaTeamID   = Spring.GetGaiaTeamID()
local isSpectating, fullview = Spring.GetSpectatingState()
local myPlayerID   = Spring.GetMyPlayerID()
local logging    = false -- Logging...
local see_prices = false -- Set to true for local testing to verify unit prices
local see_sales  = true  -- Set to false to never see console trade messages

local unitMarket = Spring.GetModOptions().unit_market
local unitsForSale = {} -- Array to store units offered for sale {UnitID => metalCost}

-- button vars
local sellUnitText = Spring.I18N('ui.unitMarket.sellUnit') or "Sell Unit"
local buttonPosX = 0.41
local buttonPosY = 0.066
local UiButton, UiElement
local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local vsx, vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx * vsy / 6200000))
local fontfileSize = 50
local fontfileOutlineSize = 10
local fontfileOutlineStrength = 1.4
local textSize = 12
local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
local uiScale = (0.7 + (vsx * vsy / 6500000))
local buttonX = math.floor(vsx * buttonPosX)
local buttonY = math.floor(vsy * buttonPosY)
local orgbuttonH = 40
local orgbuttonW = 115
local buttonW = math.floor(orgbuttonW * uiScale / 2) * 2
local buttonH = math.floor(orgbuttonH * uiScale / 2) * 2
local buttonList = nil
local uiPadding = 20
local uiElementRect = { buttonX - (buttonW / 2) - uiPadding, buttonY - (buttonH / 2) - uiPadding, buttonX + (buttonW / 2) + uiPadding, buttonY + (buttonH / 2) + uiPadding }
local buttonRect = { buttonX - (buttonW / 2), buttonY - (buttonH / 2), buttonX + (buttonW / 2), buttonY + (buttonH / 2) }
-- see ViewResize() for more actual size values

local function OfferToSell(unitID)
    local unitDefID = spGetUnitDefID(unitID)
    if not unitDefID then return end
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return end -- ?
    local price = unitDef.metalCost
    spSendLuaRulesMsg("unitOfferToSell " .. unitID .. " " .. price) -- Tell gadget we are offering unit for sale
end

local function OfferToBuy(unitID)
    spSendLuaRulesMsg("unitTryToBuy " .. unitID) -- Tell gadget we are buying (or trying to)
end

local function ClearUnitData(unitID) -- if unit is no longer sold then remove it from being sold
    unitsForSale[unitID] = nil
end

local function Print(msg)
    if (see_sales) then
        spEcho(msg)
    end
    if (logging) then
        spLog(widget:GetInfo().name, LOG.INFO, msg)
    end
end

local function InitFindSales()
    for _, unitID in ipairs(Spring.GetAllUnits()) do
        if spValidUnitID(unitID) then
            teamID = spGetUnitTeam(unitID)
            if fullview or spAreTeamsAllied(teamID, myTeamID) then
                local price = spGetUnitRulesParam(unitID, "unitPrice")
                --Spring.Echo("I see "..unitID.." p:"..price)
                if (price > 0) then
                    unitsForSale[unitID] = price
		        else
		            ClearUnitData(unitID)
                end
            end
        end
    end
end

local function toggleSelectedUnitsForSale(selectedUnits)
	local anyUnitForSale = false
	for _, unitID in ipairs(selectedUnits) do
		if unitsForSale[unitID] then
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

local function FindPlayerIDFromTeamID(teamID)
    local playerList = spGetPlayerList()
    for i = 1, #playerList do
        local playerID = playerList[i]
        local team = select(6,spGetPlayerInfo(playerID))
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
    local unitDefID = spGetUnitDefID(unitID)
    if not unitDefID then return end
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return end
    local name = getTeamName(msgFromTeamID)
    if price > 0 then
        unitsForSale[unitID] = price
        local msg = Spring.I18N('ui.unitMarket.sellingUnit', { name = name, unitName = unitDef.translatedHumanName, price = price })
        Print(msg)
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

local function unitSaleBroadcast(unitID, price, msgFromTeamID)
    unitSale(unitID, price, msgFromTeamID)
end

local function unitSoldBroadcast(unitID, price, old_ownerID, msgFromTeamID)
    unitSold(unitID, price, old_ownerID, msgFromTeamID)
end

function widget:Initialize()
    -- if market is disabled, exit
    if not unitMarket or unitMarket ~= true then
        widgetHandler:RemoveWidget() -- not enabled? shutdown
    end
	-- TODO, in 1vs1 or if you are alone in a team, unless for debug purposes - widget should auto-shutdown
    -- TODO, if you restart the widget you will forget who is selling any units, create inline that loops through all units and gets param if they are on sale
    if not(Spring.IsReplay() or spGetSpectatingState()) then
	    widgetHandler:AddAction("sell_unit", OfferToSellAction, nil, 'p')
    end
	widgetHandler:RegisterGlobal('unitSaleBroadcast', unitSaleBroadcast)
	widgetHandler:RegisterGlobal('unitSoldBroadcast', unitSoldBroadcast)
	InitFindSales()

	UiButton = WG.FlowUI.Draw.Button
	UiElement = WG.FlowUI.Draw.Element
	elementPadding = WG.FlowUI.elementPadding

    widget:ViewResize()
end

function widget:Shutdown()
    widgetHandler:DeregisterGlobal('unitSaleBroadcast')
    widgetHandler:DeregisterGlobal('unitSoldBroadcast')
	gl.DeleteList(buttonList)
	gl.DeleteFont(font)
end

function widget:PlayerChanged(playerID)
    myPlayerID = Spring.GetMyPlayerID()
	if myTeamID ~= Spring.GetMyTeamID() then
		myTeamID = Spring.GetMyTeamID()
    end
    if myAllyTeamID ~= Spring.GetMyAllyTeamID() then
        myAllyTeamID = Spring.GetMyAllyTeamID()
    end
    isSpectating, fullview = spGetSpectatingState()
    InitFindSales()
end

function widget:TextCommand(command)
    if (string.find(command, 'sell_unit') == 1) then
        local selectedUnits = spGetSelectedUnits()
        for _, unitID in ipairs(selectedUnits) do
            OfferToSell(unitID)
        end
    end
end

function widget:TextCommand(command)
    if (string.find(command, 'sell_unit') == 1) then
        local selectedUnits = spGetSelectedUnits()
        if #selectedUnits <= 0 then return end
		toggleSelectedUnitsForSale(selectedUnits)
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	ClearUnitData(unitID)
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	ClearUnitData(unitID)
end

--[[function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	ClearUnitData(unitID)
end

--function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	--ClearUnitData(unitID)
--end]] -- believe gadget broadcasts instead

-------------------------------------------------------- UI code ---
function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	uiScale = (0.75 + (vsx * vsy / 6000000))
	buttonX = math.floor(vsx * buttonPosX)
	buttonY = math.floor(vsy * buttonPosY)
	orgbuttonW = font:GetTextWidth(sellUnitText) * textSize * uiScale * 1.4
	buttonW = math.floor(orgbuttonW * uiScale / 2) * 1.4
	buttonH = math.floor(orgbuttonH * uiScale / 2) * 1.4
	uiPadding = math.floor(elementPadding * 1.5)
end

local doubleClickTime = 1 -- Maximum time in seconds between two clicks for them to be considered a double-click
local maxDistanceForDoubleClick = 10 -- Maximum distance between two clicks for them to be considered a double-click
local rangeBuy = 30 -- Maximum range for units to buy over a double-click.
-- TODO - investigate whether players want to double-click and drag to start drawing a circle to buy everything inside circle for mass buying purposes.

local lastClickCoords = nil
local lastClickTime = nil

function widget:MousePress(mx, my, button)
    if isSpectating then return false end

    local alt, ctrl, meta, shift = spGetModKeyState()
    if alt then
        if button == 1 then
            local _, coords = spTraceScreenRay(mx, my, true)
            if coords ~= nil then
                local currentTime = spGetGameSeconds()
                -- Check for a double-click
                if lastClickCoords ~= nil and lastClickTime ~= nil then
                    local distance = math.floor(math.sqrt((lastClickCoords[1] - coords[1])^2 + (lastClickCoords[2] - coords[2])^2 + (lastClickCoords[3] - coords[3])^2))
                    if currentTime - lastClickTime <= doubleClickTime and distance <= maxDistanceForDoubleClick then
                        -- Double-click detected
                        --Spring.Echo("Double-click detected!")

                        local selectedUnits = spGetUnitsInCylinder(coords[1],coords[3],rangeBuy)
                        for _, unitID in ipairs(selectedUnits) do
                            if (unitID and unitsForSale[unitID]) then
                                -- ignore your own units?
                                local unitTeamID = spGetUnitTeam(unitID)
                                if unitTeamID ~= myTeamID then -- comment this if if you are debugging
                                    OfferToBuy(unitID)
                                end
                            end
                        end
                        return #selectedUnits > 0
                        --
                    end
                end
                -- Store the current click as the last click
                lastClickCoords = coords
                lastClickTime = currentTime
            end
        end
    end
    if not (alt or ctrl or shift) then
        local selectedUnits = spGetSelectedUnits()
        if (#selectedUnits <= 0) then
            return false
        end
        -- pressing button element
        if mx > uiElementRect[1] and mx < uiElementRect[3] and my > uiElementRect[2] and my < uiElementRect[4] then
            -- pressing actual button
            if mx > buttonRect[1] and mx < buttonRect[3] and my > buttonRect[2] and my < buttonRect[4] then
                toggleSelectedUnitsForSale(selectedUnits)
                return true
            end
        end
    end
end

local spIsGUIHidden = Spring.IsGUIHidden
local animationDuration = 7
local animationFrequency = 3
function widget:DrawScreen()
    if spIsGUIHidden() then
        return
    end
    local selectedUnits = spGetSelectedUnits()
    if (#selectedUnits <= 0) then
        return
    end

    local alt, ctrl, meta, shift = spGetModKeyState()
    gl.DeleteList(buttonList)
    --gl.Color(1, 0.5, 0, 0.8) 
    local color = {1, 0.65, 0, 0.8} -- Orange color for button background
    local mult = 0.15
    local x, y = spGetMouseState()
	uiElementRect = { buttonX - (buttonW / 2) - uiPadding, buttonY - (buttonH / 2) - uiPadding, buttonX + (buttonW / 2) + uiPadding, buttonY + (buttonH / 2) + uiPadding }
	buttonRect = { buttonX - (buttonW / 2), buttonY - (buttonH / 2), buttonX + (buttonW / 2), buttonY + (buttonH / 2) }
    if not (alt or ctrl or shift) then
        if x > buttonRect[1] and x < buttonRect[3] and y > buttonRect[2] and y < buttonRect[4] then
            mult = 0.55
        end
    else
        mult = 0.01
    end
    buttonList = gl.CreateList(function()
		UiElement(uiElementRect[1], uiElementRect[2], uiElementRect[3], uiElementRect[4], 1, 1, 1, 1, 1, 1, 1, 1)
        UiButton(buttonRect[1], buttonRect[2], buttonRect[3], buttonRect[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, { color[1]*mult, color[2]*mult, color[3]*mult, 1 }, { color[1], color[2], color[3], 0.2 })
    end)
    gl.CallList(buttonList)

    gl.Color(1, 1, 1, 1)  -- White color for text
    gl.Text(sellUnitText, buttonRect[1]+((buttonRect[3]-buttonRect[1])/2), (buttonRect[2]+((buttonRect[4]-buttonRect[2])/2)) - (buttonH * 0.16), textSize * uiScale, "co")
end
function widget:DrawWorld()
	if spIsGUIHidden() or next(unitsForSale) == nil then
		return
	end

	local cameraState = spGetCameraState()
	local camHeight = cameraState and cameraState.dist or nil

	if camHeight > 9000 then
		return
	end

	for unitID, _ in pairs(unitsForSale) do
		local x, y, z = spGetUnitPosition(unitID)

		if spIsUnitInView(unitID) and x then
            local currentTime = spGetGameSeconds() % animationDuration
            local animationProgress = math.sin((currentTime / animationDuration) * (2 * math.pi * animationFrequency))

            local greenColorA	= {0.3, 1.0, 0.3, 1.0}
            local redColor = 1
            local greenColor = (0.8 + animationProgress * 0.2)

            local radiusSize = 15 + animationProgress * 10

            local ux, uy, uz = spGetUnitViewPosition(unitID)

            local yellow	 = {1.0, 1.0, 0.3, 0.75}
            local yellowBold = {1.0, 1.0, 0.3, 1.0}

            if see_prices then
                local msg = unitsForSale[unitID]..'m'
                gl.PushMatrix()
                gl.Translate(ux, uy, uz)
                gl.Billboard()
                gl.Color(yellowBold)
                gl.BeginText()
                gl.Text(msg, 16.0, -2.0, 10.0)
                gl.EndText()
                gl.PopMatrix()
            end
            gl.PushMatrix()
            gl.Translate(ux, uy, uz)
            gl.Billboard()
            gl.Color(yellow)
            gl.BeginText()
            gl.Text('$', 12.0, 15.0, 24.0)
            gl.EndText()
            gl.PopMatrix()

            gl.Color(greenColorA)
            gl.DrawGroundCircle(x, y, z, radiusSize, 32)  -- Increase the radius based on animation progress

            local numSegments = 32
            local angleStep = (2 * math.pi) / numSegments
            gl.BeginEnd(GL.TRIANGLE_FAN, function()
                --gl.Color(1, greenColor, 0, (0.5 + animationProgress * 0.5))
                gl.Color(0.1, 1.0, 0.3, (0.1 + animationProgress * 0.05))
                gl.Vertex(x, y+25, z)
                for i = 0, numSegments do
                    local angle = i * angleStep
                    gl.Vertex(x + math.sin(angle) * radiusSize, y + 0, z + math.cos(angle) * radiusSize)
                end
            end) -- animmation part of the code was inspired by ally t2 lab flashing widget
        end
	end
end
