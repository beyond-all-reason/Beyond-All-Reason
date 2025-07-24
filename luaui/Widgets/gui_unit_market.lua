if not Spring.GetModOptions().unit_market then
    return
end

local widget = widget ---@type Widget

function widget:GetInfo() return {
    name    = "Unit Market",
    desc    = "Allows players to trade units with each other. Allies only. Fair price!",
    author  = "Tom Fyuri",
    date    = "2024",
    license = "GNU GPL v2",
    layer   = 0,
    enabled = true
} end

-- What's the general idea, the pitch, the plan, etc:
-- 1) Player A should be able to offer unit (any unit) for sale, for its fare metalCost market price.
-- 2) Player B should be able to offer to buy the unit. If playerB can afford it then we go to the next step.
-- 3) Gadget that oversees this takes the metal from the playerA and gives to playerB, and takes the unit from playerB and gives to playerA. That's it!
-- Why? So you can trade T2 cons without tracking who paid what/what/how much. Just flip the unit for sale and we are good to go.
-- Note: you can set for sale ANYTHING, even unfinished units. Be careful if you buy unfinished units though, you pay FULL PRICE for them. Hotkey/Button to toggle sale. Just alt + double-click to buy.
-- Extra feature: AI will remember your gifts and give you discount in kind for your purchases. In practise, this means you can swap units with AI for free, as long as you've given the AI more than you bought from AI.
-- AI will NOT draw any sale icons if you disable them in options.

-- How to use:

-- As a seller:
-- 1) select units and do a) or b) or c) or d):
-- a) write in chat: /luaui sell_unit
-- b) write in chat: /sell_unit
-- c) bind a hotkey before hand: bind alt+c /sell_unit, then just press the hotkey.
-- d) press button "For Sale" at the bottom center part of your screen (order window).
-- It is a unit state, so you can toggle selling status by using any of the methods above.
-- Once you are done you (and your allies) will see that the unit is flashing green and is displaying the sign "$" above itself. The price is exactly the same as the unit metalCost.

-- As a buyer:
-- 1) hold alt (optionally) and double-click over an ally unit that your ally is selling. make sure you have resources first. in case you don't have enough metal - nothing will happen.
-- There are various tooltips to help you out in the process.

-- New features 27 May 2024:
-- 1) Rewamped and optimized UI and unit state command.
-- 2) t2con dock at top-right, so you can buy t2 cons fast as fast as they go for sale.
-- 3) same dock has 'saving metal on/off' functionallity which allows you to automatically save metal for the unit you want to buy.

-- Paused for now:
-- "please set unit X for sale" requests, so buyer can get potential seller for a unit to be set on sale.
-- develop UI so that you can browse units that are for sale with a buy button maybe?

--------------------------------

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
local spSendLuaRulesMsg     = Spring.SendLuaRulesMsg
local spValidUnitID         = Spring.ValidUnitID
local spGetCameraState      = Spring.GetCameraState
local spGetGameSeconds      = Spring.GetGameSeconds
local spEcho                = Spring.Echo
local spIsUnitInView        = Spring.IsUnitInView
local spGetPlayerList       = Spring.GetPlayerList
local spGetAIInfo           = Spring.GetAIInfo
local spTraceScreenRay      = Spring.TraceScreenRay
local spGetUnitsInCylinder  = Spring.GetUnitsInCylinder
local spGetModKeyState      = Spring.GetModKeyState
local spGetMouseState       = Spring.GetMouseState
local spGetUnitRulesParam  	= Spring.GetUnitRulesParam
local spGetGameRulesParam   = Spring.GetGameRulesParam
local spMarkerAddPoint      = Spring.MarkerAddPoint
local spGetTeamResources    = Spring.GetTeamResources
local spGetGameFrame        = Spring.GetGameFrame
local spGetUnitHealth       = Spring.GetUnitHealth

local myTeamID              = Spring.GetMyTeamID()
local isSpectating, fullview = Spring.GetSpectatingState()

local spIsGUIHidden = Spring.IsGUIHidden
local spGetCameraDirection = Spring.GetCameraDirection
local glPushMatrix = gl.PushMatrix
local glBillboard = gl.Billboard
local glTranslate = gl.Translate
local glColor = gl.Color
local glPopMatrix = gl.PopMatrix
local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList
local glCallList = gl.CallList
local glDrawListAtUnit = gl.DrawListAtUnit
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glDepthTest = gl.DepthTest

local unitMarket = Spring.GetModOptions().unit_market

local math_sqrt = math.sqrt
local math_floor = math.floor
local math_max = math.max
local math_isInRect = math.isInRect

