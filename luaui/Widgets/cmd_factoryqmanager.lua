include("keysym.h.lua")
local versionNumber = 1.4

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "FactoryQ Manager",
		desc = "Saves and Loads Factory Queues. Load: Meta+[0-9], Save: Alt+Meta+[0-9] (v" .. string.format("%.1f", versionNumber) .. ")",
		author = "very_bad_soldier",
		date = "Jul 6, 2008",
		license = "GNU GPL, v2 or later",
		layer = -9000,
		enabled = false
	}
end

--Changelog
--1.4: fixed text alignment, changed layer cause other widgets are eating events otherwise (e.g. smartselect)
--1.3: fixed for 0.83
--1.21:
--added: Press Meta+C to clear currently selected factories queue
--added: some speedups, but its still quite hungry will displaying menu

--1.2:
--added: "Repeat"-State gets saved. Repeating queues show up as green preset number labels, non-repeated in gray as usual
--added: Queues can be loaded by left-clicking on the preset box
--added: Queues get saved for each mod seperately


local vsx, vsy = Spring.GetViewGeometry()

local iboxOuterMargin = 3
local iboxWidth = 298
local iboxHeight = 40
local iboxHeightTitle = 50
local iboxIconBorder = 3
local ifontSizeTitle = 16
local ifontSizeGroup = 16
local ifontSizeUnitCount = 12
local ifontSizeModifed = 28
local iunitIconSpacing = 5
local ifontModifiedYOff = 16
local igroupLabelMargin = 30
local ititleTextXOff = 10
local ititleTextYOff = 10
local iunitCountXOff = 10.0
local iunitCountYOff = 5.0
local idrawY = 650

local igroupLabelXOff = 17
local igroupLabelYOff = 10

local drawFadeTime = 0.5
local loadedBorderDisplayTime = 1.0

--------------------------------------------------------------------------------
--INTERNAL USE
--------------------------------------------------------------------------------

local alpha = 0.0
local modifiedSaved = nil
local modifiedGroup = nil
local modifiedGroupTime = nil
local defaultScreenResY = 960  --dont change it, its just to keep the same absolute size i had while developing
local savedQueues = {}
local drawX = nil
local facRepeatIdx = "facq_repeat"
local lastBoxX = nil
local lastBoxY = nil
local boxCoords = {}
local curModId = nil

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local boxWidth
local boxHeight
local boxHeightTitle
local boxIconBorder

local fontSizeTitle
local fontSizeGroup
local fontSizeUnitCount
local fontSizeModifed

local unitIconSpacing
local fontModifiedYOff

local groupLabelXOff
local groupLabelYOff

local groupLabelMargin
local boxOuterMargin

local titleTextYOff
local titleTextXOff

local unitCountXOff
local unitCountYOff

local drawY
local printDebug
local calcScreenCoords
local RemoveBuildOrders
local getButtonUnderMouse
local ClearFactoryQueues
local getSingleFactory
local saveQueue
local loadQueue
local DrawBoxes
local DrawBoxGroup
local DrawBoxTitle
local SortQueueToUnits
local CalcDrawCoords
local UiUnit, UiElement

local spEcho = Spring.Echo
local spGetModKeyState = Spring.GetModKeyState
local lastGameSeconds = Spring.GetGameSeconds()

local font, gameStarted, selUnits

local udefTab = {}
local isFactory = {}
--local unitId = {}
for udid, ud in pairs(UnitDefs) do
	--unitId[udid] = ud.id
	if ud.isFactory then
		isFactory[udid] = true
		udefTab[udid] = ud
	end
end

