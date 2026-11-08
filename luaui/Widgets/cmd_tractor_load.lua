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

if Spring.GetModOptions().beta_tractorbeam == "disabled" then
	return false
end

local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_LOAD_UNIT = GameCMD.TRANSPORT_LOAD_UNIT

local PREVIEW_RADIUS = 1200 -- units around the cursor that get a fit ring
local CLAIM_SCAN_RADIUS = 3000 -- claimed units are looked for this far around each transport
local RING_MARGIN = 8 -- ring just outside the footprint
local REFRESH_FRAMES = 4
local MIN_AREA_RADIUS = 40 -- below this a drag is a click
local LABEL_SIZE = 15

local FITS_COLOR = "\255\220\255\220"
local FULL_COLOR = "\255\255\140\120"

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
local spGetModKeyState = Spring.GetModKeyState
local spGetInvertQueueKey = Spring.GetInvertQueueKey
local spTraceScreenRay = Spring.TraceScreenRay
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetMyTeamID = Spring.GetMyTeamID
local spGetDrawFrame = Spring.GetDrawFrame
local spGetSpectatingState = Spring.GetSpectatingState
local spValidUnitID = Spring.ValidUnitID
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

local EMPTY = {}

local transports = {} -- selected tractor beam transports
local selected = {} -- unitID -> true for the whole selection
local onlyTransports = false
local pending = {} -- transportID -> seats claimed or queued, refreshed with the preview

local rings = {} -- { x, y, z, radius, fits }
local picks = {} -- { transportID, passengerID } predicted for the area being dragged
local claims = {} -- { transportID, passengerID, claimed } for the selected transports
local seatsUsed, seatsTotal = 0, 0
local areaStart -- { x, y, z } of a load drag
local lastRefresh = -math.huge
local labelSize = LABEL_SIZE