--
local selectedUnits = nil
local hoveringOverUnitID = nil
local notEnoughMetalTime = 3
local notEnoughMetalTimer = 0
local notEnoughForUnit = nil
local unitsForSale = {} -- Array to store units offered for sale {UnitID => metalCost}
local T2consForSale = {} -- Array of t2 cons that are currently for sale
local t2consFormatted = {} -- Array of t2 cons defs that are on sale
local ignoreTeam = {} -- Ignore teams that do not have human allies
local triedToManullyBuyUnitID = nil
local triedToBuyTime = 0
local triedToBuyFrame = 0
local start_saving = false
local t2conShopTimeout = 15 -- t2con shop closed, wait for new offers for at least this many seconds until giving up
local lastTimeT2ConsOnSale = 0
-- settings-customizable
local seePrices = false -- Set to true for local testing to verify unit prices
local showAIsaleOffers = true -- This is a drain on fps if 5000+ units are for sale
local buyWithoutHoldingAlt = true -- flip to true to buy with just a double-click
-- non-customizable yet or never
local see_sales  = true  -- Set to false to never see console trade messages
local spec_sale_offers = false -- Whether spectators see sale offers
-- ^ you have NO guarantee that the seller will see it though, the way it works seller gets UI Window showing that someone wants some unit to be set for sale
-- they are only shown ONE window per team, so you can't really abuse it, and they CAN ban you for sending too many requests

-- UI
local vsx, vsy = Spring.GetViewGeometry()

local fontSize = 18

local UiElement, UiUnit, UiButton, uiScale

local uiElementRect = {0,0,0,0}
local buyButtons = {}
local buyStatus = nil
local lastPurchaseAttempt = 0
local autoPurchasingUnitID = nil

local dot_count = 0

local T2ConDef = {}
local unitDefInfo = {}
local iconTypes = VFS.Include("gamedata/icontypes.lua")
local groups, unitGroup
--
local drawLists = {}
local unitConf = {}
local t2conDock, t2conDockShown = nil, false
local buyRequestDock, buyRequestDockShown = nil, false
local DrawIcon, DrawHoverIcon
local buyPriceBoldColor = '\255\230\230\230'
local DrawUnitTradeInfo = function() end
local t2conShopText = Spring.I18N('ui.unitMarket.t2conShop')
local shopTitle = Spring.I18N('ui.unitMarket.shopTitle')
local shopInfo = Spring.I18N('ui.unitMarket.shopInfo')
local youAreSellingText = Spring.I18N('ui.unitMarket.youAreSellingText')
local buy_text = Spring.I18N('ui.unitMarket.buy')
local cancel_text = Spring.I18N('ui.unitMarket.abort')
--
local doubleClickTime = 0.7 -- Maximum time in seconds between two clicks for them to be considered a double-click
local maxDistanceForDoubleClick = 10 -- Maximum distance between two clicks for them to be considered a double-click
local rangeBuy = 30 -- Maximum range for units to buy over a double-click.
-- TODO - investigate whether players want to double-click and drag to start drawing a circle to buy everything inside circle for mass buying purposes.
local lastClickCoords = nil
local lastClickTime = nil
--
--------------------------------
for unitDefID, unitDef in pairs(UnitDefs) do
	local xsize, zsize = unitDef.xsize, unitDef.zsize
	local scale = 6*( xsize^2 + zsize^2 )^0.5
	unitConf[unitDefID] = 7 +(scale/2.5)

    if unitDef.customParams.unitgroup == "buildert2" and not unitDef.isFactory and unitDef.isBuilder then
        T2ConDef[unitDefID] = true
    end

    unitDefInfo[unitDefID] = {}
    if unitDef.iconType and iconTypes[unitDef.iconType] and iconTypes[unitDef.iconType].bitmap then
        unitDefInfo[unitDefID].icontype = iconTypes[unitDef.iconType].bitmap
    end

    unitDefInfo[unitDefID].energyCost = unitDef.energyCost
    unitDefInfo[unitDefID].metalCost = unitDef.metalCost
end

--------------------------------
local function isT2Con(unitDefID)
    return T2ConDef[unitDefID]
end
local function addT2ConOffer(unitID, unitDefID)
    local index = #T2consForSale + 1
    T2consForSale[index] = unitID
    lastTimeT2ConsOnSale = os.clock()