function calcScreenCoords()
	vsx, vsy = widgetHandler:GetViewSizes()

	local factor = vsy / defaultScreenResY

	boxWidth = math.floor(iboxWidth * factor + 0.5)
	boxHeight = math.floor(iboxHeight * factor + 0.5)
	boxHeightTitle = math.floor(iboxHeightTitle * factor + 0.5)
	boxIconBorder = math.floor(iboxIconBorder * factor + 0.5)

	fontSizeTitle = math.floor(ifontSizeTitle * factor + 0.5)
	fontSizeGroup = math.floor(ifontSizeGroup * factor + 0.5)
	fontSizeUnitCount = math.floor(ifontSizeUnitCount * factor + 0.5)
	fontSizeModifed = math.floor(ifontSizeModifed * factor + 0.5)

	unitIconSpacing = math.floor(iunitIconSpacing * factor + 0.5)
	fontModifiedYOff = math.floor(ifontModifiedYOff * factor + 0.5)

	groupLabelXOff = math.floor(igroupLabelXOff * factor + 0.5)
	groupLabelYOff = math.floor(igroupLabelYOff * factor + 0.5)

	groupLabelMargin = math.floor(igroupLabelMargin * factor + 0.5)
	boxOuterMargin = math.floor(iboxOuterMargin * factor + 0.5)

	titleTextYOff = math.floor(ititleTextYOff * factor + 0.5)
	titleTextXOff = math.floor(ititleTextXOff * factor + 0.5)

	unitCountXOff = math.floor(iunitCountXOff * factor + 0.5)
	unitCountYOff = math.floor(iunitCountYOff * factor + 0.5)

	drawY = math.floor(idrawY * factor + 0.5)

	drawX = vsx - boxWidth
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()

	font = WG['fonts'].getFont(1, 1.6)

	UiUnit = WG.FlowUI.Draw.Unit
	UiElement = WG.FlowUI.Draw.Element

	calcScreenCoords()
end

function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
	end
end

function widget:GameStart()
	gameStarted = true
	maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
	maybeRemoveSelf()
end

function widget:Initialize()
	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		maybeRemoveSelf()
	end
	widget:ViewResize()

	curModId = string.upper(Game.gameShortName or "")
end

-- Included FactoryClear Lua widget
function RemoveBuildOrders(unitID, buildDefID, count)
	local opts = {}
	while (count > 0) do
		if count >= 100 then
			opts = { "right", "ctrl", "shift" }
			count = count - 100
		elseif count >= 20 then
			opts = { "right", "ctrl" }
			count = count - 20
		elseif count >= 5 then
			opts = { "right", "shift" }
			count = count - 5
		else
			opts = { "right" }
			count = count - 1
		end
		Spring.GiveOrderToUnit(unitID, -buildDefID, {}, opts)
	end
end

function getButtonUnderMouse(mx, my)
	local x1 = boxCoords["x"]
	if x1 == nil then
		return
	end
	local x2 = x1 + boxWidth
	local y1, y2
	for groupNo, ycoord in pairs(boxCoords) do
		if type(groupNo) == "number" then
			y1 = ycoord
			y2 = y1 - boxHeight

			if mx >= x1 and mx <= x2 and my <= y1 and my >= y2 then
				return groupNo
			end
		end
	end
	return nil
end

function widget:MousePress(x, y, button)
	--1 LMB, 3 RMB
	if button ~= 1 and button ~= 3 then
		return false
	end

	local btn = getButtonUnderMouse(x, y)
	if btn == nil then
		return false
	end

	local selUnit, unitDef = getSingleFactory()

	if button == 1 then
		--LMB
		loadQueue(selUnit, unitDef, btn)
	elseif button == 3 then
		--RMB
		--saving disabled
		return false
		--	saveQueue(selUnit, unitDef, btn)
	end

	return true
end

function ClearFactoryQueues()
	local udTable = Spring.GetSelectedUnitsSorted()
	for udidFac, uTable in pairs(udTable) do
		if isFactory[udidFac] then
			for _, uid in ipairs(uTable) do
				local queue = Spring.GetRealBuildQueue(uid)
				if queue ~= nil then
					for udid, buildPair in ipairs(queue) do
						local udid, count = next(buildPair, nil)
						RemoveBuildOrders(uid, udid, count)
					end
				end
			end
		end
	end
end
-- End of Included FactoryClear Lua widget

