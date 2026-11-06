local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Tractor Beam Load",
		desc = "Right click loads while a seat is free, and shows which units fit and which transport picks them",
		author = "PtaQ",
		version = "v1.0",
		date = "November 2026",
		license = "GNU GPL, v2 or later",
		layer = -2, -- the single unit load goes to one transport before other widgets see it
		enabled = true,
	}
end

local tractorBeamMode = Spring.GetModOptions().beta_tractorbeam
if not tractorBeamMode or tractorBeamMode == "disabled" then
	return false
end

local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_LOAD_UNIT = 39752 -- Transport Handler gadget

local PREVIEW_RADIUS = 1200 -- units around the cursor that get a fit ring
local REFRESH_FRAMES = 4
local MIN_AREA_RADIUS = 40 -- below this a drag is a click

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetUnitTransporter = Spring.GetUnitTransporter
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitCommands = Spring.GetUnitCommands
local spGetActiveCommand = Spring.GetActiveCommand
local spGetDefaultCommand = Spring.GetDefaultCommand
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetGameFrame = Spring.GetGameFrame
local spAreTeamsAllied = Spring.AreTeamsAllied
local spIsUnitIcon = Spring.IsUnitIcon
local spIsGUIHidden = Spring.IsGUIHidden

local mathMax = math.max
local mathSqrt = math.sqrt

local TransportAPI

local cantBeTransported, isMobile, footprint = {}, {}, {}
for unitDefID, ud in pairs(UnitDefs) do
	cantBeTransported[unitDefID] = ud.cantBeTransported
	isMobile[unitDefID] = ud.speed > 0
	footprint[unitDefID] = mathMax(ud.xsize, ud.zsize) * Game.squareSize * 0.5
end

local transports = {} -- selected tractor beam transports
local selected = {} -- unitID -> true for the whole selection
local onlyTransports = false
local pending = {} -- transportID -> seats claimed or queued, refreshed with the preview

local rings = {} -- { unitID, x, y, z, radius, fits }
local picks = {} -- { transportID, passengerID } predicted for the area being dragged
local claims = {} -- { transportID, passengerID, claimed } for the selected transports
local seatsUsed, seatsTotal = 0, 0
local areaStart -- { x, y, z } of a load drag
local lastRefresh = -math.huge

local function isTractorTransport(unitID)
	local seats = spGetUnitRulesParam(unitID, "transporterSeats")
	return seats and seats > 0
end