end
local function removeT2Offer(unitID)
    for i, tUnitID in ipairs(T2consForSale) do
        if tUnitID == unitID then
            table.remove(T2consForSale, i)
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
local function addUnitToSale(unitID, price, unitDefID)
    if not isUnitForSale(unitID) then
        local index = #unitsForSale + 1
        unitsForSale[index] = {unitID = unitID, price = price}
        if isT2Con(unitDefID) then
            addT2ConOffer(unitID, unitDefID)
        end
    end
end
local function removeUnitFromSale(unitID, unitDefID)
    for i, unitInfo in ipairs(unitsForSale) do
        if unitInfo.unitID == unitID then
            table.remove(unitsForSale, i)
            removeT2Offer(unitID)
            break
        end
    end
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
            local teamID = spGetUnitTeam(unitID)
            local price = spGetUnitRulesParam(unitID, "unitPrice")
            if not ignoreTeam[teamID] and (fullview or spAreTeamsAllied(teamID, myTeamID)) and (price > 0) then
                addUnitToSale(unitID, price, spGetUnitDefID(unitID))
            else
                ClearUnitData(unitID)
            end
        end
    end
end

local function FindPlayerIDFromTeamID(teamID)
    local playerList = spGetPlayerList()
    for i = 1, #playerList do
        local playerID = playerList[i]
        local team = select(4,spGetPlayerInfo(playerID, false))
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
            local playerName = select(1,spGetPlayerInfo(playerID, false))
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
        addUnitToSale(unitID, price, unitDefID)
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

local function clearPurchaseQueue()
    spSendLuaRulesMsg("stopSaving")
    start_saving = false
    buyStatus = nil
    autoPurchasingUnitID = nil
end

function widget:UnitSold(unitID, price, old_ownerID, msgFromTeamID)
    if (autoPurchasingUnitID == unitID and msgFromTeamID == myTeamID) then -- successfull purchase by YOU
        clearPurchaseQueue()
        local x, y, z = spGetUnitPosition(unitID)
        spMarkerAddPoint(x, y, z, "", true)
    end
    unitSold(unitID, price, old_ownerID, msgFromTeamID)
end

local function OfferToBuy(unitID)
    spSendLuaRulesMsg("unitTryToBuy " .. unitID) -- Tell gadget we are buying (or trying to)
    triedToBuyTime = os.clock()+0.3
    triedToBuyFrame = spGetGameFrame()
    triedToManullyBuyUnitID = unitID
end

local function TriedToBuyUnit()
    if triedToManullyBuyUnitID == nil then return end
    local unitID = triedToManullyBuyUnitID
    if not spValidUnitID(unitID) then return end
    local teamID = spGetUnitTeam(unitID)
    if teamID == myTeamID then
        triedToManullyBuyUnitID = nil
        return -- already bought
    end
    local price = spGetUnitRulesParam(unitID, "unitPrice")
    if price and price > 0 then -- not enough metal
        local eCurrMy, eStorMy,_, _,_,_,_,_ = spGetTeamResources(myTeamID, "metal")
        if price > eStorMy or price > eCurrMy then
            notEnoughForUnit = unitID
            notEnoughMetalTimer = os.clock()+notEnoughMetalTime
			Spring.PlaySoundFile("beep6", 0.6, 'ui')
        end
    --else -- not for sale -> wtb msg -- TODO
    end
    triedToManullyBuyUnitID = nil
end

-- TODO
--[[function widget:RecvLuaMsg(msg, playerID)
    local _, _, mySpec, msgFromTeamID = spGetPlayerInfo(playerID)

    if not msgFromTeamID or mySpec or isSpectating or not spAreTeamsAllied(msgFromTeamID, myTeamID) or msgFromTeamID == myTeamID then return end

    local words = {}
    for word in msg:gmatch("%S+") do
        table.insert(words, word)
    end

    if words[1] == "unitWantToBuy" then -- incoming "please sell this unit" request
        local unitID = words[2]
        if unitID == nil then return end

        newRequestForUnitSale(unitID, msgFromTeamID, playerID)
    end
end]]