function getSingleFactory()
	selUnits = Spring.GetSelectedUnits()

	--only do something when exactly ONE factory is selected to avoid execution by mistake
	if #selUnits ~= 1 then
		return nil, nil
	end

	local unitDefID = Spring.GetUnitDefID(selUnits[1])
	if not isFactory[unitDefID] then
		return nil, nil
	else
		local unitDef = udefTab[unitDefID]
		return selUnits[1], unitDef
	end
end

function saveQueue(unitId, unitDef, groupNo)
	local unitQ = Spring.GetFactoryCommands(unitId, -1)
	if #unitQ <= 0 then
		--queue is empty -> signal to delete preset
		savedQueues[curModId][unitDef.id][groupNo] = nil
		return
	end

	if savedQueues[curModId] == nil then
		savedQueues[curModId] = {}
	end
	if savedQueues[curModId][unitDef.id] == nil then
		savedQueues[curModId][unitDef.id] = {}
	end

	savedQueues[curModId][unitDef.id][groupNo] = unitQ
	savedQueues[curModId][unitDef.id][groupNo][facRepeatIdx] = select(4, Spring.GetUnitStates(unitId, false, true))    -- 4=repeat

	modifiedGroup = groupNo
	modifiedGroupTime = Spring.GetGameSeconds()
	modifiedSaved = true

	--force box coords table refresh
	lastBoxX = nil
	lastBoxY = nil
end

function loadQueue(unitId, unitDef, groupNo)
	if savedQueues[curModId][unitDef.id] == nil then
		--there are no queus for this factory type
		return
	end

	local queue = savedQueues[curModId][unitDef.id][groupNo]
	if queue ~= nil and #queue > 0 then
		ClearFactoryQueues()
		modifiedGroup = groupNo
		modifiedGroupTime = Spring.GetGameSeconds()
		modifiedSaved = false

		--set factory to repeat on/off
		local repVal = 1
		if queue[facRepeatIdx] == false then
			repVal = 0
		end
		Spring.GiveOrderToUnit(unitId, CMD.REPEAT, { repVal }, 0)

		for i = 1, #queue do
			local cmd = queue[i]
			if not cmd.options.internal then
				local opts = {}
				Spring.GiveOrderToUnit(unitId, cmd.id, cmd.params, opts)
			end
		end
	end
end

function widget:KeyPress(key, modifier, isRepeat)
	local mode = nil
	local selUnit, unitDef = getSingleFactory()

	if selUnit == nil and unitDef == nil then
		return false
	end

	if modifier.meta and modifier.alt then
		mode = 1 --write
	elseif (modifier.meta) then
		mode = 2 --read

		if key == KEYSYMS.C then
			ClearFactoryQueues()
		end
	else
		return false
	end

	--asert(mode ~= nil)
	local gr = -2
	if key == KEYSYMS.N_0 then
		gr = 0
	end
	if key == KEYSYMS.N_1 then
		gr = 1
	end
	if key == KEYSYMS.N_2 then
		gr = 2
	end
	if key == KEYSYMS.N_3 then
		gr = 3
	end
	if key == KEYSYMS.N_4 then
		gr = 4
	end
	if key == KEYSYMS.N_5 then
		gr = 5
	end
	if key == KEYSYMS.N_6 then
		gr = 6
	end
	if key == KEYSYMS.N_7 then
		gr = 7
	end
	if key == KEYSYMS.N_8 then
		gr = 8
	end
	if key == KEYSYMS.N_9 then
		gr = 9
	end
	--if key == KEYSYMS.BACKSLASH then gr = -1 end

	if gr ~= -2 then
		if mode == 1 then
			saveQueue(selUnit, unitDef, gr)
		elseif mode == 2 then
			loadQueue(selUnit, unitDef, gr)
		end
	end

	return true;
end

function CalcDrawCoords(unitId, heightAll)
	local xw, yw, zw = Spring.GetUnitViewPosition(unitId)
	local x, y, _ = Spring.WorldToScreenCoords(xw, yw, zw)

	if x + boxWidth - 1 > vsx then
		x = x - boxWidth
	end
	if y - heightAll < 0 then
		y = y + heightAll
	end

	local staticPos = false
	if x < 0 or x + boxWidth > vsx then
		staticPos = true
	end

	if y - heightAll < 0 or y > vsy then
		staticPos = true
	end

	if staticPos then
		y = drawY
		x = drawX
	end

	return x, y
