-- SPDX-License-Identifier: GPL-2.0-or-later
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Map region view bounds",
		desc = "Map region selector and cropped world/minimap views",
		author = "gajop",
		license = "GNU GPL, v2 or later",
		layer = 9999,
		enabled = true,
		handler = true,
	}
end

if not (Engine.FeatureSupport and Engine.FeatureSupport.mapRegionViews) then
	return false
end

local mapRegions = VFS.Include("common/map_regions.lua")
if not mapRegions then
	return false
end

local BUTTON_WIDTH = 240
local BUTTON_RIGHT_MARGIN = 14
local BUTTON_HEIGHT = 34
local BUTTON_GAP = 3
local SELECTOR_TOP = 0.65 -- fraction of the screen height
local FONT_SIZE = 14

local regions = mapRegions.regions
local activeRegion, ready = 1, false
local myTeamID = Spring.GetMyTeamID()
local cameraStates = {}
---@type table?, integer?
local pendingCamera, cameraDrawFrame
local buttons = {}
local menuVisible = #regions > 1
local labelsDirty = true
local unitRegions = {}
local counts = {}
local tooltip

local function ContainsUnit(unitID)
	local x, _, z = Spring.GetUnitPosition(unitID)
	return mapRegions.ContainsObject(activeRegion, x, z)
end

local function SetRegionView(regionID, cameraState)
	if not regions[regionID] then
		return false
	end
	if ready then
		cameraStates[activeRegion] = Spring.GetCameraState()
	end
	activeRegion = regionID
	labelsDirty = true
	local r = regions[regionID]
	WG.MapRegionView = {
		region = regionID,
		rect = r,
		ContainsUnit = ContainsUnit,
		SetRegion = SetRegionView,
	}
	if WG.DelaySmoothCam then
		WG.DelaySmoothCam(0.5)
	end
	Spring.SetCameraBounds(r.x0, r.z0, r.x1, r.z1)
	Spring.SetMiniMapView(r.x0, r.z0, r.x1, r.z1)
	Spring.SetWorldDrawBounds(r.x0, r.z0, r.x1, r.z1)
	if Engine.FeatureSupport.objectDrawBounds then
		local bounds = mapRegions.objectBounds[regionID]
		Spring.SetObjectDrawBounds(bounds.x0, bounds.z0, bounds.x1, bounds.z1)
	end
	widgetHandler:ParallelWorldShift()
	local x, z = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
	pendingCamera = cameraState
		or cameraStates[regionID]
		or {
			name = "ta",
			mode = 1,
			px = x,
			py = Spring.GetGroundHeight(x, z),
			pz = z,
			height = math.max(r.width, r.height) * 1.17,
			angle = 0.05,
			flipped = 0,
		}
	cameraDrawFrame = Spring.GetDrawFrame() + 1
	return true
end