local function ExecutePurchases()
    if buyStatus ~= nil and lastPurchaseAttempt ~= spGetGameFrame() and #T2consForSale ~= 0 then
        -- we try to buy the unit right away if we have metal, if we dont we start saving for it
        local LookingForUnitDefID = buyStatus[2]
        local price = UnitDefs[LookingForUnitDefID].metalCost
        local mCurr = select(1, spGetTeamResources(myTeamID, "metal"))
        if (mCurr >= price) then
            -- loop through cons for sale and try to buy the best one once we can afford it
            local bestForSaleID = nil
            local bestFinish = 0
            for _, unitID in ipairs(T2consForSale) do
                local teamID = spGetUnitTeam(unitID)
                local unitDefID = spGetUnitDefID(unitID)
                Spring.Echo("checked "..unitDefID.." vs "..LookingForUnitDefID)
                if teamID ~= myTeamID and unitDefID == LookingForUnitDefID then
                    local finished = select(5,spGetUnitHealth(unitID))
                    if bestFinish < finished then
                        bestFinish = finished
                        bestForSaleID = unitID
                    end
                end
            end
            if bestForSaleID ~= nil then
                spSendLuaRulesMsg("unitTryToBuy " .. bestForSaleID) -- Tell gadget we are buying (or trying to)
                autoPurchasingUnitID = bestForSaleID
            end
        elseif not start_saving then
            -- fallback
            spSendLuaRulesMsg("startSaving")
            start_saving = true
        end
        lastPurchaseAttempt = spGetGameFrame()
    end
end

local function FindBestT2ConsForSale()
    if #T2consForSale == 0 then
        if #t2consFormatted ~= 0 then
            t2consFormatted = {}
            lastTimeT2ConsOnSale = os.clock()
        end
        -- abort buy attempts
        if buyStatus ~= nil and os.clock() >= (lastTimeT2ConsOnSale + t2conShopTimeout) then
            clearPurchaseQueue()
        end
        return false
    end

    t2consFormatted = {}
    local unitDefCounts = {}

    for _, unitID in ipairs(T2consForSale) do
        local unitDefID = spGetUnitDefID(unitID)
        local teamID = spGetUnitTeam(unitID)
        if teamID ~= myTeamID and isT2Con(unitDefID) then
            if not unitDefCounts[unitDefID] then
                unitDefCounts[unitDefID] = 0
            end
            unitDefCounts[unitDefID] = unitDefCounts[unitDefID] + 1
        end
    end

    for unitDefID, count in pairs(unitDefCounts) do
        table.insert(t2consFormatted, {unitDefID = unitDefID, count = count})
    end

    return true
end

