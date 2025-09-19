if not RmlUi then
	return
end

local widget = widget

function widget:GetInfo()
	return {
		name = "Quick Start UI",
		desc = "Displays instant build resources and factory prompt",
		author = "SethDGamre",
		date = "2025-07",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local modOptions = Spring.GetModOptions()

if not modOptions or (modOptions.quick_start ~= "enabled" and modOptions.quick_start ~= "factory_discount" and modOptions.quick_start ~= "default") then
	return false
end

local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetMyTeamID = Spring.GetMyTeamID
local spI18N = Spring.I18N

local MODEL_NAME = "quick_start_model"
local RML_PATH = "luaui/RmlWidgets/gui_quick_start/gui_quick_start.rml"

local ENERGY_VALUE_CONVERSION_DIVISOR = 10

local widgetState = {
	rmlContext = nil,
	dmHandle = nil,
	document = nil,
	lastUpdate = 0,
	updateInterval = 0.2,
	showBar = false,
	lastQueueHash = "",
	isPaused = false,
	isDocumentVisible = true,
	hiddenByLobby = false,
	juiceBarElements = {
		fillElement = nil,
		projectedElement = nil,
	},
}

local initialModel = {
	juiceTotal = 0,
	juiceUsed = 0,
	juiceRemaining = 0,
	juicePercent = 0,
	juiceProjected = 0,
	juiceProjectedPercent = 0,
	showBar = false,
	factoryQueued = false,
	factoryDiscountUsed = false,
	factoryDiscountText = "",
	factoryDiscountTextClass = "qs-factory-text",
	quickStart = {
		preGameResources = "",
		remainingResourcesWarning = "",
		placeDiscountedFactory = "",
	},
}

local function calculateJuiceCost(unitDefID)
	local uDef = UnitDefs[unitDefID]
	if not uDef then return 0 end
	local metalCost = uDef.metalCost or 0
	local energyCost = uDef.energyCost or 0
	return metalCost + (energyCost / ENERGY_VALUE_CONVERSION_DIVISOR)
end

local function hashQueue(queue)
	if not queue or #queue == 0 then return "" end
	local h = ""
	for i = 1, math.min(#queue, 50) do
		local q = queue[i]
		h = h .. tostring(q[1]) .. ":" .. tostring(q[2]) .. ":" .. tostring(q[4]) .. ":" .. tostring(q[5]) .. "|"
	end
	return h
end

local function createJuiceBarElements()
	if not widgetState.document then 
		Spring.Echo("Quick Start: No document found")
		return 
	end
	
	local fillElement = widgetState.document:GetElementById("qs-juice-fill")
	local projectedElement = widgetState.document:GetElementById("qs-juice-projected")
	
	if fillElement and projectedElement then
		widgetState.juiceBarElements.fillElement = fillElement
		widgetState.juiceBarElements.projectedElement = projectedElement
		Spring.Echo("Quick Start: Juice bar elements created successfully")
	else
		Spring.Echo("Quick Start: Failed to find juice bar elements")
	end
end

local function computeProjectedUsage()
	local myTeamID = spGetMyTeamID()
	local juiceTotal = spGetGameRulesParam("quickStartJuiceBase") or 0
	local factoryDiscountAmount = spGetGameRulesParam("quickStartFactoryDiscountAmount") or 0
	local factoryDiscountUsed = spGetTeamRulesParam(myTeamID, "quickStartFactoryDiscountUsed") or 0
	local instantBuildRange = spGetGameRulesParam("overridePregameBuildDistance") or 600
	local pregame = WG and WG["pregame-build"] and WG["pregame-build"].getBuildQueue and WG["pregame-build"].getBuildQueue() or {}
	local pregameUnitSelected = WG["pregame-unit-selected"] or -1

	local juiceUsed = 0
	local firstFactoryPlaced = false
	local shouldApplyDiscount = modOptions.quick_start == "factory_discount"
	
	local commanderX, commanderY, commanderZ = Spring.GetTeamStartPosition(myTeamID)
	if not commanderX or not commanderZ then
		commanderX, commanderY, commanderZ = 0, 0, 0
	end

	if pregame and #pregame > 0 then
		for i = 1, #pregame do
			local item = pregame[i]
			local defID = item[1]
			if defID and defID > 0 then
				local uDef = UnitDefs[defID]
				if uDef then
					local buildX, buildZ = item[2], item[4]
					local distance = math.distance2d(commanderX, commanderZ, buildX, buildZ)
					
					if distance <= instantBuildRange then
						local juiceCost = calculateJuiceCost(defID)
						
						if uDef.isFactory then
							if not firstFactoryPlaced then
								firstFactoryPlaced = true
								if shouldApplyDiscount then
									juiceUsed = juiceUsed + math.max(0, juiceCost - factoryDiscountAmount)
								else
									juiceUsed = juiceUsed + juiceCost
								end
							else
								juiceUsed = juiceUsed + juiceCost
							end
						else
							juiceUsed = juiceUsed + juiceCost
						end
					end
				end
			end
		end
	end

	local juiceProjected = 0
	if pregameUnitSelected and pregameUnitSelected > 0 then
		local uDef = UnitDefs[pregameUnitSelected]
		if uDef then
			local mx, my = Spring.GetMouseState()
			local _, pos = Spring.TraceScreenRay(mx, my, true, false, false, uDef.modCategories and uDef.modCategories.underwater)
			if pos then
				local buildFacing = Spring.GetBuildFacing()
				local bx, by, bz = Spring.Pos2BuildPos(pregameUnitSelected, pos[1], pos[2], pos[3], buildFacing)
				local distance = math.distance2d(commanderX, commanderZ, bx, bz)
				
				if distance <= instantBuildRange then
					local juiceCost = calculateJuiceCost(pregameUnitSelected)
					
					if uDef.isFactory and not firstFactoryPlaced then
						if shouldApplyDiscount then
							juiceProjected = math.max(0, juiceCost - factoryDiscountAmount)
						else
							juiceProjected = juiceCost
						end
					else
						juiceProjected = juiceCost
					end
				end
			end
		end
	end

	local juiceRemaining = math.max(0, juiceTotal - juiceUsed)
	local percent = juiceTotal > 0 and math.max(0, math.min(100, (juiceRemaining / juiceTotal) * 100)) or 0
	local projectedPercent = juiceTotal > 0 and math.max(0, math.min(100, (juiceProjected / juiceTotal) * 100)) or 0

	return {
		juiceTotal = juiceTotal,
		juiceUsed = juiceUsed,
		juiceRemaining = juiceRemaining,
		juicePercent = percent,
		juiceProjected = juiceProjected,
		juiceProjectedPercent = projectedPercent,
		factoryQueued = false,
		factoryDiscountUsed = factoryDiscountUsed == 1,
	}
end

local function updateDataModel(force)
	if not widgetState.dmHandle then return end

	local queue = WG and WG["pregame-build"] and WG["pregame-build"].getBuildQueue and WG["pregame-build"].getBuildQueue() or {}
	local newHash = hashQueue(queue)
	if not force and widgetState.lastQueueHash == newHash and (os.clock() - widgetState.lastUpdate) < widgetState.updateInterval then
		return
	end
	widgetState.lastQueueHash = newHash
	widgetState.lastUpdate = os.clock()

	local modelUpdate = computeProjectedUsage()
	widgetState.dmHandle.juiceTotal = modelUpdate.juiceTotal
	widgetState.dmHandle.juiceUsed = modelUpdate.juiceUsed
	widgetState.dmHandle.juiceRemaining = modelUpdate.juiceRemaining
	widgetState.dmHandle.juicePercent = modelUpdate.juicePercent
	widgetState.dmHandle.juiceProjected = modelUpdate.juiceProjected
	widgetState.dmHandle.juiceProjectedPercent = modelUpdate.juiceProjectedPercent
	widgetState.dmHandle.factoryQueued = modelUpdate.factoryQueued
	widgetState.dmHandle.factoryDiscountUsed = modelUpdate.factoryDiscountUsed

	if widgetState.document then
		local juicePercent = widgetState.dmHandle.juicePercent or 0
		if widgetState.juiceBarElements.fillElement then
			widgetState.juiceBarElements.fillElement:SetAttribute("style", "width: " .. string.format("%.1f%%", juicePercent))
		end

		if widgetState.juiceBarElements.projectedElement then
			local juiceProjectedPercent = widgetState.dmHandle.juiceProjectedPercent or 0
			local overlayWidth = math.min(juiceProjectedPercent, juicePercent)
			local overlayLeft = math.max(0, juicePercent - overlayWidth)
			local style = string.format("left: %.1f%%; width: %.1f%%;", overlayLeft, overlayWidth)
			widgetState.juiceBarElements.projectedElement:SetAttribute("style", style)
		end

		local juiceRemaining = widgetState.document:GetElementById("qs-juice-remaining")
		local juiceTotal = widgetState.document:GetElementById("qs-juice-total")
		
		if juiceRemaining then juiceRemaining.inner_rml = tostring(math.floor(widgetState.dmHandle.juiceRemaining or 0)) end
		if juiceTotal then juiceTotal.inner_rml = tostring(math.floor(widgetState.dmHandle.juiceTotal or 0)) end

	end
end

function widget:Initialize()
	Spring.Echo("Quick Start: Initializing widget")
	
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then 
		Spring.Echo("Quick Start: Failed to get RML context")
		return false 
	end

	local dm = widgetState.rmlContext:OpenDataModel(MODEL_NAME, initialModel, self)
	if not dm then 
		Spring.Echo("Quick Start: Failed to open data model")
		return false 
	end
	widgetState.dmHandle = dm

	widgetState.showBar = true
	widgetState.dmHandle.showBar = widgetState.showBar


	local document = widgetState.rmlContext:LoadDocument(RML_PATH)
	if not document then
		Spring.Echo("Quick Start: Failed to load document")
		widget:Shutdown()
		return false
	end
	widgetState.document = document
	document:Show()
	Spring.Echo("Quick Start: Document loaded and shown")

	local juiceHeader = document:GetElementById("qs-juice-header")
	local warningText = document:GetElementById("qs-warning-text")
	local factoryText = document:GetElementById("qs-factory-text")
	
	if juiceHeader then
		juiceHeader.inner_rml = spI18N('ui.quickStart.preGameResources')
	end
	if warningText then
		warningText.inner_rml = spI18N('ui.quickStart.remainingResourcesWarning')
	end
	if factoryText then
		factoryText.inner_rml = spI18N('ui.quickStart.placeDiscountedFactory')
	end

	createJuiceBarElements()

	updateDataModel(true)
	Spring.Echo("Quick Start: Widget initialized successfully")
	return true
end

function widget:Shutdown()
	if widgetState.rmlContext and widgetState.dmHandle then
		widgetState.rmlContext:RemoveDataModel(MODEL_NAME)
		widgetState.dmHandle = nil
	end
	if widgetState.document then
		widgetState.document:Close()
		widgetState.document = nil
	end
	widgetState.rmlContext = nil
end

function widget:Update()
	local gameFrame = Spring.GetGameFrame()
	if gameFrame > 0 then
		widgetHandler:RemoveWidget(self)
		return
	end
	updateDataModel(false)
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 19) == 'LobbyOverlayActive0' then
		if widgetState.document then
			if not widgetState.isDocumentVisible then
				widgetState.document:Show()
				widgetState.isDocumentVisible = true
			end
			widgetState.hiddenByLobby = false
		end
	elseif msg:sub(1, 19) == 'LobbyOverlayActive1' then
		if widgetState.document then
			if widgetState.isDocumentVisible then
				widgetState.document:Hide()
				widgetState.isDocumentVisible = false
			end
			widgetState.hiddenByLobby = true
		end
	end
end