local function NextRegion()
	if #regions < 2 then
		return false
	end
	SetRegionView(activeRegion % #regions + 1)
	return true
end

-- The gadget's rules param also covers units created in a separating strip.
local function UnitRegion(unitID)
	local regionID = Spring.GetUnitRulesParam(unitID, "map_region")
	if regions[regionID] then
		return regionID
	end
	local x, _, z = Spring.GetUnitPosition(unitID)
	return mapRegions.ObjectRegion(x, z)
end

local function AddUnit(unitID)
	if unitRegions[unitID] then
		return
	end
	local regionID = UnitRegion(unitID)
	if regionID then
		unitRegions[unitID] = regionID
		counts[regionID] = counts[regionID] + 1
		labelsDirty = true
	end
end

local function RemoveUnit(unitID)
	local regionID = unitRegions[unitID]
	if regionID then
		unitRegions[unitID] = nil
		counts[regionID] = counts[regionID] - 1
		labelsDirty = true
	end
end

local function RecountUnits()
	unitRegions = {}
	for regionID in ipairs(regions) do
		counts[regionID] = 0
	end
	for _, unitID in ipairs(Spring.GetTeamUnits(myTeamID) or {}) do
		AddUnit(unitID)
	end
	labelsDirty = true
end

local function LayoutButtons(vsx, vsy)
	local top = vsy * SELECTOR_TOP
	for regionID in ipairs(regions) do
		local button = buttons[regionID] or { region = regionID }
		button.x0 = vsx - BUTTON_RIGHT_MARGIN - BUTTON_WIDTH
		button.x1 = vsx - BUTTON_RIGHT_MARGIN
		button.y0 = top - regionID * BUTTON_HEIGHT
		button.y1 = top - (regionID - 1) * BUTTON_HEIGHT - BUTTON_GAP
		buttons[regionID] = button
	end
end

local function UpdateLabels()
	for regionID, button in ipairs(buttons) do
		local active = regionID == activeRegion
		button.active = active
		button.label = (active and "> " or "") .. regions[regionID].name .. " (" .. counts[regionID] .. ")"
	end
	labelsDirty = false
end

local function ButtonAt(x, y)
	for _, button in ipairs(buttons) do
		if x >= button.x0 and x <= button.x1 and y >= button.y0 and y <= button.y1 then
			return button
		end
	end
end

function widget:Initialize()
	activeRegion = mapRegions.TeamHome(myTeamID) or 1
	tooltip = BAR.I18N("ui.mapRegions.tooltip")
	LayoutButtons(Spring.GetViewGeometry())
	RecountUnits()
	widgetHandler.actionHandler:AddAction(self, "map_region_next", NextRegion, nil, "p")
end

function widget:ViewResize(vsx, vsy)
	LayoutButtons(vsx, vsy)
end

function widget:PlayerChanged()
	local teamID = Spring.GetMyTeamID()
	if teamID ~= myTeamID then
		myTeamID = teamID
		RecountUnits()
	end
end

function widget:UnitCreated(unitID, _, unitTeam)
	if unitTeam == myTeamID then
		AddUnit(unitID)
	end
end

function widget:UnitDestroyed(unitID)
	RemoveUnit(unitID)
end

function widget:UnitGiven(unitID, _, newTeam)
	if newTeam == myTeamID then
		AddUnit(unitID)
	end
end

function widget:UnitTaken(unitID, _, oldTeam)
	if oldTeam == myTeamID then
		RemoveUnit(unitID)
	end
end

function widget:Update()
	-- The gadget publishes the regions once the engine has been configured.
	if Spring.GetGameRulesParam("map_regions") then
		SetRegionView(activeRegion)
		ready = true
		widgetHandler:RemoveWidgetCallIn("Update", self)
	end
end

function widget:DrawScreen()
	if not menuVisible or Spring.IsGUIHidden() then
		return
	end
	if labelsDirty then
		UpdateLabels()
	end
	---@type function?
	local element = rawget(WG, "FlowUI") and WG.FlowUI.Draw and WG.FlowUI.Draw.Element
	for _, button in ipairs(buttons) do
		if element then
			element(button.x0, button.y0, button.x1, button.y1)
		else
			gl.Color(0.06, 0.08, 0.09, 0.94)
			gl.Rect(button.x0, button.y0, button.x1, button.y1)
		end
		gl.Color(button.active and 0.4 or 0.85, 0.9, 1, 1)
		gl.Text(button.label, button.x0 + 10, button.y0 + 10, FONT_SIZE, "o")
	end
	gl.Color(1, 1, 1, 1)
end

function widget:DrawWorldPreUnit()
	if pendingCamera and Spring.GetDrawFrame() >= cameraDrawFrame then
		Spring.SetCameraState(pendingCamera, 0)
		pendingCamera = nil
	end
end

function widget:IsAbove(x, y)
	return menuVisible and not Spring.IsGUIHidden() and ButtonAt(x, y) ~= nil
end

function widget:GetTooltip()
	return tooltip
end

function widget:MousePress(x, y, button)
	if button ~= 1 or not menuVisible then
		return false
	end
	local pressed = ButtonAt(x, y)
	if pressed then
		SetRegionView(pressed.region)
		return true
	end
	return false
end

function widget:Shutdown()
	WG.MapRegionView = nil
	Spring.SetCameraBounds()
	Spring.SetMiniMapView()
	Spring.SetWorldDrawBounds()
	if Engine.FeatureSupport.objectDrawBounds then
		Spring.SetObjectDrawBounds()
	end
end
