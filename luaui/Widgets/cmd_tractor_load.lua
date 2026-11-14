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

local TransportUI = VFS.Include("luaui/Include/transport_ui.lua")

local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_LOAD_UNIT = GameCMD.TRANSPORT_LOAD_UNIT
local LOAD_COMMANDS = { [CMD_LOAD_UNITS] = true }

local PREVIEW_RADIUS = 1200 -- units around the cursor that get a fit ring
local CLAIM_SCAN_RADIUS = 3000 -- claimed units are looked for this far around each transport
local RING_MARGIN = 8 -- ring just outside the footprint
local REFRESH_FRAMES = 4
local MIN_AREA_RADIUS = 40 -- below this a drag is a click
local LABEL_SIZE = 15

local FITS_COLOR = "\255\220\255\220"
local FULL_COLOR = "\255\255\140\120"

local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitCommands = Spring.GetUnitCommands
local spGetMouseState = Spring.GetMouseState
local spGetMyTeamID = Spring.GetMyTeamID

local TransportAPI ---@type table

local cantBeTransported, isMobile, footprint = {}, {}, {} ---@type table<integer, boolean>, table<integer, boolean>, table<integer, number>
for unitDefID, ud in pairs(UnitDefs) do
	cantBeTransported[unitDefID] = ud.cantBeTransported
	isMobile[unitDefID] = ud.speed > 0
	footprint[unitDefID] = math.max(ud.xsize, ud.zsize) * Game.squareSize * 0.5
end

local EMPTY = {}

---@class LoadPick
---@field transportID integer
---@field passengerID integer
---@field claimed boolean? the transport has claimed it, not only queued it

local transports = {} ---@type integer[] selected tractor beam transports
local selected = {} ---@type table<number, true> the whole selection
local onlyTransports = false
local pending = {} ---@type table<integer, number> seats claimed or queued per transport, refreshed with the preview

local rings = {} ---@type { x: number, y: number, z: number, radius: number, fits: boolean }[]
local picks = {} ---@type LoadPick[] predicted for the area being dragged
local claims = {} ---@type LoadPick[] of the selected transports
local seatsUsed, seatsTotal = 0, 0 ---@type number, number
local areaStart ---@type { [1]: number, [2]: number, [3]: number }? a load drag
local lastRefresh = -math.huge
local labelSize = LABEL_SIZE ---@type number

local function refreshSelection()
	selected = {}
	local units = Spring.GetSelectedUnits()
	for i = 1, #units do
		selected[units[i]] = true
	end
	transports = TransportUI.tractorTransports(TransportAPI, units)
	onlyTransports = #transports > 0 and #transports == #units
	lastRefresh = -math.huge
end

-- the selection list lags a death by a frame or so
local function dropDeadTransports()
	for i = #transports, 1, -1 do
		if not Spring.ValidUnitID(transports[i]) then
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

-- a plain order replaces the queue, so only a shift order counts what is already pending
local function owedSeats(shift)
	return shift and pending or EMPTY
end

-- a unit the gadget would lift (seats aside): ours or allied, standing free
local function isLoadable(unitID, unitDefID)
	if not unitDefID or cantBeTransported[unitDefID] or selected[unitID] then
		return false
	end
	if Spring.GetUnitTransporter(unitID) or Spring.GetUnitIsBeingBuilt(unitID) then
		return false
	end
	if (spGetUnitRulesParam(unitID, "inLoadAnim") or 0) > 0 or spGetUnitRulesParam(unitID, "inUnloadAnim") == 1 then
		return false
	end
	local teamID = spGetUnitTeam(unitID)
	return teamID ~= nil and Spring.AreTeamsAllied(teamID, spGetMyTeamID())
end

-- nearest selected transport with a seat that fits the unit
local function bestTransportFor(unitID, owed)
	local ux, _, uz = spGetUnitPosition(unitID)
	if not ux then
		return nil
	end
	local size = TransportAPI.GetPassengerSize(unitID)
	local best, bestDist ---@type integer?, number?
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

