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
-- Note: you can set for sale ANYTHING as long as its a finished unit. Hotkey to toggle sale. Just alt + double-click to buy.
-- TODO: develop UI so that you can browse units that are for sale with a buy button maybe?
-- TODO: maybe a button in a unitstate window "this unit is for sale" toggle so you can start selling units without hotkey?
-- But as it is, it should be fine for the first version.

-- How to use:

-- As a seller:
-- 1) select units and do a) or b) or c):
-- a) write in chat: /luaui sell_unit
-- b) write in chat: /sell_unit
-- c) bind a hotkey before hand: bind alt+c /sell_unit, then just press the hotkey to toggle sellable status.
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
local spIsUnitInView        = Spring.IsUnitInView
local spGetPlayerList       = Spring.GetPlayerList
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spTraceScreenRay      = Spring.TraceScreenRay
local spGetUnitsInCylinder  = Spring.GetUnitsInCylinder
local spGetModKeyState      = Spring.GetModKeyState
local spGetUnitRulesParam  	= Spring.GetUnitRulesParam
local spSetUnitRulesParam   = Spring.SetUnitRulesParam
local myTeamID     = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local gaiaTeamID   = Spring.GetGaiaTeamID()
local isSpectating = Spring.GetSpectatingState() == true

local unitMarket = Spring.GetModOptions().unit_market
local unitsForSale = {} -- Array to store units offered for sale {UnitID => metalCost}

local function InitFindSales()
    for _, unitID in ipairs(Spring.GetAllUnits()) do
        if spValidUnitID(unitID) then
            teamID = spGetUnitTeam(unitID)
            if isSpectating or spAreTeamsAllied(teamID, myTeamID) then
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
	InitFindSales()
end

function widget:PlayerChanged(playerID)
	if spGetSpectatingState() ~= isSpectating then
		isSpectating = spGetSpectatingState()
		InitFindSales()
	end
end

function OfferToSell(unitID)
    spSendLuaRulesMsg("unitOfferToSell " .. unitID) -- Tell gadget we are offering unit for sale
end
function OfferToBuy(unitID)
    spSendLuaRulesMsg("unitTryToBuy " .. unitID) -- Tell gadget we are buying (or trying to)
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
        if selectedUnits == nil or #selectedUnits <= 0 then return end

        local anyUnitForSale = false -- Flag to check if any selected unit are already on sale
        for _, unitID in ipairs(selectedUnits) do
            if unitsForSale[unitID] then
                anyUnitForSale = true -- If they are we are going to remove sale status on them
                OfferToSell(unitID)
            end
        end
        -- If none of the selected units are on sale, call OfferToSell to set all of them on sale
        if not anyUnitForSale then
            for _, unitID in ipairs(selectedUnits) do
                OfferToSell(unitID)
            end
        end
    end
end

function ClearUnitData(unitID)
    -- if unit is no longer sold then remove it from being sold
    unitsForSale[unitID] = nil
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

function widget:RecvLuaMsg(msg, playerID)
    local msgFromTeamID = select(4,spGetPlayerInfo(playerID))

    -- ignore messages from enemies unless you are spec
    if not (isSpectating or spAreTeamsAllied(msgFromTeamID, myTeamID)) then return end

    local words = {}
    for word in msg:gmatch("%S+") do
        table.insert(words, word)
    end

    if words[1] == "unitForSale" then
        --Spring.Echo(words) -- debug
        local unitID = tonumber(words[2])
        local selling = tonumber(words[3])
        local unitDefID = spGetUnitDefID(unitID)
        if not unitDefID then return end
        local unitDef = UnitDefs[unitDefID]
        if not unitDef then return end
        local name,_ = spGetPlayerInfo(playerID, false)
        if selling > 0 then
            unitsForSale[unitID] = unitDef.metalCost
            spEcho(name.." is selling "..unitDef.translatedHumanName.." for "..unitDef.metalCost.." metal.")
        else
            ClearUnitData(unitID)
        end
    elseif words[1] == "unitSold" then
        --Spring.Echo(words) -- debug
        local unitID = tonumber(words[2])
        local price  = tonumber(words[3])
        ClearUnitData(unitID)
        local old_ownerID = FindPlayerIDFromTeamID(tonumber(words[4]))
        local new_ownerID = FindPlayerIDFromTeamID(tonumber(words[5]))
        if (old_ownerID and new_ownerID) then
            local owner_name = select(1,spGetPlayerInfo(new_ownerID, false)) or "unknown"
            local old_owner_name = select(1,spGetPlayerInfo(old_ownerID, false)) or "unknown"
            spEcho(old_owner_name.." sold "..unitDef.translatedHumanName.." for "..price.." metal to "..owner_name..".")
        end
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	ClearUnitData(unitID)
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	ClearUnitData(unitID)
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	ClearUnitData(unitID)
end

--function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	--ClearUnitData(unitID)
--end

-------------------------------------------------------- UI code ---
local doubleClickTime = 1 -- Maximum time in seconds between two clicks for them to be considered a double-click
local maxDistanceForDoubleClick = 10 -- Maximum distance between two clicks for them to be considered a double-click
local rangeBuy = 30 -- Maximum range for units to buy over a double-click.

local lastClickCoords = nil
local lastClickTime = nil

function widget:MousePress(mx, my, button)
    local alt, ctrl, meta, shift = spGetModKeyState()
    if alt and not isSpectating then
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
                        --
                    end
                end
                -- Store the current click as the last click
                lastClickCoords = coords
                lastClickTime = currentTime
            end
        end
    end
end

local spIsGUIHidden = Spring.IsGUIHidden
local animationDuration = 7
local animationFrequency = 3
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

            local yellow	= {1.0, 1.0, 0.3, 0.66}
            gl.PushMatrix()
            gl.Translate(ux, uy, uz)
            gl.Billboard()
            gl.Color(yellow)
            gl.BeginText()
            gl.Text("$", 12.0, 15.0, 24.0)
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
