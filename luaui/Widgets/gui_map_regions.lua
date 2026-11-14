-- SPDX-License-Identifier: GPL-2.0-or-later
function widget:GetInfo()
	return {
		name = "Map region view bounds",
		desc = "Map region selector and cropped world/minimap views",
		author = "Codex",
		license = "GPL v2 or later",
		layer = 9999,
		enabled = true,
		handler = true,
	}
end

if not (Engine.FeatureSupport and Engine.FeatureSupport.mapRegionViews) then
	return false
end

local mapRegions = VFS.Include("luarules/Utilities/map_regions.lua")
if not mapRegions then
	return false
end

local activeRegion, ready = 1, false
local cameraStates = {}
---@type table?, integer?
local pendingCamera, cameraDrawFrame
local buttons, menuVisible, vsx, vsy = {}, false, 0, 0
---@type number
local nextCountsUpdate = 0
local counts = {}

local function ContainsUnit(unitID)
	local x, _, z = Spring.GetUnitPosition(unitID)
	return mapRegions.ContainsObject(activeRegion, x, z)
end

local function SetRegionView(regionID, cameraState)
	if not mapRegions.regions[regionID] then
		return false
	end
	if ready then
		cameraStates[activeRegion] = Spring.GetCameraState()
	end
	activeRegion = regionID
	local r = mapRegions.regions[regionID]
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

local function UpdateSelector()
	counts = {}
	for _, unitID in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID()) or {}) do
		local x, _, z = Spring.GetUnitPosition(unitID)
		local regionID = mapRegions.ObjectRegion(x, z)
		if regionID then
			counts[regionID] = (counts[regionID] or 0) + 1
		end
	end
end

local function RefreshSelector()
	menuVisible = #mapRegions.regions > 1
	buttons = {}
	if not menuVisible then
		return
	end
	vsx, vsy = Spring.GetViewGeometry()
	local top = vsy * 0.65
	for row, _ in ipairs(mapRegions.regions) do
		buttons[#buttons + 1] = {
			region = row,
			x0 = vsx - 254,
			x1 = vsx - 14,
			y0 = top - row * 34,
			y1 = top - (row - 1) * 34 - 3,
		}
	end
end

function widget:DrawScreen()
	if not menuVisible or Spring.IsGUIHidden() then
		return
	end
	---@type function?
	local element = rawget(WG, "FlowUI") and WG.FlowUI.Draw and WG.FlowUI.Draw.Element
	for _, button in ipairs(buttons) do
		local regionID = button.region
		if element then
			element(button.x0, button.y0, button.x1, button.y1)
		else
			gl.Color(0.06, 0.08, 0.09, 0.94)
			gl.Rect(button.x0, button.y0, button.x1, button.y1)
		end
		gl.Color(activeRegion == regionID and 0.4 or 0.85, 0.9, 1, 1)
		gl.Text(
			(activeRegion == regionID and "> " or "")
				.. mapRegions.regions[regionID].name
				.. " ("
				.. (counts[regionID] or 0)
				.. ")",
			button.x0 + 10,
			button.y0 + 10,
			14,
			"o"
		)
	end
	gl.Color(1, 1, 1, 1)
end

function widget:IsAbove(x, y)
	if Spring.IsGUIHidden() then
		return false
	end
	for _, b in ipairs(buttons) do
		if x >= b.x0 and x <= b.x1 and y >= b.y0 and y <= b.y1 then
			return true
		end
	end
	return false
end

function widget:GetTooltip()
	return "Map regions — click to view; N cycles regions"
end

function widget:Initialize()
	activeRegion = mapRegions.TeamHome(Spring.GetMyTeamID()) or 1
end

function widget:Update()
	if not ready and Spring.GetGameRulesParam("map_regions") then
		SetRegionView(activeRegion)
		ready = true
	end
	RefreshSelector()
	local now = Spring.GetDrawSeconds()
	if now >= nextCountsUpdate then
		nextCountsUpdate = now + 0.25
		UpdateSelector()
	end
end

function widget:DrawWorldPreUnit()
	if pendingCamera and Spring.GetDrawFrame() >= cameraDrawFrame then
		Spring.SetCameraState(pendingCamera, 0)
		pendingCamera = nil
	end
end

function widget:KeyPress(key, mods)
	if key ~= string.byte("n") or mods.ctrl or mods.alt or mods.meta or #mapRegions.regions < 2 then
		return false
	end
	SetRegionView(activeRegion % #mapRegions.regions + 1)
	UpdateSelector()
	return true
end

function widget:MousePress(x, y, button)
	if button == 1 and menuVisible then
		for _, b in ipairs(buttons) do
			if x >= b.x0 and x <= b.x1 and y >= b.y0 and y <= b.y1 then
				SetRegionView(b.region)
				return true
			end
		end
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