---@return LoadPick[]
local function predictAreaLoad(cx, cz, radius, shift)
	local candidates = {} ---@type { id: integer, x: number, z: number, size: number, offset: number }[]
	local units = spGetUnitsInCylinder(cx, cz, radius)
	local myTeam = spGetMyTeamID()
	for i = 1, #units do
		local unitID = units[i]
		local unitDefID = spGetUnitDefID(unitID)
		local claimedBy = spGetUnitRulesParam(unitID, "transportClaimedBy") or 0
		-- a plain order frees the claims of the selected transports
		local free = claimedBy == 0 or (not shift and selected[claimedBy])
		local x, _, z = spGetUnitPosition(unitID)
		if unitDefID and x and free and isLoadable(unitID, unitDefID) then
			local offset = (isMobile[unitDefID] and 0 or MOBILITY_DIST)
				+ (spGetUnitTeam(unitID) == myTeam and 0 or ALLIED_DIST)
			candidates[#candidates + 1] =
				{ id = unitID, x = x, z = z, size = TransportAPI.GetPassengerSize(unitID), offset = offset }
		end
	end
	local order = {} ---@type { id: integer, x: number, z: number, dist: number }[]
	for i = 1, #transports do
		local tx, _, tz = spGetUnitPosition(transports[i])
		if tx then
			order[#order + 1] = { id = transports[i], x = tx, z = tz, dist = (tx - cx) ^ 2 + (tz - cz) ^ 2 }
		end
	end
	table.sort(order, function(a, b)
		return a.dist < b.dist
	end)
	local owedByTransport = owedSeats(shift)
	local taken = {}
	local result = {}
	for i = 1, #order do
		local transport = order[i]
		local owed = owedByTransport[transport.id] or 0
		while true do
			local best, bestDist
			for j = 1, #candidates do
				local candidate = candidates[j]
				local fits = not taken[candidate.id]
					and TransportAPI.CanPassengerFitInTransporter(transport.id, candidate.id, nil, candidate.size, owed)
				if fits then
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

-- units a transport has a single unit load queued for
---@return integer[]
local function queuedPassengers(transportID)
	local list = {}
	local queue = spGetUnitCommands(transportID, -1) or EMPTY
	for i = 1, #queue do
		local params = queue[i].params
		if queue[i].id == CMD_LOAD_UNIT and params and params[1] then
			list[#list + 1] = params[1]
		end
	end
	return list
end

---@return LoadPick[]
local function collectClaims()
	local list = {}
	local listed = {}
	local function add(transportID, passengerID, claimed)
		if not listed[passengerID] then
			listed[passengerID] = true
			list[#list + 1] = { transportID = transportID, passengerID = passengerID, claimed = claimed }
		end
	end
	for i = 1, #transports do
		local transportID = transports[i]
		local queued = queuedPassengers(transportID)
		for j = 1, #queued do
			add(transportID, queued[j], spGetUnitRulesParam(queued[j], "transportClaimedBy") == transportID)
		end
	end
	-- area loads claim without a queue entry per unit
	for i = 1, #transports do
		local transportID = transports[i]
		local tx, _, tz = spGetUnitPosition(transportID)
		if tx and (spGetUnitRulesParam(transportID, "transporterClaimedSeats") or 0) > 0 then
			local nearby = spGetUnitsInCylinder(tx, tz, CLAIM_SCAN_RADIUS)
			for j = 1, #nearby do
				if spGetUnitRulesParam(nearby[j], "transportClaimedBy") == transportID then
					add(transportID, nearby[j], true)
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
		local queued = queuedPassengers(transports[i])
		for j = 1, #queued do
			if queued[j] == unitID then
				return true
			end
		end
	end
	return false
end

local function loadMode()
	return TransportUI.commandMode(LOAD_COMMANDS)
end

local function resizeLabel(vsy)
	labelSize = LABEL_SIZE * (vsy / 1080) * Spring.GetConfigFloat("ui_scale", 1)
end

function widget:ViewResize(_, vsy)
	resizeLabel(vsy)
end

function widget:Initialize()
	TransportAPI = WG.TransportAPI
	if not TransportAPI then
		widgetHandler:RemoveWidget()
		return
	end
	refreshSelection()
	local _, vsy = Spring.GetViewGeometry()
	resizeLabel(vsy)
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

function widget:DefaultCommand(targetType, targetID)
	if targetType ~= "unit" or not onlyTransports or not TransportUI.settingOn("rightClickLoad") then
		return
	end
	if not isLoadable(targetID, spGetUnitDefID(targetID)) or spGetUnitTeam(targetID) ~= spGetMyTeamID() then
		return
	end
	if bestTransportFor(targetID, owedSeats(TransportUI.shiftHeld())) then
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
	Spring.GiveOrderToUnit(transportID, CMD_LOAD_UNITS, params, options.coded)
	return true
end

function widget:MousePress(mx, my, button)
	if button == 1 and loadMode() == "active" then
		local x, y, z = TransportUI.cursorGround(mx, my)
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

local function countSeats(owed)
	seatsUsed, seatsTotal = 0, 0
	for i = 1, #transports do
		local transportID = transports[i]
		local used = spGetUnitRulesParam(transportID, "transporterUsedSeats") or 0
		seatsTotal = seatsTotal + (spGetUnitRulesParam(transportID, "transporterSeats") or 0)
		seatsUsed = seatsUsed + used + (owed[transportID] or 0)
	end
end

local function findRings(cx, cz, owed)
	rings = {}
	local units = spGetUnitsInCylinder(cx, cz, PREVIEW_RADIUS)
	for i = 1, #units do
		local unitID = units[i]
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID and isLoadable(unitID, unitDefID) and not Spring.IsUnitIcon(unitID) then
			local x, y, z = Spring.GetUnitBasePosition(unitID)
			if x and y and z then
				local radius = footprint[unitDefID] + RING_MARGIN
				rings[#rings + 1] =
					{ x = x, y = y, z = z, radius = radius, fits = bestTransportFor(unitID, owed) ~= nil }
			end
		end
	end
end

function widget:Update()
	if #transports == 0 or Spring.GetSpectatingState() then
		clearPreview()
		if #claims > 0 then
			claims = {}
		end
		return
	end
	-- by draw frame: the preview keeps up while paused
	local frame = Spring.GetDrawFrame()
	if frame - lastRefresh < REFRESH_FRAMES then
		return
	end
	lastRefresh = frame

	dropDeadTransports()
	pending = countPending()
	claims = TransportUI.settingOn("claimLines") and collectClaims() or EMPTY

	local mx, my, lmb = spGetMouseState()
	if areaStart and not lmb then
		areaStart = nil
	end
	if not loadMode() then
		clearPreview()
		return
	end

	local shift = TransportUI.shiftHeld()
	local owed = owedSeats(shift)
	countSeats(owed)

	local cx, _, cz = TransportUI.cursorGround(mx, my)
	rings = {}
	picks = {}
	if not (cx and cz) then
		return
	end
	if TransportUI.settingOn("rings") then
		findRings(cx, cz, owed)
	end
	-- with Alt or Ctrl the area filter turns the drag into its own per-unit loads
	local alt, ctrl = Spring.GetModKeyState()
	if areaStart and not alt and not ctrl then
		local radius = math.sqrt((cx - areaStart[1]) ^ 2 + (cz - areaStart[3]) ^ 2)
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

local function pickLines(list, colored)
	for i = 1, #list do
		local pick = list[i]
		if colored then
			gl.Color(0.6, 0.6, 1, pick.claimed and 0.7 or 0.25)
		end
		unitLine(pick.transportID, pick.passengerID)
	end
end

function widget:DrawWorldPreUnit()
	if Spring.IsGUIHidden() or (#rings == 0 and #picks == 0 and #claims == 0) then
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
			gl.BeginEnd(GL.LINES, TransportUI.crossVertices, ring.x, ring.y + 2, ring.z, ring.radius * 0.35)
		end
	end

	-- the area being dragged: who picks whom
	if #picks > 0 then
		gl.LineWidth(2)
		gl.Color(0.35, 1, 0.45, 0.6)
		gl.BeginEnd(GL.LINES, pickLines, picks, false)
	end

	-- given orders: solid once the transport has claimed the unit, faint while it waits in the queue
	if #claims > 0 then
		gl.LineWidth(1.5)
		gl.BeginEnd(GL.LINES, pickLines, claims, true)
	end

	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
	gl.DepthTest(true)
end

function widget:DrawScreen()
	if Spring.IsGUIHidden() or seatsTotal == 0 or not loadMode() or not WG.fonts then
		return
	end
	local font = WG.fonts.getFont(2)
	if not font then
		return
	end
	local mx, my = spGetMouseState()
	local color = seatsUsed >= seatsTotal and FULL_COLOR or FITS_COLOR
	font:Begin()
	font:SetOutlineColor(0, 0, 0, 1)
	font:Print(color .. seatsUsed .. "/" .. seatsTotal, mx + labelSize * 1.2, my - labelSize * 1.6, labelSize, "o")
	font:End()
end