local function refreshSelection()
	transports, selected = {}, {}
	local units = spGetSelectedUnits()
	for i = 1, #units do
		selected[units[i]] = true
		if isTractorTransport(units[i]) then
			transports[#transports + 1] = units[i]
		end
	end
	onlyTransports = #transports > 0 and #transports == #units
	lastRefresh = -math.huge
end

local function refreshPending()
	pending = {}
	for i = 1, #transports do
		pending[transports[i]] = TransportAPI.GetPendingSeats(transports[i])
	end
end

-- a unit the gadget would lift (seats aside): ours or allied, standing free
local function isLoadable(unitID, unitDefID)
	if not unitDefID or cantBeTransported[unitDefID] or selected[unitID] then
		return false
	end
	if spGetUnitTransporter(unitID) or spGetUnitIsBeingBuilt(unitID) then
		return false
	end
	if (spGetUnitRulesParam(unitID, "inLoadAnim") or 0) > 0 or spGetUnitRulesParam(unitID, "inUnloadAnim") == 1 then
		return false
	end
	return spAreTeamsAllied(spGetUnitTeam(unitID), spGetMyTeamID())
end

local function fitsIn(transportID, unitID, size)
	return TransportAPI.CanPassengerFitInTransporter(transportID, unitID, nil, size, pending[transportID] or 0)
end

-- nearest selected transport with a seat that fits the unit
local function bestTransportFor(unitID)
	local size = TransportAPI.GetPassengerSize(unitID)
	local ux, _, uz = spGetUnitPosition(unitID)
	local best, bestDist
	for i = 1, #transports do
		local transportID = transports[i]
		if fitsIn(transportID, unitID, size) then
			local tx, _, tz = spGetUnitPosition(transportID)
			local d = (tx - ux) * (tx - ux) + (tz - uz) * (tz - uz)
			if not bestDist or d < bestDist then
				best, bestDist = transportID, d
			end
		end
	end
	return best
end

-- the gadget's area load: each transport claims the closest units it can seat, mobile and own ones first;
-- transports closer to the area go first (the gadget's order between transports is not fixed)
local MOBILITY_DIST = Game.mapSizeX * Game.mapSizeZ -- same offsets as the gadget
local ALLIED_DIST = 2 * MOBILITY_DIST

local function predictAreaLoad(cx, cz, radius)
	local result = {}
	local candidates = {}
	local units = spGetUnitsInCylinder(cx, cz, radius)
	local myTeam = spGetMyTeamID()
	for i = 1, #units do
		local unitID = units[i]
		local unitDefID = spGetUnitDefID(unitID)
		if isLoadable(unitID, unitDefID) and (spGetUnitRulesParam(unitID, "transportClaimedBy") or 0) == 0 then
			local x, _, z = spGetUnitPosition(unitID)
			candidates[#candidates + 1] = {
				id = unitID,
				x = x,
				z = z,
				size = TransportAPI.GetPassengerSize(unitID),
				offset = (isMobile[unitDefID] and 0 or MOBILITY_DIST)
					+ (spGetUnitTeam(unitID) == myTeam and 0 or ALLIED_DIST),
			}
		end
	end
	local order = {}
	for i = 1, #transports do
		local tx, _, tz = spGetUnitPosition(transports[i])
		order[i] = { id = transports[i], x = tx, z = tz, d = (tx - cx) * (tx - cx) + (tz - cz) * (tz - cz) }
	end
	table.sort(order, function(a, b)
		return a.d < b.d
	end)
	local taken = {}
	for i = 1, #order do
		local t = order[i]
		local owed = pending[t.id] or 0
		while true do
			local best, bestDist
			for j = 1, #candidates do
				local c = candidates[j]
				if not taken[c.id] and TransportAPI.CanPassengerFitInTransporter(t.id, c.id, nil, c.size, owed) then
					local d = (c.x - t.x) * (c.x - t.x) + (c.z - t.z) * (c.z - t.z) + c.offset
					if not bestDist or d < bestDist then
						best, bestDist = c, d
					end
				end
			end
			if not best then
				break
			end
			taken[best.id] = true
			owed = owed + best.size
			result[#result + 1] = { t.id, best.id }
		end
	end
	return result
end

local function collectClaims()
	local list = {}
	for i = 1, #transports do
		local transportID = transports[i]
		local Q = spGetUnitCommands(transportID, -1)
		if Q then
			for j = 1, #Q do
				local cmd = Q[j]
				if cmd.id == CMD_LOAD_UNIT and cmd.params[1] then
					local passengerID = cmd.params[1]
					list[#list + 1] = {
						transportID,
						passengerID,
						spGetUnitRulesParam(passengerID, "transportClaimedBy") == transportID,
					}
				end
			end
		end
	end
	-- area loads claim without a queue entry per unit
	if #transports > 0 then
		local myAllyTeam = spGetMyAllyTeamID()
		for i = 1, #transports do
			local tx, _, tz = spGetUnitPosition(transports[i])
			local nearby = spGetUnitsInCylinder(tx, tz, 3000, myAllyTeam)
			for j = 1, #nearby do
				if spGetUnitRulesParam(nearby[j], "transportClaimedBy") == transports[i] then
					local known = false
					for k = 1, #list do
						if list[k][2] == nearby[j] then
							known = true
							break
						end
					end
					if not known then
						list[#list + 1] = { transports[i], nearby[j], true }
					end
				end
			end
		end
	end
	return list
end

-- "active": the load button is armed; "default": a right click would load
local function loadMode()
	local _, activeCmdID = spGetActiveCommand()
	if activeCmdID then
		return activeCmdID == CMD_LOAD_UNITS and "active" or nil
	end
	local _, defaultCmdID = spGetDefaultCommand()
	return defaultCmdID == CMD_LOAD_UNITS and "default" or nil
end

local function cursorGround(mx, my)
	local _, pos = spTraceScreenRay(mx, my, true)
	if pos and pos[1] then
		return pos[1], pos[2], pos[3]
	end
end

function widget:Initialize()
	TransportAPI = WG.TransportAPI
	if not TransportAPI or not TransportAPI.GetPendingSeats then
		Spring.Echo("Tractor Beam Load: needs the Transport Handler API, removing")
		widgetHandler:RemoveWidget()
		return
	end
	refreshSelection()
	WG.TractorLoad = {
		BestTransportFor = function(unitID)
			refreshPending()
			return bestTransportFor(unitID)
		end,
		PredictAreaLoad = function(cx, cz, radius)
			refreshPending()
			return predictAreaLoad(cx, cz, radius)
		end,
		GetClaims = collectClaims,
	}
end

function widget:Shutdown()
	WG.TractorLoad = nil
end

function widget:SelectionChanged()
	refreshSelection()
end

function widget:DefaultCommand(targetType, targetID)
	if targetType ~= "unit" or not onlyTransports then
		return
	end
	if not isLoadable(targetID, spGetUnitDefID(targetID)) or spGetUnitTeam(targetID) ~= spGetMyTeamID() then
		return
	end
	refreshPending()
	if bestTransportFor(targetID) then
		return CMD_LOAD_UNITS
	end
end

-- several transports told to load one unit: only the nearest one with a seat for it goes
function widget:CommandNotify(cmdID, params, options)
	if cmdID ~= CMD_LOAD_UNITS or #params ~= 1 or #transports < 2 then
		return false
	end
	if options.shift then
		refreshPending()
	else
		pending = {}
	end
	local transportID = bestTransportFor(params[1])
	if not transportID then
		return false
	end
	spGiveOrderToUnit(transportID, CMD_LOAD_UNITS, params, options.coded)
	return true
end

function widget:MousePress(mx, my, button)
	if button == 1 and loadMode() == "active" then
		local x, y, z = cursorGround(mx, my)
		areaStart = x and { x, y, z } or nil
	end
	return false
end

function widget:Update()
	if #transports == 0 then
		rings, picks, claims = {}, {}, {}
		return
	end
	local frame = spGetGameFrame()
	if frame - lastRefresh < REFRESH_FRAMES then
		return
	end
	lastRefresh = frame

	claims = collectClaims()

	local mx, my, lmb = spGetMouseState()
	if areaStart and not lmb then
		areaStart = nil
	end
	local mode = loadMode()
	if not mode then
		rings, picks = {}, {}
		return
	end

	refreshPending()
	seatsUsed, seatsTotal = 0, 0
	for i = 1, #transports do
		local transportID = transports[i]
		seatsTotal = seatsTotal + (spGetUnitRulesParam(transportID, "transporterSeats") or 0)
		seatsUsed = seatsUsed
			+ (spGetUnitRulesParam(transportID, "transporterUsedSeats") or 0)
			+ (pending[transportID] or 0)
	end

	local cx, _, cz = cursorGround(mx, my)
	rings = {}
	if cx then
		local units = spGetUnitsInCylinder(cx, cz, PREVIEW_RADIUS)
		for i = 1, #units do
			local unitID = units[i]
			local unitDefID = spGetUnitDefID(unitID)
			if isLoadable(unitID, unitDefID) and not spIsUnitIcon(unitID) then
				local x, y, z = spGetUnitBasePosition(unitID)
				rings[#rings + 1] = { unitID, x, y, z, footprint[unitDefID] + 8, bestTransportFor(unitID) ~= nil }
			end
		end
	end

	picks = {}
	if areaStart and cx then
		local dx, dz = cx - areaStart[1], cz - areaStart[3]
		local radius = mathSqrt(dx * dx + dz * dz)
		if radius >= MIN_AREA_RADIUS then
			picks = predictAreaLoad(areaStart[1], areaStart[3], radius)
		end
	end
end

local function unitLine(fromID, toID)
	local fx, fy, fz = spGetUnitPosition(fromID)
	local tx, ty, tz = spGetUnitPosition(toID)
	if fx and tx then
		gl.Vertex(fx, fy, fz)
		gl.Vertex(tx, ty, tz)
	end
end

local function drawCross(x, y, z, s)
	gl.BeginEnd(GL.LINES, function()
		gl.Vertex(x - s, y, z - s)
		gl.Vertex(x + s, y, z + s)
		gl.Vertex(x - s, y, z + s)
		gl.Vertex(x + s, y, z - s)
	end)
end

function widget:DrawWorldPreUnit()
	if spIsGUIHidden() or (#rings == 0 and #picks == 0 and #claims == 0) then
		return
	end
	gl.DepthTest(false)

	-- fits: a bold ring; no seat for it: a thin ring and a cross
	for i = 1, #rings do
		local r = rings[i]
		if r[6] then
			gl.LineWidth(2.5)
			gl.Color(0.35, 1, 0.45, 0.75)
			gl.DrawGroundCircle(r[2], r[3], r[4], r[5], 24)
		else
			gl.LineWidth(1)
			gl.Color(0.75, 0.75, 0.75, 0.45)
			gl.DrawGroundCircle(r[2], r[3], r[4], r[5], 16)
			drawCross(r[2], r[3] + 2, r[4], r[5] * 0.35)
		end
	end

	-- the area being dragged: who picks whom
	if #picks > 0 then
		gl.LineWidth(2)
		gl.Color(0.35, 1, 0.45, 0.6)
		gl.BeginEnd(GL.LINES, function()
			for i = 1, #picks do
				unitLine(picks[i][1], picks[i][2])
			end
		end)
	end

	-- given orders: solid once the transport has claimed the unit, faint while it waits in the queue
	if #claims > 0 then
		gl.LineWidth(1.5)
		gl.BeginEnd(GL.LINES, function()
			for i = 1, #claims do
				local c = claims[i]
				if c[3] then
					gl.Color(0.6, 0.6, 1, 0.7)
				else
					gl.Color(0.6, 0.6, 1, 0.25)
				end
				unitLine(c[1], c[2])
			end
		end)
	end

	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
	gl.DepthTest(true)
end

function widget:DrawScreen()
	if spIsGUIHidden() or seatsTotal == 0 or not loadMode() or not WG.fonts then
		return
	end
	local font = WG.fonts.getFont(2)
	if not font then
		return
	end
	local mx, my = spGetMouseState()
	local size = 15 * (WG.uiScale or 1)
	font:Begin()
	font:SetOutlineColor(0, 0, 0, 1)
	font:Print(
		(seatsUsed >= seatsTotal and "\255\255\140\120" or "\255\220\255\220") .. seatsUsed .. "/" .. seatsTotal,
		mx + size * 1.2,
		my - size * 1.6,
		size,
		"o"
	)
	font:End()
end