local function DrawT2TradeDock()
    if groups == nil then return end -- TODO optimise this
	local color = { 0.15, 0.15, 0.15 }
    local padding = 8
    local PicSize = 64
    local buyButtonH = 24
    local headerHeight = fontSize*2
    local text
    local max_height = 140
    if (buyStatus) and (#T2consForSale > 0) then
        local unit_name = UnitDefs[buyStatus[2]].name
        local price = UnitDefs[buyStatus[2]].metalCost
        text = Spring.I18N('ui.unitMarket.purchasing', { name = unit_name, price = price })
    else
        local amIselling = (#t2consFormatted == 0) and (#T2consForSale > 0)
        if #t2consFormatted > 0 then
            text = t2conShopText
        else
            local closeTimer = math_floor(lastTimeT2ConsOnSale + t2conShopTimeout - os.clock())
            if closeTimer <= 0 then
                return
            end
            if buyStatus ~= nil then
                text = shopTitle.."\n"..shopInfo.."\n"..Spring.I18N('ui.unitMarket.failedToFindNewOffers', { sec = closeTimer })
            else
                if amIselling then
                    text = shopTitle.."\n"..youAreSellingText.."\n"..Spring.I18N('ui.unitMarket.autoClosing', { sec = closeTimer })
                else
                    text = shopTitle.."\n"..shopInfo.."\n"..Spring.I18N('ui.unitMarket.autoClosing', { sec = closeTimer })
                end
            end
            max_height = 110
        end
    end
    local max_width = math_max(#t2consFormatted * (PicSize) + 8, font:GetTextWidth(text.."...")*fontSize + 16)
	uiElementRect = {
		(vsx * 0.7), vsy * 0.959 - max_height,
		(vsx * 0.7) + max_width, vsy * 0.959
	}
    -- figure out which t2cons we can buy, if there are any, we will draw the dock
    buyButtons = {}

    if #t2consFormatted > 0 then
    t2conDock = glCreateList(function()
    UiElement(uiElementRect[1], uiElementRect[2], uiElementRect[3], uiElementRect[4], 1, 1, 1, 1, 1, 1, 1, 1)
    font:SetTextColor(1, 1, 1, 1)
    font:SetOutlineColor(0, 0, 0, 1)
    if (buyStatus) then
        text = text..string.rep(".", dot_count)
    end
    font:Print(text, uiElementRect[1] + padding, uiElementRect[2] + max_height - 24, fontSize, "lo") -- TODO make it center?
    for i, data in ipairs(t2consFormatted) do
        local unitDefID, count = data.unitDefID, data.count
        --local price = UnitDefs[unitDefID].metalCost
        local spacing = (i-1) * (PicSize)
		glColor(1,1,1,1)
        UiUnit(
            uiElementRect[1] + padding + spacing, uiElementRect[2] - PicSize - headerHeight + max_height, uiElementRect[1] + PicSize + spacing, uiElementRect[2] - headerHeight + max_height,
            nil,
            1,1,1,1,
			0.03,
            nil, nil,
            "#" .. (unitDefID),
			(unitDefInfo[unitDefID].icontype and ':l:' .. unitDefInfo[unitDefID].icontype or nil),
			groups[unitGroup[unitDefID]],
			{unitDefInfo[unitDefID].metalCost, unitDefInfo[unitDefID].energyCost}
        )
        local extra_shift = PicSize + padding
        font:Print(tostring(count).."#", uiElementRect[1] + PicSize + spacing, uiElementRect[2] - headerHeight - PicSize + max_height + 2, fontSize * 0.67 * uiScale, "ro")
        local buttonCoords = {
            uiElementRect[1] + padding + spacing, uiElementRect[2] - buyButtonH - headerHeight + max_height - extra_shift, uiElementRect[1] + PicSize + spacing, uiElementRect[2] - headerHeight + max_height - extra_shift
        }
        buyButtons[i] = { buttonCoords, unitDefID }
        UiButton(
            buttonCoords[1], buttonCoords[2], buttonCoords[3], buttonCoords[4],
            1, 1, 1, 1, 1, 1, 1, 1, nil,
            { color[1]*0.55, color[2]*0.55, color[3]*0.55, 1 }, { color[1], color[2], color[3], 1 }
        )
        local width = buttonCoords[3] - buttonCoords[1]
        if (buyStatus and buyStatus[1] == i) then
		    font:Print(cancel_text, buttonCoords[1] + width/2, buttonCoords[2] + 6, fontSize * 0.67 * uiScale, "co")
        else
		    font:Print(buy_text, buttonCoords[1] + width/2, buttonCoords[2] + 6, fontSize * 0.67 * uiScale, "co")
        end
    end
    end)
    else
    t2conDock = glCreateList(function()
    UiElement(uiElementRect[1], uiElementRect[2], uiElementRect[3], uiElementRect[4], 1, 1, 1, 1, 1, 1, 1, 1)
    font:SetTextColor(1, 1, 1, 1)
    font:SetOutlineColor(0, 0, 0, 1)
    font:Print(text, uiElementRect[1] + padding, uiElementRect[2] + max_height - 24, fontSize, "lo") -- TODO make it center?
    if (buyStatus ~= nil) then
    local extra_shift = padding
    local buttonCoords = {
        uiElementRect[1] + padding, uiElementRect[2] - buyButtonH + 40 - extra_shift, uiElementRect[1] + PicSize, uiElementRect[2] + 40 - extra_shift
    }
    buyButtons[1] = { buttonCoords, buyStatus[2] }
    UiButton(
        buttonCoords[1], buttonCoords[2], buttonCoords[3], buttonCoords[4],
        1, 1, 1, 1, 1, 1, 1, 1, nil,
        { color[1]*0.55, color[2]*0.55, color[3]*0.55, 1 }, { color[1], color[2], color[3], 1 }
    )
    local width = buttonCoords[3] - buttonCoords[1]
    font:Print(cancel_text, buttonCoords[1] + width/2, buttonCoords[2] + 6, fontSize * 0.67 * uiScale, "co")
    local unit_name = UnitDefs[buyStatus[2]].name
    local price = UnitDefs[buyStatus[2]].metalCost
    font:Print(unit_name.." ("..price.."m)", buttonCoords[1] + width + 20, buttonCoords[2] + 6, fontSize * 0.67 * uiScale, "lo")
    end
    end)
    end
    t2conDockShown = true
end

local function updatedSeePrices(value)
    if value then
        DrawUnitTradeInfo = function()
            local unitScale
            for i = 1, #unitsForSale do
                local unitID, price = unitsForSale[i].unitID, unitsForSale[i].price
                local unitDefID = spGetUnitDefID(unitID)
                if unitDefID and price then
                    local x, y, z = spGetUnitPosition(unitID)
                    if x and spIsUnitInView(unitID) then
                        if not drawLists[unitID] then
                            if unitID == hoveringOverUnitID then
                                drawLists[unitID] = glCreateList(DrawHoverIcon, price)
                            else
                                drawLists[unitID] = glCreateList(DrawIcon, price)
                            end
                        end
                        unitScale = unitConf[unitDefID]
                        glDrawListAtUnit(unitID, drawLists[unitID], false, unitScale, unitScale, unitScale)
                    end
                end
            end
        end
    else
        DrawUnitTradeInfo = function()
            local unitScale
            for i = 1, #unitsForSale do
                local unitID, unitDefID = unitsForSale[i].unitID
                local unitDefID = spGetUnitDefID(unitID)
                if unitDefID then
                    local x, y, z = spGetUnitPosition(unitID)
                    if x and spIsUnitInView(unitID) then
                        if unitID == hoveringOverUnitID then
                            drawLists[unitID] = glCreateList(DrawHoverIcon, nil)
                        else
                            drawLists[unitID] = glCreateList(DrawIcon, nil)
                        end
                        unitScale = unitConf[unitDefID]
                        glDrawListAtUnit(unitID, drawLists[unitID], false, unitScale, unitScale, unitScale)
                    end
                end
            end
        end
    end
    if seePrices ~= value then
        for k,_ in pairs(drawLists) do
            glDeleteList(drawLists[k])
            drawLists[k] = nil
        end
    end
end

local function getIgnoreList()
    -- reset ignore
    local teamList = spGetTeamList()
	for _, teamID in ipairs(teamList) do
        ignoreTeam[teamID] = false
	end
    -- if you are debugging, comment this section
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
            if not showAIsaleOffers and isAITeam then
                ignoreTeam[teamID] = true
            end
        end
    end
    --
end

function widget:Initialize()
    -- if market is disabled, exit
    if not unitMarket or unitMarket ~= true then
        widgetHandler:RemoveWidget()
    end

    WG['unit_market'] = {}
	WG['unit_market'].setSeePrices = function(value)
        updatedSeePrices(value)
		seePrices = value
	end
	WG['unit_market'].getSeePrices = function()
		return seePrices
	end
	WG['unit_market'].setShowAIsaleOffers = function(value)
		showAIsaleOffers = value
        getIgnoreList()
        InitFindSales()
	end
	WG['unit_market'].getShowAIsaleOffers = function()
		return showAIsaleOffers
	end
	WG['unit_market'].setBuyWithoutHoldingAlt = function(value)
		buyWithoutHoldingAlt = value
	end
	WG['unit_market'].getBuyWithoutHoldingAlt = function()
		return buyWithoutHoldingAlt
	end
    updatedSeePrices(seePrices)

    if WG['buildmenu'] and WG['buildmenu'].getGroups then
        groups, unitGroup = WG['buildmenu'].getGroups()
    end

    getIgnoreList()

	widget:ViewResize(vsx, vsy)
    widget:SelectionChanged(spGetSelectedUnits())
	InitFindSales()

    if (spGetGameFrame() > 0) then
        lastTimeT2ConsOnSale = os.clock()
        FindBestT2ConsForSale()
        DrawT2TradeDock()
    end
end

function widget:PlayerChanged(playerID)
	myTeamID = Spring.GetMyTeamID()
    isSpectating, fullview = spGetSpectatingState()
    InitFindSales()
end

function widget:TextCommand(command)
    if (string.find(command, 'sell_unit') == 1) or (string.find(command, 'sell') == 1) then
        OfferToSellAction()
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	ClearUnitData(unitID)
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	ClearUnitData(unitID)
end

function widget:SelectionChanged(sel)
	selectedUnits = sel
end
-------------------------------------------------------- UI code ---
local function drawBuyTooltipDock(unitDefID, mx, my)
    local mCurr = select(1, spGetTeamResources(myTeamID, "metal"))
    local price = UnitDefs[unitDefID].metalCost
    local x = mx - vsx*0.2
    if (mx < 0) then mx = 0 end -- failsafe
    local y = my - 60
    local offset = 0
    local text
    if (mCurr >= price) then
        text = Spring.I18N('ui.unitMarket.youCanAffordIt', { price = price })
        x = mx - 60
    else
        text = Spring.I18N('ui.unitMarket.youCantAffordIt', { price = price })
        offset = 20
    end
    UiElement(x - 20, y - 20 - offset, x + 20 + font:GetTextWidth(text) * fontSize, y + 20 + fontSize, 1, 1, 1, 1, 1, 1, 1, 1)
	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 1)
    font:Print(text, x, y, fontSize, "o")
	font:End()
end

local function drawBuyTooltip(unitID, teamID, price, mx, my)
    local text
    if teamID ~= myTeamID then
        local mCurr = select(1, spGetTeamResources(myTeamID, "metal"))
        if mCurr >= price then
            text = Spring.I18N('ui.unitMarket.youCanBuyThisTooltip', { price = price })
        else
            text = Spring.I18N('ui.unitMarket.youCantBuyThisTooltip', { price = price })
        end
    elseif price > 0 then
        text = Spring.I18N('ui.unitMarket.offeringThisUnitForSale', { price = price })
    else return end
    mx = mx + 40
    my = my - 40
    UiElement(mx - 20, my - 20, mx + 20 + font:GetTextWidth(text) * fontSize, my + 20 + fontSize, 1, 1, 1, 1, 1, 1, 1, 1)
	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 1)
    font:Print(text, mx, my, fontSize, "o")
	font:End()
end

function widget:MousePress(mx, my, button)
    if isSpectating then return end

    if t2conDockShown and button == 1 then
        for index, data in ipairs(buyButtons) do
            local coords = data[1]
            local unitDefID = data[2]
            if math_isInRect(mx, my, coords[1], coords[2], coords[3], coords[4]) then
                if (buyStatus == nil) then
                    buyStatus = {
                        index,
                        unitDefID
                    }
                    -- we only send this if we don't have enough metal or maynot have
                    local mCurr = select(1, spGetTeamResources(myTeamID, "metal"))
                    local price = UnitDefs[unitDefID].metalCost
                    if (mCurr-10) < price then
                        spSendLuaRulesMsg("startSaving")
                        start_saving = true
                    end
                    --Spring.Echo("trying to buy:"..unitDefID)
                else
                    clearPurchaseQueue()
                end
                return
            end
        end
    end

    local alt, ctrl, meta, shift = spGetModKeyState()
    if (buyWithoutHoldingAlt or alt) and button == 1 then
        local currentTime = spGetGameSeconds()
        local rType, cUnitID = spTraceScreenRay(mx, my)
        if lastClickTime ~= nil and currentTime - lastClickTime <= doubleClickTime then -- Double-click detected
            local distance = math_sqrt((mx - lastClickCoords[1])^2 + (my - lastClickCoords[2])^2)
            if distance <= maxDistanceForDoubleClick then -- Distance OK
                if rType == 'unit' and spValidUnitID(cUnitID) and spGetUnitTeam(cUnitID) ~= myTeamID then
                    OfferToBuy(cUnitID)
                else
                    _, cUnitID = spTraceScreenRay(mx, my, true)
                    if cUnitID ~= nil then
                        local buyingUnits = spGetUnitsInCylinder(cUnitID[1], cUnitID[3], rangeBuy)
                        for _, unitID in ipairs(buyingUnits) do
                            if spValidUnitID(unitID) and spGetUnitTeam(unitID) ~= myTeamID then
                                OfferToBuy(unitID)
                            end
                        end
                    end
                end
            end
        end
        lastClickTime = currentTime
        lastClickCoords = {mx, my}
    end
end

DrawIcon = function(text)
    local iconSize = 1.1
    local textSize = 0.5
    glPushMatrix()
    glColor(0.95, 0.95, 0.95, 1)
    glTexture(':n:LuaUI/Images/unit_market/buy_icon.png')
    glBillboard()
	glTranslate(0.4, 0.8, 0)
    --glTranslate(12.0, 18.0, 24.0)
    glTexRect(-iconSize/2, -iconSize/2, iconSize/2, iconSize/2)
    if text ~= nil then
        glTexture(false)
        glTranslate(iconSize/2, -iconSize/2, 0)
        --font:Begin()
        font:Print(buyPriceBoldColor..text.."m", 0.6, 1.0, textSize)
        --font:End()
    end
    glPopMatrix()
end
DrawHoverIcon = function(text)
    local iconSize = 1.1
    local textSize = 0.5
    glPushMatrix()
    glColor(0.95, 0.95, 0.95, 1)
    glTexture(':n:LuaUI/Images/unit_market/buy_icon_hover.png')
    glBillboard()
	glTranslate(0.4, 0.8, 0)
    --glTranslate(12.0, 18.0, 24.0)
    glTexRect(-iconSize/2, -iconSize/2, iconSize/2, iconSize/2)
    if text ~= nil then
        glTexture(false)
        glTranslate(iconSize/2, -iconSize/2, 0)
        --font:Begin()
        font:Print(buyPriceBoldColor..text.."m", 0.6, 1.0, textSize)
        --font:End()
    end
    glPopMatrix()
end
function widget:ViewResize(n_vsx, n_vsy)
	vsx, vsy = Spring.GetViewGeometry()
	uiScale = (0.75 + (vsx * vsy / 6000000))

	font = WG['fonts'].getFont(nil, 1.2, 0.2, 20)

	UiElement = WG.FlowUI.Draw.Element
	UiUnit = WG.FlowUI.Draw.Unit
	UiButton = WG.FlowUI.Draw.Button

    -- I'll dynamically resize it before showing it...
	uiElementRect = {
		(vsx * 0.7), vsy * 0.959 - 80,
		(vsx * 0.7) + 400, vsy * 0.959
	}
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
	glDepthTest(false)
    DrawUnitTradeInfo()
	glDepthTest(true)
end

function widget:DrawScreen()
    if notEnoughForUnit then
        local text = Spring.I18N('ui.unitMarket.notEnoughMetal')
        font:Begin()
        font:Print(text, vsx * 0.5, vsy * 0.66, 26 * uiScale, "co")
        font:End()
    end
    if not isSpectating then
        local mx, my = spGetMouseState()
        local rType, unitID = spTraceScreenRay(mx, my)
        if rType == 'unit' then
            local price = GetUnitPrice(unitID)
            local teamID = spGetUnitTeam(unitID)
            if price > 0 and spAreTeamsAllied(teamID, myTeamID) then
                hoveringOverUnitID = unitID
                drawBuyTooltip(unitID, teamID, price, mx, my)
            else
                hoveringOverUnitID = nil
            end
        else
            hoveringOverUnitID = nil
        end
        for index, data in ipairs(buyButtons) do
            local coords = data[1]
            local unitDefID = data[2]
            if math_isInRect(mx, my, coords[1], coords[2], coords[3], coords[4]) then
                drawBuyTooltipDock(unitDefID, mx, my)
            end
        end
        if t2conDockShown then
            glCallList(t2conDock)
        end
        if buyRequestDockShown then
            glCallList(buyRequestDock)
        end
    end
end

function widget:Shutdown()
    spSendLuaRulesMsg("stopSaving")
	for k,_ in pairs(drawLists) do
		glDeleteList(drawLists[k])
	end
    glDeleteList(t2conDock)
    glDeleteList(buyRequestDock)
	WG['unit_market'] = nil
end

local sec, sec2, sec3, updatePeriod = 0, 0, 0, 0.25
local prevCam = {spGetCameraDirection()}
function widget:Update(dt)
	sec = sec + dt
    sec2 = sec2 + dt
	if sec >= 0.15 then
		sec = 0
		local camX, camY, camZ = spGetCameraDirection()
		if camX ~= prevCam[1] or camY ~= prevCam[2] or camZ ~= prevCam[3] then
			for k,_ in pairs(drawLists) do
				glDeleteList(drawLists[k])
				drawLists[k] = nil
			end
		end
		prevCam = {camX,camY,camZ}
	end
    if sec2 >= updatePeriod then
        if t2conDockShown then
            t2conDockShown = false
            glDeleteList(t2conDock)
            t2conDock = nil
            DrawT2TradeDock()
            updatePeriod = 0.25
        else
            updatePeriod = 1
            -- slightly slower if we can't show it yet, maybe there are no t2 cons for sale
        end
    end

    if notEnoughForUnit and os.clock()>=notEnoughMetalTimer then
        notEnoughForUnit = nil
    end

    if triedToManullyBuyUnitID and os.clock() >= triedToBuyTime and triedToBuyFrame ~= spGetGameFrame() then
        TriedToBuyUnit()
    end
end

function widget:GameFrame(frame)
	if frame <= 0 or isSpectating then return end
    if frame == 1 then
        lastTimeT2ConsOnSale = os.clock()
        FindBestT2ConsForSale()
        DrawT2TradeDock()
    elseif (frame % 15) == 1 then
        dot_count = dot_count + 1
        if (dot_count > 3) then dot_count = 0 end

        if (FindBestT2ConsForSale()) then
            if not t2conDockShown then
                DrawT2TradeDock()
                updatePeriod = 0.25
            end
            ExecutePurchases()
        end
    end
end

function widget:GetConfigData()
    updatedSeePrices(seePrices)
	return {
		seePrices = seePrices,
        showAIsaleOffers = showAIsaleOffers,
        buyWithoutHoldingAlt = buyWithoutHoldingAlt,
		version = 1,
	}
end

function widget:SetConfigData(data)
	if data.seePrices ~= nil then
		seePrices = data.seePrices
	end
	if data.showAIsaleOffers ~= nil then
		showAIsaleOffers = data.showAIsaleOffers
	end
	if data.buyWithoutHoldingAlt ~= nil then
		buyWithoutHoldingAlt = data.buyWithoutHoldingAlt
	end
end