end

function DrawBoxTitle(x, y, alpha, unitDef, selUnit)
	UiElement(x, y - boxHeightTitle, x + boxWidth, y, 1,1,1,0, 1,1,0,1, math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))
	gl.Color(1, 1, 1, 1)

	UiUnit(
		x + boxIconBorder, y - boxHeightTitle + boxIconBorder, x + boxHeightTitle, y - boxIconBorder,
		nil,
		1,1,1,1,
		0.08,
		nil, nil,
		'#'..unitDef.id
	)
	local text = unitDef.translatedHumanName

	font:Begin()
	font:SetTextColor(0, 1, 0, alpha or 1)
	font:Print(text, x + boxHeightTitle + titleTextXOff, y - boxHeightTitle / 2.0 - titleTextYOff, fontSizeTitle, "nd0")
	font:End()
end

function SortQueueToUnits(queue)
	local units = {}
	for i = 1, #queue do
		local entity = queue[i]
		if type(entity) == "table" then
			if entity.id < 0 then
				local idx = -1 * entity.id
				local newVal = 1
				if units[idx] ~= nil then
					newVal = units[idx] + 1
				end
				units[idx] = newVal
			end
		end
	end
	return units
end

function DrawBoxGroup(x, y, yOffset, unitDef, selUnit, alpha, groupNo, queue)
	local xOff = 0
	local loadedBorderWidth = 1

	--if units == nil then
	local units = SortQueueToUnits(queue)
	--end
	--Draw "loaded" border
	if modifiedGroup == groupNo and modifiedGroupTime > Spring.GetGameSeconds() - loadedBorderDisplayTime then
		if modifiedSaved == true then
			gl.Color(1, 0, 0, math.min(alpha, 1.0))
		else
			gl.Color(0, 1, 0, math.min(alpha, 1.0))
		end
		gl.Rect(x - loadedBorderWidth, y + loadedBorderWidth, x + boxWidth + loadedBorderWidth, y - boxHeight - loadedBorderWidth)
	end

	--Draw Background Box
	UiElement(x, y - boxHeight, x + boxWidth, y, 0,1,1,1, 1,1,1,1, math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))
	--UiElement(x + boxIconBorder, y - boxHeight + 3, x + groupLabelMargin, y - 3, 1, 1, 1, 1)
	--gl.Color(0, 0, 0, math.min(alpha, 0.6))
	--gl.Rect(x, y, x + boxWidth, y - boxHeight)
	--if queue[facRepeatIdx] == nil or queue[facRepeatIdx] == true then
	--	gl.Color(0.0, 0.7, 0.0, math.min(alpha or 1, 0.5))
	--else
	--	gl.Color(0.7, 0.7, 0.7, math.min(alpha or 1, 0.5))
	--end
	--gl.Rect(x + boxIconBorder, y - 3, x + groupLabelMargin, y - boxHeight + 3)

	font:Begin()
	--Draw group Label
	font:SetTextColor(1.0, 0.5, 0, alpha or 1)
	font:Print(groupNo, x + groupLabelXOff, y - boxHeight / 2.0 - groupLabelYOff, fontSizeGroup, "cdn")
	xOff = xOff + groupLabelMargin

	for k, unitCount in pairs(units) do
		if x + boxHeight + boxIconBorder + xOff + boxHeight + unitIconSpacing > x + boxWidth then
			font:SetTextColor(1, 1, 1, alpha)
			font:Print("...", x + xOff + unitCountXOff, y - boxHeight + unitCountYOff, fontSizeUnitCount, "nd")
			break
		else
			gl.Color(0.8,0.8,0.8 ,1)
			UiUnit(
				x + boxIconBorder + xOff, y - boxHeight + boxIconBorder, x + boxHeight - boxIconBorder + xOff, y - boxIconBorder,
				nil,
				1,1,1,1,
				0.08,
				nil, nil,
				'#'..k
			)
			font:SetTextColor(1, 1, 1, alpha)
			font:Print(unitCount, x + (boxHeight*0.5) - boxIconBorder + xOff, y - boxHeight + unitCountYOff, fontSizeUnitCount, "cndo")
		end
		xOff = xOff + boxHeight - boxIconBorder - boxIconBorder + unitIconSpacing
	end

	--draw "loaded" text
	if modifiedGroup == groupNo and modifiedGroupTime > Spring.GetGameSeconds() - loadedBorderDisplayTime then
		local lText = "Loaded"
		if modifiedSaved == true then
			lText = "Saved"
		end
		font:SetTextColor(0.9, 0.9, 0.9, alpha)
		font:Print(lText, x + (boxWidth + 0.5) / 2, y - (boxHeight + 0.5) / 2 - fontModifiedYOff, fontSizeModifed, "cnd")
	end
	font:End()
	gl.Color(1, 1, 1, 1)