local function refreshSelection()
	transports, selected = {}, {}
	local units = spGetSelectedUnits()
	for i = 1, #units do
		selected[units[i]] = true
		if TransportAPI.IsTractorTransport(units[i]) then
			transports[#transports + 1] = units[i]
		end
	end
	onlyTransports = #transports > 0 and #transports == #units
	lastRefresh = -math.huge
end

-- the selection list lags a death by a frame or so
local function dropDeadTransports()
	for i = #transports, 1, -1 do
		if not spValidUnitID(transports[i]) then
			table.remove(transports, i)
		end
	end
end

local function countPending()
	local seats = {}
	for i = 1, #transports do
		seats[transports[i]] = TransportAPI.GetPendingSeats(transports[i])
	end
	return seats
end

local function shiftHeld()
	local _, _, _, shift = spGetModKeyState()
	if spGetInvertQueueKey() then
		shift = not shift
	end
	return shift
end

-- a plain order replaces the queue, so only a shift order counts what is already pending
local function owedSeats(shift)
	return shift and pending or EMPTY
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

-- nearest selected transport with a seat that fits the unit
local function bestTransportFor(unitID, owed)
	local ux, _, uz = spGetUnitPosition(unitID)
	if not ux then
		return nil
	end
	local size = TransportAPI.GetPassengerSize(unitID)
	local best, bestDist
	for i = 1, #transports do
		local transportID = transports[i]
		local tx, _, tz = spGetUnitPosition(transportID)
		if tx and TransportAPI.CanPassengerFitInTransporter(transportID, unitID, nil, size, owed[transportID] or 0) then
			local dist = (tx - ux) * (tx - ux) + (tz - uz) * (tz - uz)
			if not bestDist or dist < bestDist then
				best, bestDist = transportID, dist
			end
		end
	end
	return best
end

-- the gadget's area load: each transport claims the closest units it can seat, mobile and own ones first;
-- transports closer to the area go first (the gadget's order between transports is not fixed)
local MOBILITY_DIST = Game.mapSizeX * Game.mapSizeZ -- the gadget's priority offsets
local ALLIED_DIST = 2 * MOBILITY_DIST

local function predictAreaLoad(cx, cz, radius, shift)
	local result = {}
	local candidates = {}
	local units = spGetUnitsInCylinder(cx, cz, radius)
	local myTeam = spGetMyTeamID()
	for i = 1, #units do
		local unitID = units[i]
		local unitDefID = spGetUnitDefID(unitID)
		local claimedBy = spGetUnitRulesParam(unitID, "transportClaimedBy") or 0
		-- a plain order frees the claims of the selected transports
		local free = claimedBy == 0 or (not shift and selected[claimedBy])
		if free and isLoadable(unitID, unitDefID) then
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
		if tx then
			order[#order + 1] =
				{ id = transports[i], x = tx, z = tz, dist = (tx - cx) * (tx - cx) + (tz - cz) * (tz - cz) }
		end
	end
	table.sort(order, function(a, b)
		return a.dist < b.dist
	end)
	local owedByTransport = owedSeats(shift)
	local taken = {}
	for i = 1, #order do
		local transport = order[i]
		local owed = owedByTransport[transport.id] or 0
		while true do
			local best, bestDist
			for j = 1, #candidates do
				local candidate = candidates[j]
				if
					not taken[candidate.id]
					and TransportAPI.CanPassengerFitInTransporter(transport.id, candidate.id, nil, candidate.size, owed)
				then
					local dx, dz = candidate.x - transport.x, candidate.z - transport.z
					local dist = dx * dx + dz * dz + candidate.offset
					if not bestDist or dist < bestDist then
						best, bestDist = candidate, dist
					end
				end
			end
			if not best then
				break
			end
			taken[best.id] = true
			owed = owed + best.size
			result[#result + 1] = { transportID = transport.id, passengerID = best.id }
		end
	end
	return result
end

local function collectClaims()
	local list = {}
	local listed = {}
	for i = 1, #transports do
		local transportID = transports[i]
		local queue = spGetUnitCommands(transportID, -1)
		if queue then
			for j = 1, #queue do
				local cmd = queue[j]
				local passengerID = cmd.id == CMD_LOAD_UNIT and cmd.params[1]
				if passengerID and not listed[passengerID] then
					listed[passengerID] = true
					list[#list + 1] = {
						transportID = transportID,
						passengerID = passengerID,
						claimed = spGetUnitRulesParam(passengerID, "transportClaimedBy") == transportID,
					}
				end
			end
		end
	end
	-- area loads claim without a queue entry per unit
	for i = 1, #transports do
		local transportID = transports[i]
		local tx, _, tz = spGetUnitPosition(transportID)
		if tx and (spGetUnitRulesParam(transportID, "transporterClaimedSeats") or 0) > 0 then
			local nearby = spGetUnitsInCylinder(tx, tz, CLAIM_SCAN_RADIUS)
			for j = 1, #nearby do
				local unitID = nearby[j]
				if not listed[unitID] and spGetUnitRulesParam(unitID, "transportClaimedBy") == transportID then
					listed[unitID] = true
					list[#list + 1] = { transportID = transportID, passengerID = unitID, claimed = true }
				end
			end
		end
	end
	return list
end

-- a selected transport already claims or has queued this unit
local function takenBySelection(unitID)
	if selected[spGetUnitRulesParam(unitID, "transportClaimedBy") or 0] then
		return true
	end
	for i = 1, #transports do
		local queue = spGetUnitCommands(transports[i], -1)
		for j = 1, queue and #queue or 0 do
			if queue[j].id == CMD_LOAD_UNIT and queue[j].params[1] == unitID then
				return true
			end
		end
	end
	return false
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

function widget:ViewResize(_, vsy)
	labelSize = LABEL_SIZE * (vsy / 1080) * Spring.GetConfigFloat("ui_scale", 1)
end

function widget:Initialize()
	TransportAPI = WG.TransportAPI
	if not TransportAPI then
		widgetHandler:RemoveWidget()
		return
	end
	refreshSelection()
	widget:ViewResize(Spring.GetViewGeometry())
	-- test hooks for the smoke harness
	WG.TractorLoad = {
		BestTransportFor = function(unitID)
			return bestTransportFor(unitID, countPending())
		end,
		PredictAreaLoad = function(cx, cz, radius)
			pending = countPending()
			return predictAreaLoad(cx, cz, radius, true)
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

-- a preview toggle from Transport Settings; on when that widget is off
local function settingOn(key)
	local settings = WG.TransportSettings
	return not settings or settings[key] ~= false
end

function widget:DefaultCommand(targetType, targetID)
	if targetType ~= "unit" or not onlyTransports or not settingOn("rightClickLoad") then
		return
	end
	if not isLoadable(targetID, spGetUnitDefID(targetID)) or spGetUnitTeam(targetID) ~= spGetMyTeamID() then
		return
	end
	if bestTransportFor(targetID, owedSeats(shiftHeld())) then
		return CMD_LOAD_UNITS
	end
end

-- several transports told to load one unit: only the nearest one with a seat for it goes
function widget:CommandNotify(cmdID, params, options)
	if cmdID ~= CMD_LOAD_UNITS or #params ~= 1 or #transports < 2 then
		return false
	end
	if options.shift and takenBySelection(params[1]) then
		return true
	end
	local transportID = bestTransportFor(params[1], options.shift and countPending() or EMPTY)
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

local function clearPreview()
	if #rings > 0 then
		rings = {}
	end
	if #picks > 0 then
		picks = {}
	end
end

function widget:Update()
	if #transports == 0 or spGetSpectatingState() then
		clearPreview()
		if #claims > 0 then
			claims = {}
		end
		return
	end
	-- by draw frame: the preview keeps up while paused
	local frame = spGetDrawFrame()
	if frame - lastRefresh < REFRESH_FRAMES then
		return
	end
	lastRefresh = frame

	dropDeadTransports()
	pending = countPending()
	claims = settingOn("claimLines") and collectClaims() or EMPTY

	local mx, my, lmb = spGetMouseState()
	if areaStart and not lmb then
		areaStart = nil
	end
	local mode = loadMode()
	if not mode then
		clearPreview()
		return
	end

	local alt, ctrl, _, shift = spGetModKeyState()
	if spGetInvertQueueKey() then
		shift = not shift
	end
	local owed = owedSeats(shift)
	seatsUsed, seatsTotal = 0, 0
	for i = 1, #transports do
		local transportID = transports[i]
		seatsTotal = seatsTotal + (spGetUnitRulesParam(transportID, "transporterSeats") or 0)
		seatsUsed = seatsUsed
			+ (spGetUnitRulesParam(transportID, "transporterUsedSeats") or 0)
			+ (owed[transportID] or 0)
	end

	local cx, _, cz = cursorGround(mx, my)
	rings = {}
	if cx and settingOn("rings") then
		local units = spGetUnitsInCylinder(cx, cz, PREVIEW_RADIUS)
		for i = 1, #units do
			local unitID = units[i]
			local unitDefID = spGetUnitDefID(unitID)
			if isLoadable(unitID, unitDefID) and not spIsUnitIcon(unitID) then
				local x, y, z = spGetUnitBasePosition(unitID)
				rings[#rings + 1] = {
					x = x,
					y = y,
					z = z,
					radius = footprint[unitDefID] + RING_MARGIN,
					fits = bestTransportFor(unitID, owed) ~= nil,
				}
			end
		end
	end

	picks = {}
	-- with Alt or Ctrl the area filter turns the drag into its own per-unit loads
	if areaStart and cx and not alt and not ctrl then
		local dx, dz = cx - areaStart[1], cz - areaStart[3]
		local radius = mathSqrt(dx * dx + dz * dz)
		if radius >= MIN_AREA_RADIUS then
			picks = predictAreaLoad(areaStart[1], areaStart[3], radius, shift)
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

local function drawCross(x, y, z, size)
	gl.BeginEnd(GL.LINES, function()
		gl.Vertex(x - size, y, z - size)
		gl.Vertex(x + size, y, z + size)
		gl.Vertex(x - size, y, z + size)
		gl.Vertex(x + size, y, z - size)
	end)
end

function widget:DrawWorldPreUnit()
	if spIsGUIHidden() or (#rings == 0 and #picks == 0 and #claims == 0) then
		return
	end
	gl.DepthTest(false)

	-- fits: a bold ring; no seat for it: a thin ring and a cross
	for i = 1, #rings do
		local ring = rings[i]
		if ring.fits then
			gl.LineWidth(2.5)
			gl.Color(0.35, 1, 0.45, 0.75)
			gl.DrawGroundCircle(ring.x, ring.y, ring.z, ring.radius, 24)
		else
			gl.LineWidth(1)
			gl.Color(0.75, 0.75, 0.75, 0.45)
			gl.DrawGroundCircle(ring.x, ring.y, ring.z, ring.radius, 16)
			drawCross(ring.x, ring.y + 2, ring.z, ring.radius * 0.35)
		end
	end

	-- the area being dragged: who picks whom
	if #picks > 0 then
		gl.LineWidth(2)
		gl.Color(0.35, 1, 0.45, 0.6)
		gl.BeginEnd(GL.LINES, function()
			for i = 1, #picks do
				unitLine(picks[i].transportID, picks[i].passengerID)
			end
		end)
	end

	-- given orders: solid once the transport has claimed the unit, faint while it waits in the queue
	if #claims > 0 then
		gl.LineWidth(1.5)
		gl.BeginEnd(GL.LINES, function()
			for i = 1, #claims do
				local claim = claims[i]
				gl.Color(0.6, 0.6, 1, claim.claimed and 0.7 or 0.25)
				unitLine(claim.transportID, claim.passengerID)
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
	font:Begin()
	font:SetOutlineColor(0, 0, 0, 1)
	font:Print(
		(seatsUsed >= seatsTotal and FULL_COLOR or FITS_COLOR) .. seatsUsed .. "/" .. seatsTotal,
		mx + labelSize * 1.2,
		my - labelSize * 1.6,
		labelSize,
		"o"
	)
	font:End()
end
