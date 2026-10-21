-- SPDX-License-Identifier: GPL-2.0-or-later
function widget:GetInfo()
	return {
		name = "Portal view bounds",
		desc = "Connected-map selector and cropped world/minimap views",
		author = "Codex",
		license = "GPL v2 or later",
		-- BAR dispatches mouse presses in ascending layer order. Handle portal
		-- clicks before CustomFormations2 (10000) turns them into ground moves.
		layer = 9999,
		enabled = true,
	}
end
if not (Engine.FeatureSupport and Engine.FeatureSupport.mapRegionViews) then
	return false
end
local options = Spring.GetModOptions()
if not options.portal_worlds or options.portal_worlds == "off" then
	return false
end
local world = VFS.Include("luarules/Utilities/portal_worlds.lua")
if not world then
	return false
end
local active, origin, generation, ready = 1, 1, 0, false
local cameraStates = {}
local pendingCamera, cameraDrawFrame
local buttons, menuVisible, vsx, vsy = {}, false, 0, 0
---@type number
local nextCountsUpdate = 0
local function IsOpen(edge)
	return Spring.GetGameRulesParam("portal_e" .. edge .. "_open") == 1
end
local function Accessible(region)
	return region == origin or world.Route(origin, region, IsOpen) ~= nil
end
local function ContainsUnit(id)
	local x, _, z = Spring.GetUnitPosition(id)
	return world.ContainsObject(active, x, z)
end
local function View(region, cameraState)
	if not world.regions[region] or not Accessible(region) then
		return false
	end
	if ready then
		cameraStates[active] = Spring.GetCameraState()
	end
	active = region
	generation = generation + 1
	local r = world.regions[region]
	WG.PortalWorldView = { generation = generation, region = region, rect = r, ContainsUnit = ContainsUnit }
	if WG.DelaySmoothCam then
		WG.DelaySmoothCam(0.5)
	end
	Spring.SetCameraBounds(r.x0, r.z0, r.x1, r.z1)
	Spring.SetMiniMapView(r.x0, r.z0, r.x1, r.z1)
	Spring.SetWorldDrawBounds(r.x0, r.z0, r.x1, r.z1)
	if Engine.FeatureSupport.objectDrawBounds then
		local bounds = world.objectBounds[region]
		Spring.SetObjectDrawBounds(bounds.x0, bounds.z0, bounds.x1, bounds.z1)
	end
	local x, z = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
	pendingCamera = cameraState
		or cameraStates[region]
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
local counts = {}
local function UpdateSelector()
	counts = {}
	for _, id in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID()) or {}) do
		local x, _, z = Spring.GetUnitPosition(id)
		local region = world.ObjectRegion(x, z)
		if region then
			counts[region] = (counts[region] or 0) + 1
		end
	end
end
local function RefreshSelector()
	local accessible = {}
	for i in ipairs(world.regions) do
		if Accessible(i) then
			accessible[#accessible + 1] = i
		end
	end
	menuVisible = #accessible > 1
	buttons = {}
	if not menuVisible then
		return
	end
	vsx, vsy = Spring.GetViewGeometry()
	local top = vsy * 0.65
	for row, region in ipairs(accessible) do
		buttons[#buttons + 1] =
			{ region = region, x0 = vsx - 254, x1 = vsx - 14, y0 = top - row * 34, y1 = top - (row - 1) * 34 - 3 }
	end
end
function widget:DrawScreen()
	if not menuVisible or Spring.IsGUIHidden() then
		return
	end
	local element = WG.FlowUI and WG.FlowUI.Draw.Element
	for _, button in ipairs(buttons) do
		local i = button.region
		if element then
			element(button.x0, button.y0, button.x1, button.y1)
		else
			gl.Color(0.06, 0.08, 0.09, 0.94)
			gl.Rect(button.x0, button.y0, button.x1, button.y1)
		end
		gl.Color(active == i and 0.4 or 0.85, 0.9, 1, 1)
		gl.Text(
			(active == i and "> " or "") .. world.regions[i].name .. " (" .. (counts[i] or 0) .. ")",
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
	return "Connected maps — click to view; N cycles maps"
end
function widget:Initialize()
	WG.PortalWorlds = {
		View = View,
		Accessible = Accessible,
		GetState = function()
			return active, menuVisible
		end,
	}
	origin = world.TeamHome(Spring.GetMyTeamID()) or 1
	active = origin
end
function widget:Update()
	if not ready and Spring.GetGameRulesParam("portal_regions") then
		View(active)
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
	if key ~= string.byte("n") or mods.ctrl or mods.alt or mods.meta then
		return false
	end
	for offset = 1, #world.regions - 1 do
		local i = (active - 1 + offset) % #world.regions + 1
		if Accessible(i) then
			View(i)
			UpdateSelector()
			return true
		end
	end
	return false
end
function widget:MousePress(x, y, button)
	if button == 1 and menuVisible then
		for _, b in ipairs(buttons) do
			if x >= b.x0 and x <= b.x1 and y >= b.y0 and y <= b.y1 then
				View(b.region)
				return true
			end
		end
	end
	if button ~= 3 then
		return false
	end
	local _, activeCommand = Spring.GetActiveCommand()
	if activeCommand then
		return false -- Preserve normal command cancellation and formation controls.
	end
	local kind, id = Spring.TraceScreenRay(x, y, false, true)
	---@type integer?
	local edge
	if kind == "unit" and type(id) == "number" then
		local unitID = math.floor(id)
		local candidate = Spring.GetUnitRulesParam(unitID, "portal_portal")
		if
			type(candidate) == "number"
			and candidate % 1 == 0
			and Spring.GetUnitRulesParam(unitID, "portal_region") == active
		then
			edge = math.floor(candidate)
		end
	end
	if not edge then
		local _, pos = Spring.TraceScreenRay(x, y, true, true)
		if type(pos) ~= "table" then
			return false
		end
		for i, connection in ipairs(world.connections) do
			if IsOpen(i) and world.Other(connection, active) then
				local prefix = "portal_e" .. i .. "_r" .. active
				local mx, mz = Spring.GetGameRulesParam(prefix .. "_x"), Spring.GetGameRulesParam(prefix .. "_z")
				if
					type(mx) == "number"
					and type(mz) == "number"
					and (pos[1] - mx) ^ 2 + (pos[3] - mz) ^ 2 <= 64 ^ 2
				then
					edge = i
					break
				end
			end
		end
	end
	if not edge then
		return false
	end
	local selected = Spring.GetSelectedUnits()
	if #selected == 0 then
		return false
	end
	local _, _, _, shift = Spring.GetModKeyState()
	if Spring.GetInvertQueueKey() then
		shift = not shift
	end
	Spring.GiveOrderToUnitArray(selected, GameCMD.PORTAL_TRAVEL, { edge, active }, shift and CMD.OPT_SHIFT or 0)
	return true
end
function widget:Shutdown()
	WG.PortalWorldView = nil
	WG.PortalWorlds = nil
	Spring.SetCameraBounds()
	Spring.SetMiniMapView()
	Spring.SetWorldDrawBounds()
end