end

function DrawBoxes()
	local selUnit, unitDef = getSingleFactory()
	if selUnit == nil and unitDef == nil then
		return
	end

	local itemCount = 0
	if savedQueues[curModId] ~= nil and savedQueues[curModId][unitDef.id] ~= nil then
		itemCount = #savedQueues[curModId][unitDef.id]
	end
	local heightAll = boxHeightTitle + itemCount * (boxHeight + boxOuterMargin)

	local x, y, z = CalcDrawCoords(selUnit, heightAll)

	local coordsChanged = false
	if x ~= lastBoxX or y ~= lastBoxY then
		coordsChanged = true
	end
	lastBoxY = y
	lastBoxX = x

	DrawBoxTitle(x, y, alpha, unitDef, selUnit)

	if savedQueues[curModId] == nil or savedQueues[curModId][unitDef.id] == nil then
		return
	end

	--save box x coord
	boxCoords.x = x

	local yOffset = 0
	local k = 1
	local first = true
	while (k < 10) do
		local q = savedQueues[curModId][unitDef.id][k]
		if q ~= nil then
			local height = boxHeight
			if first == true then
				height = boxHeightTitle
			end
			yOffset = yOffset - height
			DrawBoxGroup(x, y + yOffset, yOffset, unitDef, selUnit, alpha, k, savedQueues[curModId][unitDef.id][k])
			first = false
		end

		--update box coord table if needed
		if coordsChanged == true then
			if q == nil then
				boxCoords[k] = nil
			else
				boxCoords[k] = y + yOffset
			end
		end

		if k == 0 then
			break
		elseif k == 9 then
			k = 0
		else
			k = k + 1
		end
	end

end

function widget:Update()
	local now = Spring.GetGameSeconds()
	local timediff = now - lastGameSeconds

	if select(3, spGetModKeyState()) then
		-- meta (space)
		if alpha < 1.0 then
			alpha = alpha + timediff / drawFadeTime
			alpha = math.min(1.0, alpha)
		end
		--drawLastKeyTime = now
	else
		if alpha > 0.0 then
			alpha = alpha - timediff / drawFadeTime
			alpha = math.max(0.0, alpha)
		end
	end

	lastGameSeconds = now
end

function widget:DrawScreen()
	if alpha > 0.0 then
		DrawBoxes()
	else
		boxCoords = {}
		--force box coords table refresh
		lastBoxX = nil
		lastBoxY = nil
	end
end

--save / load to config file
function widget:GetConfigData()
	return savedQueues
end

function widget:SetConfigData(data)
	if data ~= nil then
		savedQueues = data
	end
end

function printDebug(value)
	if debug then
		if type(value) == "boolean" then
			if value == true then
				spEcho("true")
			else
				spEcho("false")
			end
		elseif type(value) == "table" then
			spEcho("Dumping table:")
			for key, val in pairs(value) do
				spEcho(key, val)
			end
		else
			spEcho(value)
		end
	end
end
