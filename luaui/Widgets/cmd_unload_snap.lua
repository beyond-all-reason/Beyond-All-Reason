local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unload Snap and Preview",
		desc = "Shows where each selected tractor beam transport will set its cargo down, and sends it exactly there",
		author = "DoodVanDaag, PtaQ",
		version = "v2.0",
		date = "November 2026",
		license = "GNU GPL, v2 or later",
		layer = -1, -- before Area Unload and Custom Formations see the unload
		enabled = true,
	}
end

local tractorBeamMode = Spring.GetModOptions().beta_tractorbeam
if not tractorBeamMode or tractorBeamMode == "disabled" then
	return false
end

-- How it stays true to the gadget: the Transport Handler re-snaps an unload with ClosestBuildPos from the
-- ordered point, and ClosestBuildPos keeps that point when it is free. So each transport is ordered straight
-- to a pad position that is already free, and the ghost drawn there is where the cargo lands.
-- The search here only uses what the player can see: TestBuildOrder is LOS aware in unsynced code, while
-- ClosestBuildPos also scans for buildings out of sight (RecoilEngine #2955) and would leak them on hover.

local CMD_UNLOAD_UNIT = CMD.UNLOAD_UNIT
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_AREA_LOAD = 39751 -- Transport Handler gadget
local CMD_LOAD_UNIT = 39752
local CMD_LOAD_WAIT = 39753

local SEARCH_RADIUS = 512 -- same radius the gadget snaps with
local BUILD_SQUARE = Game.squareSize * 2
local FACTORY_YARD_MARGIN = Game.squareSize * 2 -- ClosestBuildPos keeps 2 squares off factories with an open yard
local SEARCH_BUDGET = 6000 -- TestBuildOrder calls per plan, all transports together
local REPLAN_FRAMES = 15 -- cargo and queues change without a cursor move

-- TestBuildOrder: 0 blocked, 1 mobile unit in the way, 2 free (the engine maps OPEN onto RECLAIMABLE for old
-- callers); a feature in the way comes back as a second value, and ClosestBuildPos never keeps a spot on one
local MOBILE, FREE = 1, 2

local spGetActiveCommand = Spring.GetActiveCommand
local spGetDefaultCommand = Spring.GetDefaultCommand
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spPos2BuildPos = Spring.Pos2BuildPos
local spTestBuildOrder = Spring.TestBuildOrder
local spGetGroundHeight = Spring.GetGroundHeight
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetModKeyState = Spring.GetModKeyState
local spGetInvertQueueKey = Spring.GetInvertQueueKey
local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID

local mathAbs = math.abs
local mathFloor = math.floor
local mathMax = math.max

local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ

local TransportAPI

local isFactory = {}
local defHalfX, defHalfZ = {}, {}
for unitDefID, ud in pairs(UnitDefs) do
	if ud.isFactory then
		isFactory[unitDefID] = true
	end
	defHalfX[unitDefID] = ud.xsize * Game.squareSize * 0.5
	defHalfZ[unitDefID] = ud.zsize * Game.squareSize * 0.5
end
local maxFactoryHalf = 0
for unitDefID in pairs(isFactory) do
	maxFactoryHalf = mathMax(maxFactoryHalf, defHalfX[unitDefID], defHalfZ[unitDefID])
end

-- build squares around the target, nearest first
local searchOffsets = {}
do
	local r = mathFloor(SEARCH_RADIUS / BUILD_SQUARE)
	for dz = -r, r do
		for dx = -r, r do
			local d2 = dx * dx + dz * dz
			if d2 <= r * r then
				searchOffsets[#searchOffsets + 1] = { dx * BUILD_SQUARE, dz * BUILD_SQUARE, d2 }
			end
		end
	end
	table.sort(searchOffsets, function(a, b)
		if a[3] ~= b[3] then
			return a[3] < b[3]
		end
		if a[2] ~= b[2] then
			return a[2] < b[2]
		end
		return a[1] < b[1]
	end)
end

local plan -- { cx, cz, scx, scz, shift, frame, pads = { {unitID, padDefID, x, y, z} }, failed = { unitID } }
local ghosts = {} -- pad index -> { id, padDefID, x, z }
local queuedPads = {} -- { padDefID, x, y, z } of unloads the selection already has queued
local press -- a click being tracked, see MousePress

local function isTractorTransport(unitID)
	local seats = spGetUnitRulesParam(unitID, "transporterSeats")
	return seats and seats > 0
end

local function getTransports(units)
	local transports = {}
	for i = 1, #units do
		if isTractorTransport(units[i]) then
			transports[#transports + 1] = units[i]
		end
	end
	return transports
end

local function isLoadCommand(cmdID)
	return cmdID == CMD_AREA_LOAD or cmdID == CMD_LOAD_UNIT or cmdID == CMD_LOAD_WAIT
end

-- mirrors the gadget: an empty transport that is still loading keeps its loads even on an unshifted unload
local function keepsQueuedLoads(unitID, shift)
	if shift then
		return true
	end
	local carried = spGetUnitIsTransporting(unitID)
	if carried and #carried > 0 then
		return false
	end
	local Q = spGetUnitCommands(unitID, 1)
	return Q and Q[1] and isLoadCommand(Q[1].id) or false
end

local function overlaps(x, z, hx, hz, rects)
	for i = 1, #rects do
		local r = rects[i]
		if mathAbs(x - r[1]) < hx + r[3] and mathAbs(z - r[2]) < hz + r[4] then
			return true
		end
	end
	return false
end

local function nearFactory(x, z, hx, hz)
	local reach = FACTORY_YARD_MARGIN + maxFactoryHalf
	local units = spGetUnitsInRectangle(x - hx - reach, z - hz - reach, x + hx + reach, z + hz + reach)
	for i = 1, #units do
		local defID = spGetUnitDefID(units[i]) -- nil for radar dots: unknown, not counted
		if defID and isFactory[defID] then
			local ux, _, uz = spGetUnitPosition(units[i])
			if
				mathAbs(x - ux) < hx + defHalfX[defID] + FACTORY_YARD_MARGIN
				and mathAbs(z - uz) < hz + defHalfZ[defID] + FACTORY_YARD_MARGIN
			then
				return true
			end
		end
	end
	return false
end

---@return number? x
---@return number? y
---@return number? z
---@return integer budgetLeft
local function findPadSpot(padDefID, cx, cz, reserved, budget)
	local hx, hz = defHalfX[padDefID], defHalfZ[padDefID]
	for i = 1, #searchOffsets do
		if budget <= 0 then
			break
		end
		local o = searchOffsets[i]
		local wx, wz = cx + o[1], cz + o[2]
		if wx > hx and wz > hz and wx < mapSizeX - hx and wz < mapSizeZ - hz then
			local bx, by, bz = spPos2BuildPos(padDefID, wx, spGetGroundHeight(wx, wz), wz)
			if not overlaps(bx, bz, hx, hz, reserved) then
				budget = budget - 1
				local status, featureID = spTestBuildOrder(padDefID, bx, by, bz, 0)
				-- a factory with an open yard close by makes ClosestBuildPos move on; it cannot see the yard
				-- state from here, so any factory counts and the spot found is one it keeps
				if (status == FREE or status == MOBILE) and not featureID and not nearFactory(bx, bz, hx, hz) then
					return bx, by, bz, budget
				end
			end
		end
	end
	return nil, nil, nil, budget
end

local function collectQueuedPads(transports)
	local pads = {}
	for i = 1, #transports do
		local unitID = transports[i]
		local Q = spGetUnitCommands(unitID, -1)
		if Q then
			for j = 1, #Q do
				local cmd = Q[j]
				if cmd.id == CMD_UNLOAD_UNIT then
					local padDefID = TransportAPI.GetUnloadPadType(unitID, cmd.params[4], true)
					if padDefID then
						pads[#pads + 1] = { padDefID, cmd.params[1], cmd.params[2], cmd.params[3] }
					end
				end
			end
		end
	end
	return pads
end

local function makePlan(cx, cz, shift)
	local transports = getTransports(spGetSelectedUnits())
	if #transports == 0 then
		return nil
	end

	-- transports with something to drop (now or by the time they get there); empty ones only if all are empty
	local entries = {}
	local anyCargo = false
	for i = 1, #transports do
		local unitID = transports[i]
		local queued = keepsQueuedLoads(unitID, shift)
		local cargo = queued and TransportAPI.GetExpectedCargo(unitID) or spGetUnitIsTransporting(unitID) or {}
		local hasCargo = #cargo > 0
		anyCargo = anyCargo or hasCargo
		entries[#entries + 1] = {
			unitID = unitID,
			hasCargo = hasCargo,
			padDefID = TransportAPI.GetUnloadPadType(unitID, nil, queued),
		}
	end
	local chosen = {}
	for i = 1, #entries do
		local e = entries[i]
		if e.padDefID and (e.hasCargo or not anyCargo) then
			local ux, _, uz = spGetUnitPosition(e.unitID)
			e.dist = (ux - cx) * (ux - cx) + (uz - cz) * (uz - cz)
			chosen[#chosen + 1] = e
		end
	end
	-- big pads claim the inner spots, then the closest transport goes first
	table.sort(chosen, function(a, b)
		local sa, sb = defHalfX[a.padDefID], defHalfX[b.padDefID]
		if sa ~= sb then
			return sa > sb
		end
		return a.dist < b.dist
	end)

	local reserved = {}
	if shift then
		for i = 1, #queuedPads do
			local q = queuedPads[i]
			reserved[#reserved + 1] = { q[2], q[4], defHalfX[q[1]], defHalfZ[q[1]] }
		end
	end

	local newPlan = { cx = cx, cz = cz, shift = shift, frame = spGetGameFrame(), pads = {}, failed = {} }
	local budget = SEARCH_BUDGET
	for i = 1, #chosen do
		local e = chosen[i]
		local x, y, z
		x, y, z, budget = findPadSpot(e.padDefID, cx, cz, reserved, budget)
		if x then
			newPlan.pads[#newPlan.pads + 1] = { e.unitID, e.padDefID, x, y, z }
			reserved[#reserved + 1] = { x, z, defHalfX[e.padDefID], defHalfZ[e.padDefID] }
		else
			newPlan.failed[#newPlan.failed + 1] = e.unitID
		end
	end
	return newPlan
end

local function clearGhosts()
	if not WG.StopDrawUnitShapeGL4 then
		return
	end
	for i, g in pairs(ghosts) do
		WG.StopDrawUnitShapeGL4(g.id)
		ghosts[i] = nil
	end
end

-- pad models where the cargo lands; the outlines in DrawWorld carry it when DrawUnitShape GL4 is off
local function syncGhosts()
	if not WG.DrawUnitShapeGL4 then
		return
	end
	local pads = plan and plan.pads or {}
	local myTeam = spGetMyTeamID()
	for i = 1, #pads do
		local p = pads[i]
		local g = ghosts[i]
		if not g or g.padDefID ~= p[2] or g.x ~= p[3] or g.z ~= p[5] then
			if g then
				WG.StopDrawUnitShapeGL4(g.id)
			end
			ghosts[i] = {
				id = WG.DrawUnitShapeGL4(p[2], p[3], p[4], p[5], 0, 0.55, myTeam, 0.15, 0.3),
				padDefID = p[2],
				x = p[3],
				z = p[5],
			}
		end
	end
	for i, g in pairs(ghosts) do
		if i > #pads then
			WG.StopDrawUnitShapeGL4(g.id)
			ghosts[i] = nil
		end
	end
end

local function isUnloadCmd(cmdID)
	return cmdID == CMD_UNLOAD_UNIT or cmdID == CMD_UNLOAD_UNITS
end

-- "active": the unload button is armed; "default": a right click would unload
local function unloadMode()
	local _, activeCmdID = spGetActiveCommand()
	if activeCmdID then
		return isUnloadCmd(activeCmdID) and "active" or nil
	end
	local _, defaultCmdID = spGetDefaultCommand()
	return isUnloadCmd(defaultCmdID) and "default" or nil
end

local function shiftHeld()
	local _, _, _, shift = spGetModKeyState()
	if spGetInvertQueueKey() then
		shift = not shift
	end
	return shift
end

local function cursorGround(mx, my)
	local _, pos = spTraceScreenRay(mx, my, true)
	if pos and pos[1] then
		return pos[1], pos[3]
	end
end

local function issuePlan(p, options)
	for i = 1, #p.pads do
		local pad = p.pads[i]
		spGiveOrderToUnit(pad[1], CMD_UNLOAD_UNIT, { pad[3], pad[4], pad[5] }, options)
	end
	-- no free spot found here: hand the raw point to the gadget, which searches with everything it knows
	for i = 1, #p.failed do
		spGiveOrderToUnit(p.failed[i], CMD_UNLOAD_UNIT, { p.cx, spGetGroundHeight(p.cx, p.cz), p.cz }, options)
	end
end

function widget:Initialize()
	TransportAPI = WG.TransportAPI
	if not TransportAPI or not TransportAPI.GetExpectedCargo then
		Spring.Echo("Unload Snap and Preview: needs the Transport Handler API, removing")
		widgetHandler:RemoveWidget()
	end
end

function widget:Shutdown()
	clearGhosts()
end

function widget:SelectionChanged()
	plan = nil
end

local lastQueueScan = -math.huge

function widget:Update()
	local frame = spGetGameFrame()
	local mx, my, lmb, _, rmb = spGetMouseState()

	-- custom formations swallows a short unload click when several transports are selected: give it here
	if press then
		local down = (press.button == 1 and lmb) or (press.button == 3 and rmb)
		if not down then
			if not press.notified and not press.formation and press.plan then
				issuePlan(press.plan, press.shift and { "shift" } or {})
			end
			press = nil
		end
	end

	local mode = unloadMode()
	if not mode then
		plan = nil
		queuedPads = {}
		clearGhosts()
		return
	end

	if frame - lastQueueScan >= REPLAN_FRAMES then
		lastQueueScan = frame
		queuedPads = collectQueuedPads(getTransports(spGetSelectedUnits()))
	end

	local cx, cz = cursorGround(mx, my)
	if not cx or (press and press.formation) then
		plan = nil
		clearGhosts()
		return
	end
	local shift = shiftHeld()
	local scx, scz = mathFloor(cx / BUILD_SQUARE), mathFloor(cz / BUILD_SQUARE)
	if not plan or plan.scx ~= scx or plan.scz ~= scz or plan.shift ~= shift or frame - plan.frame >= REPLAN_FRAMES then
		plan = makePlan(cx, cz, shift)
		if plan then
			plan.scx, plan.scz = scx, scz
		end
	end
	syncGhosts()
end

function widget:MousePress(mx, my, button)
	local mode = unloadMode()
	if (button == 1 and mode == "active") or (button == 3 and mode == "default") then
		local cx, cz = cursorGround(mx, my)
		if cx then
			local shift = shiftHeld()
			press = { button = button, shift = shift, plan = makePlan(cx, cz, shift) }
		end
	end
	return false -- custom formations still gets the drag for line unloads
end

-- a drawn line: custom formations hands out one unload per unit, and the gadget snaps each of them
function widget:UnitCommandNotify(unitID, cmdID)
	if press and isUnloadCmd(cmdID) then
		press.formation = true
	end
	return false
end

function widget:CommandNotify(cmdID, params, options)
	if not isUnloadCmd(cmdID) or (cmdID == CMD_UNLOAD_UNIT and params[4]) or not params[3] then
		return false -- not a drop at a point (an unload of one named passenger is gui_info's)
	end
	local p = makePlan(params[1], params[3], options.shift)
	if not p or (#p.pads == 0 and #p.failed == 0) then
		return false
	end
	if press then
		press.notified = true
	end
	issuePlan(p, options.coded)
	return true
end

local function groundY(x, z)
	return mathMax(spGetGroundHeight(x, z), 0) + 2
end

local function padOutline(padDefID, x, z)
	local hx, hz = defHalfX[padDefID], defHalfZ[padDefID]
	local step = BUILD_SQUARE
	gl.BeginEnd(GL.LINE_LOOP, function()
		for px = x - hx, x + hx - 1, step do
			gl.Vertex(px, groundY(px, z - hz), z - hz)
		end
		for pz = z - hz, z + hz - 1, step do
			gl.Vertex(x + hx, groundY(x + hx, pz), pz)
		end
		for px = x + hx, x - hx + 1, -step do
			gl.Vertex(px, groundY(px, z + hz), z + hz)
		end
		for pz = z + hz, z - hz + 1, -step do
			gl.Vertex(x - hx, groundY(x - hx, pz), pz)
		end
	end)
end

function widget:DrawWorld()
	if not plan and #queuedPads == 0 then
		return
	end
	gl.DepthTest(false)

	-- unloads already queued: thin and grey, so the new drop reads apart from them
	gl.LineWidth(1.5)
	gl.Color(0.8, 0.8, 0.8, 0.45)
	for i = 1, #queuedPads do
		local q = queuedPads[i]
		padOutline(q[1], q[2], q[4])
	end

	if plan then
		gl.LineWidth(2.5)
		gl.Color(0.35, 1, 0.45, 0.8)
		for i = 1, #plan.pads do
			local p = plan.pads[i]
			padOutline(p[2], p[3], p[5])
		end

		-- the nearest pad had to move off the cursor: show where to
		local first = plan.pads[1]
		if
			first
			and (mathAbs(first[3] - plan.cx) > defHalfX[first[2]] or mathAbs(first[5] - plan.cz) > defHalfZ[first[2]])
		then
			gl.LineWidth(2)
			gl.Color(1, 1, 0, 0.45)
			gl.BeginEnd(GL.LINES, function()
				gl.Vertex(plan.cx, groundY(plan.cx, plan.cz), plan.cz)
				gl.Vertex(first[3], groundY(first[3], first[5]), first[5])
			end)
		end

		-- some transports found no spot within reach: a cross on the cursor
		if #plan.failed > 0 then
			local s = 24
			local y = groundY(plan.cx, plan.cz)
			gl.LineWidth(3)
			gl.Color(1, 0.3, 0.2, 0.9)
			gl.BeginEnd(GL.LINES, function()
				gl.Vertex(plan.cx - s, y, plan.cz - s)
				gl.Vertex(plan.cx + s, y, plan.cz + s)
				gl.Vertex(plan.cx - s, y, plan.cz + s)
				gl.Vertex(plan.cx + s, y, plan.cz - s)
			end)
		end
	end

	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
	gl.DepthTest(true)
end
