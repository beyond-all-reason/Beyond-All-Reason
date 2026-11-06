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
local spGetUnitHeading = Spring.GetUnitHeading

local mathAbs = math.abs
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathSin = math.sin
local mathCos = math.cos
local mathSqrt = math.sqrt
local mathAtan2 = math.atan2 or math.atan
local HALF_PI = math.pi / 2
local HEADING_TO_RAD = math.pi / 32768

-- same look as the other placement previews: blueprint ghost alpha, the unload command's colour
local GHOST_ALPHA = 0.6
local UNLOAD_R, UNLOAD_G, UNLOAD_B = 1.0, 0.8, 0.0
local DASH, DASH_PERIOD = 14, 24

local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ

local TransportAPI

local isFactory = {}
local isImmobile = {} -- these land on the build grid, facing a cardinal direction
local defHalfX, defHalfZ = {}, {}
for unitDefID, ud in pairs(UnitDefs) do
	if ud.isFactory then
		isFactory[unitDefID] = true
	end
	isImmobile[unitDefID] = ud.speed == 0
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

local plan -- { cx, cz, scx, scz, shift, frame, pads = { {unitID, padDefID, x, y, z, passengerID, spots} }, failed = { entry } }
local ghosts = {} -- { id, defID, x, z, rot }, one per unit about to land
local queuedPads = {} -- { padDefID, x, y, z } of unloads the selection already has queued
local press -- a click being tracked, see MousePress
local drop -- { transportID, passengerID }: one unit picked in the info panel, placed with the unload command
local dropPlaced
local rearmDrop

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
					-- a queued building takes its own footprint, everything else the unload pad
					local buildingDefID = cmd.params[4] and spGetUnitDefID(cmd.params[4])
					local padDefID = buildingDefID and isImmobile[buildingDefID] and buildingDefID
						or TransportAPI.GetUnloadPadType(unitID, cmd.params[4], true)
					if padDefID then
						pads[#pads + 1] = { padDefID, cmd.params[1], cmd.params[2], cmd.params[3] }
					end
				end
			end
		end
	end
	return pads
end

local function isCarrying(transportID, passengerID)
	local carried = spGetUnitIsTransporting(transportID)
	if carried then
		for i = 1, #carried do
			if carried[i] == passengerID then
				return true
			end
		end
	end
	return false
end

local function chooseTransports(cx, cz, shift)
	if drop then
		local padDefID = TransportAPI.GetUnloadPadType(drop[1], drop[2])
		return padDefID and { { unitID = drop[1], padDefID = padDefID, passengerID = drop[2] } }
	end

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
	return chosen
end

-- where each passenger touches down: the animator keeps its offset from the transport, turned to the heading
-- the transport arrives with (facing the pad from where it is now)
local function landingSpots(transportID, passengers, padX, padZ)
	local tx, _, tz = spGetUnitPosition(transportID)
	local spots = {}
	if not tx then
		return spots
	end
	local nowHeading = (spGetUnitHeading(transportID) or 0) * HEADING_TO_RAD
	local dx, dz = padX - tx, padZ - tz
	local arriveHeading = (dx * dx + dz * dz > 64 * 64) and mathAtan2(dx, dz) or nowHeading
	local sa, ca = mathSin(nowHeading), mathCos(nowHeading)
	local sb, cb = mathSin(arriveHeading), mathCos(arriveHeading)
	for i = 1, #passengers do
		local passengerID = passengers[i]
		local defID = spGetUnitDefID(passengerID)
		local px, _, pz = spGetUnitPosition(passengerID)
		if defID and px then
			local ox, oz = px - tx, pz - tz
			local fwd, side = ox * sa + oz * ca, ox * ca - oz * sa
			local x, z = padX + fwd * sb + side * cb, padZ + fwd * cb - side * sb
			local rot = (spGetUnitHeading(passengerID) or 0) * HEADING_TO_RAD - nowHeading + arriveHeading
			local y = mathMax(spGetGroundHeight(x, z), 0)
			if isImmobile[defID] then
				x, y, z = spPos2BuildPos(defID, x, y, z)
				rot = mathFloor(rot / HALF_PI + 0.5) * HALF_PI
			end
			spots[#spots + 1] = { defID, x, y, z, rot }
		end
	end
	return spots
end

-- buildings to set down: one picked in the info panel, or the whole cargo of the only selected transport
-- when all of it is buildings. Returns transportID, { passengerID }
local function buildingsToPlace(shift)
	if drop then
		local defID = spGetUnitDefID(drop[2])
		if defID and isImmobile[defID] then
			return drop[1], { drop[2] }
		end
		return nil
	end
	local transports = getTransports(spGetSelectedUnits())
	if #transports ~= 1 then
		return nil
	end
	local transportID = transports[1]
	local carried = spGetUnitIsTransporting(transportID) or {}
	if
		#carried == 0
		or (keepsQueuedLoads(transportID, shift) and #TransportAPI.GetExpectedCargo(transportID) > #carried)
	then
		return nil
	end
	for i = 1, #carried do
		local defID = spGetUnitDefID(carried[i])
		if not (defID and isImmobile[defID]) then
			return nil
		end
	end
	return transportID, carried
end

local function footprintsOverlap(x1, z1, defID1, x2, z2, defID2)
	return mathAbs(x1 - x2) < defHalfX[defID1] + defHalfX[defID2]
		and mathAbs(z1 - z2) < defHalfZ[defID1] + defHalfZ[defID2]
end

-- buildings go down like a build order: their cargo layout turned to the heading the transport arrives with,
-- spread so footprints don't overlap, each on the grid with its own footprint tested
local function placementPlan(transportID, passengers, cx, cz, shift)
	local tx, _, tz = spGetUnitPosition(transportID)
	if not tx then
		return nil
	end
	local nowHeading = (spGetUnitHeading(transportID) or 0) * HEADING_TO_RAD
	local dx, dz = cx - tx, cz - tz
	local arriveHeading = (dx * dx + dz * dz > 64 * 64) and mathAtan2(dx, dz) or nowHeading
	local sa, ca = mathSin(nowHeading), mathCos(nowHeading)
	local sb, cb = mathSin(arriveHeading), mathCos(arriveHeading)

	local entries, minGap, widest = {}, math.huge, 0
	for i = 1, #passengers do
		local passengerID = passengers[i]
		local defID = spGetUnitDefID(passengerID)
		local px, _, pz = spGetUnitPosition(passengerID)
		if defID and px then
			local ox, oz = px - tx, pz - tz
			local fwd, side = ox * sa + oz * ca, ox * ca - oz * sa
			local rot = (spGetUnitHeading(passengerID) or 0) * HEADING_TO_RAD - nowHeading + arriveHeading
			entries[#entries + 1] = {
				id = passengerID,
				defID = defID,
				ox = fwd * sb + side * cb,
				oz = fwd * cb - side * sb,
				rot = mathFloor(rot / HALF_PI + 0.5) * HALF_PI,
			}
			widest = mathMax(widest, 2 * defHalfX[defID], 2 * defHalfZ[defID])
		end
	end
	if #entries == 0 then
		return nil
	end
	for i = 1, #entries do
		for j = i + 1, #entries do
			local a, b = entries[i], entries[j]
			minGap = math.min(minGap, mathSqrt((a.ox - b.ox) ^ 2 + (a.oz - b.oz) ^ 2))
		end
	end
	local spread = (#entries > 1 and minGap > 0 and minGap < widest) and widest / minGap or 1
	if #entries == 1 then
		entries[1].ox, entries[1].oz = 0, 0
	end

	local newPlan = { cx = cx, cz = cz, shift = shift, frame = spGetGameFrame(), place = true, pads = {}, failed = {} }
	for i = 1, #entries do
		local e = entries[i]
		local wx, wz = cx + e.ox * spread, cz + e.oz * spread
		local bx, by, bz = spPos2BuildPos(e.defID, wx, spGetGroundHeight(wx, wz), wz)
		-- grid snapping can still bring two together: step this one outward until it is clear
		local stepX, stepZ = e.ox >= 0 and BUILD_SQUARE or -BUILD_SQUARE, 0
		if mathAbs(e.oz) > mathAbs(e.ox) then
			stepX, stepZ = 0, e.oz >= 0 and BUILD_SQUARE or -BUILD_SQUARE
		end
		for _ = 1, 8 do
			local clash = false
			for j = 1, #newPlan.pads do
				local q = newPlan.pads[j]
				if footprintsOverlap(bx, bz, e.defID, q[3], q[5], q[2]) then
					clash = true
					break
				end
			end
			if not clash then
				break
			end
			bx, by, bz = spPos2BuildPos(e.defID, bx + stepX, spGetGroundHeight(bx + stepX, bz + stepZ), bz + stepZ)
		end
		local status, featureID = spTestBuildOrder(e.defID, bx, by, bz, 0)
		local fits = (status == FREE or status == MOBILE) and not featureID -- units in the way get pushed aside
		newPlan.place = newPlan.place and fits
		newPlan.pads[#newPlan.pads + 1] =
			{ transportID, e.defID, bx, by, bz, e.id, { { e.defID, bx, by, bz, e.rot } }, fits }
	end
	return newPlan
end

local function makePlan(cx, cz, shift)
	local placeTransport, buildings = buildingsToPlace(shift)
	if placeTransport then
		return placementPlan(placeTransport, buildings, cx, cz, shift)
	end
	local chosen = chooseTransports(cx, cz, shift)
	if not chosen then
		return nil
	end

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
			local cargo = e.passengerID and { e.passengerID } or spGetUnitIsTransporting(e.unitID) or {}
			local spots = landingSpots(e.unitID, cargo, x, z)
			newPlan.pads[#newPlan.pads + 1] = { e.unitID, e.padDefID, x, y, z, e.passengerID, spots }
			reserved[#reserved + 1] = { x, z, defHalfX[e.padDefID], defHalfZ[e.padDefID] }
		else
			newPlan.failed[#newPlan.failed + 1] = e
		end
	end
	return newPlan
end

local function clearGhosts()
	if not WG.StopDrawUnitShapeGL4 then
		return
	end
	for i = #ghosts, 1, -1 do
		if ghosts[i].id then
			WG.StopDrawUnitShapeGL4(ghosts[i].id)
		end
		ghosts[i] = nil
	end
end

-- the cargo as ghosts where it lands; the brackets in DrawWorld carry the preview when DrawUnitShape GL4 is off
local function syncGhosts()
	if not WG.DrawUnitShapeGL4 then
		return
	end
	local pads = plan and plan.pads or {}
	local myTeam = spGetMyTeamID()
	local n = 0
	for i = 1, #pads do
		local spots = pads[i][7]
		for j = 1, #spots do
			local s = spots[j]
			n = n + 1
			local g = ghosts[n]
			if g and g.defID ~= s[1] then
				if g.id then
					WG.StopDrawUnitShapeGL4(g.id)
				end
				g = nil
			end
			if not g or g.x ~= s[2] or g.z ~= s[4] or g.rot ~= s[5] then
				local id = WG.DrawUnitShapeGL4(s[1], s[2], s[3], s[4], s[5], GHOST_ALPHA, myTeam, nil, nil, g and g.id)
				ghosts[n] = { id = id, defID = s[1], x = s[2], z = s[4], rot = s[5] }
			end
		end
	end
	for i = #ghosts, n + 1, -1 do
		if ghosts[i].id then
			WG.StopDrawUnitShapeGL4(ghosts[i].id)
		end
		ghosts[i] = nil
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
	if p.place == false then
		return
	end
	-- buildings: one exact drop each, queued one after another
	if p.place then
		for i = 1, #p.pads do
			local pad = p.pads[i]
			spGiveOrderToUnit(
				pad[1],
				CMD_UNLOAD_UNIT,
				{ pad[3], pad[4], pad[5], pad[6] },
				i == 1 and options or CMD.OPT_SHIFT
			)
		end
		if drop then
			drop = nil
			dropPlaced = true
		end
		return
	end
	for i = 1, #p.pads do
		local pad = p.pads[i]
		spGiveOrderToUnit(pad[1], CMD_UNLOAD_UNIT, { pad[3], pad[4], pad[5], pad[6] }, options)
	end
	-- no free spot found here: hand the raw point to the gadget, which searches with everything it knows
	for i = 1, #p.failed do
		local e = p.failed[i]
		spGiveOrderToUnit(
			e.unitID,
			CMD_UNLOAD_UNIT,
			{ p.cx, spGetGroundHeight(p.cx, p.cz), p.cz, e.passengerID },
			options
		)
	end
	if drop then
		drop = nil
		dropPlaced = true
	end
end

-- the info panel's cargo icons: arm the unload command for one passenger of the selected transport
local function dropUnit(transportID, passengerID)
	local selected = spGetSelectedUnits()
	if #selected ~= 1 or selected[1] ~= transportID or not isTractorTransport(transportID) then
		return false
	end
	if not isCarrying(transportID, passengerID) then
		return false
	end
	-- transports carry the area unload button only; its click comes back here as a point
	local index = Spring.GetCmdDescIndex(CMD_UNLOAD_UNITS)
	if not index or not Spring.SetActiveCommand(index) then
		return false
	end
	drop = { transportID, passengerID }
	plan = nil
	return true
end

function widget:Initialize()
	TransportAPI = WG.TransportAPI
	if not TransportAPI or not TransportAPI.GetExpectedCargo then
		Spring.Echo("Unload Snap and Preview: needs the Transport Handler API, removing")
		widgetHandler:RemoveWidget()
		return
	end
	WG.UnloadSnap = {
		DropUnit = dropUnit,
		GetDrop = function()
			if drop then
				return drop[1], drop[2]
			end
		end,
		-- the drops shown right now: { {transportID, padDefID, x, y, z, passengerID, spots} },
		-- spots = { {unitDefID, x, y, z, rotation} } where each passenger lands
		GetPads = function()
			return plan and plan.pads
		end,
		-- the drops an unload of the selection at x, z would get
		PreviewAt = function(x, z, shift)
			local p = makePlan(x, z, shift)
			return p and p.pads
		end,
	}
end

function widget:Shutdown()
	clearGhosts()
	WG.UnloadSnap = nil
end

function widget:SelectionChanged()
	plan = nil
	drop = nil
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
	-- a single drop is one click; a shift click would leave the unload armed for the whole cargo
	if dropPlaced then
		dropPlaced = nil
		if mode == "active" then
			Spring.SetActiveCommand(0)
			mode = nil
		end
	end
	-- a click on a blocked spot gives no order and leaves the single drop armed, like a build order would
	if rearmDrop then
		rearmDrop = nil
		if drop and mode ~= "active" then
			local index = Spring.GetCmdDescIndex(CMD_UNLOAD_UNITS)
			if index and Spring.SetActiveCommand(index) then
				mode = "active"
			end
		end
	end
	if drop and (mode ~= "active" or not isCarrying(drop[1], drop[2])) then
		drop = nil
		plan = nil
	end
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

local lineReserve -- { time, rects }: pads already handed out along the line being given

-- a drawn line: custom formations hands out one unload per transport; each gets the free pad nearest its point,
-- clear of the pads given to the others on the same line
function widget:UnitCommandNotify(unitID, cmdID, params, options)
	if not isUnloadCmd(cmdID) or not params or not params[3] or (cmdID == CMD_UNLOAD_UNIT and params[4]) then
		return false
	end
	if press then
		press.formation = true
	end
	if not isTractorTransport(unitID) then
		return false
	end
	local shift = options and options.shift
	local now = os.clock()
	if not lineReserve or now - lineReserve.time > 0.25 then
		lineReserve = { rects = {} }
		if shift then
			for i = 1, #queuedPads do
				local q = queuedPads[i]
				lineReserve.rects[#lineReserve.rects + 1] = { q[2], q[4], defHalfX[q[1]], defHalfZ[q[1]] }
			end
		end
	end
	lineReserve.time = now
	local padDefID = TransportAPI.GetUnloadPadType(unitID, nil, keepsQueuedLoads(unitID, shift))
	if not padDefID then
		return false
	end
	local x, y, z = findPadSpot(padDefID, params[1], params[3], lineReserve.rects, SEARCH_BUDGET / 4)
	if not x then
		return false -- the gadget snaps the raw point
	end
	lineReserve.rects[#lineReserve.rects + 1] = { x, z, defHalfX[padDefID], defHalfZ[padDefID] }
	spGiveOrderToUnit(unitID, CMD_UNLOAD_UNIT, { x, y, z }, options and options.coded or 0)
	return true
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
	if p.place == false then
		rearmDrop = drop ~= nil
		return true
	end
	issuePlan(p, options.coded)
	return true
end

local function groundY(x, z)
	return mathMax(spGetGroundHeight(x, z), 0) + 2
end

-- corner brackets of a drop zone, following the ground
local function bracketVertices(x, z, hx, hz)
	local lx, lz = hx * 0.4, hz * 0.4
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			local cx, cz = x + sx * hx, z + sz * hz
			local cy = groundY(cx, cz)
			gl.Vertex(cx - sx * lx, groundY(cx - sx * lx, cz), cz)
			gl.Vertex(cx, cy, cz)
			gl.Vertex(cx, cy, cz)
			gl.Vertex(cx, groundY(cx, cz - sz * lz), cz - sz * lz)
		end
	end
end

local function dashVertices(x1, y1, z1, x2, y2, z2)
	local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
	local len = mathSqrt(dx * dx + dy * dy + dz * dz)
	if len < 1 then
		return
	end
	for d = 0, len, DASH_PERIOD do
		local t1, t2 = d / len, mathMin(d + DASH, len) / len
		gl.Vertex(x1 + dx * t1, y1 + dy * t1, z1 + dz * t1)
		gl.Vertex(x1 + dx * t2, y1 + dy * t2, z1 + dz * t2)
	end
end

-- a building's footprint edge, following the ground
local function footprintVertices(x, z, hx, hz)
	local cornersX = { x - hx, x + hx, x + hx, x - hx }
	local cornersZ = { z - hz, z - hz, z + hz, z + hz }
	for i = 1, 4 do
		local ax, az = cornersX[i], cornersZ[i]
		local bx, bz = cornersX[i % 4 + 1], cornersZ[i % 4 + 1]
		local steps = mathMax(1, mathFloor(mathMax(mathAbs(bx - ax), mathAbs(bz - az)) / 8))
		for s = 0, steps - 1 do
			local x1, z1 = ax + (bx - ax) * s / steps, az + (bz - az) * s / steps
			local x2, z2 = ax + (bx - ax) * (s + 1) / steps, az + (bz - az) * (s + 1) / steps
			gl.Vertex(x1, groundY(x1, z1), z1)
			gl.Vertex(x2, groundY(x2, z2), z2)
		end
	end
end

-- over a soft dark line that keeps it readable on light ground
local function drawLinesColored(fn, width, r, g, b, a, ...)
	gl.LineWidth(width + 2)
	gl.Color(0, 0, 0, a * 0.3)
	gl.BeginEnd(GL.LINES, fn, ...)
	gl.LineWidth(width)
	gl.Color(r, g, b, a)
	gl.BeginEnd(GL.LINES, fn, ...)
end

-- amber like the unload command's queue lines
local function drawLines(fn, width, alpha, ...)
	drawLinesColored(fn, width, UNLOAD_R, UNLOAD_G, UNLOAD_B, alpha, ...)
end

local function drawBrackets(padDefID, x, z, width, alpha)
	drawLines(bracketVertices, width, alpha, x, z, defHalfX[padDefID], defHalfZ[padDefID])
end

-- a building placed like a build order: green where it can go, red where it cannot (blueprint colours)
local function drawFootprint(defID, x, z, placeable)
	local hx, hz = defHalfX[defID], defHalfZ[defID]
	local r, g, b = 0.0, 1.0, 0.0
	if not placeable then
		r, g, b = 1.0, 0.0, 0.0
	end
	gl.Color(r, g, b, 0.12)
	gl.BeginEnd(GL.QUADS, function()
		gl.Vertex(x - hx, groundY(x - hx, z - hz), z - hz)
		gl.Vertex(x + hx, groundY(x + hx, z - hz), z - hz)
		gl.Vertex(x + hx, groundY(x + hx, z + hz), z + hz)
		gl.Vertex(x - hx, groundY(x - hx, z + hz), z + hz)
	end)
	drawLinesColored(footprintVertices, 2, r, g, b, 0.9, x, z, hx, hz)
end

function widget:DrawWorld()
	if not plan and #queuedPads == 0 then
		return
	end
	gl.DepthTest(false)

	-- unloads already queued: faint, so the new drop reads apart from them
	for i = 1, #queuedPads do
		local q = queuedPads[i]
		drawBrackets(q[1], q[2], q[4], 1.5, 0.3)
	end

	if plan then
		for i = 1, #plan.pads do
			local p = plan.pads[i]
			if plan.place ~= nil then
				drawFootprint(p[2], p[3], p[5], p[8])
			else
				drawBrackets(p[2], p[3], p[5], 2, 0.85)
			end
			-- which transport drops here (buildings: one line, to the cursor)
			local tx, ty, tz = spGetUnitPosition(p[1])
			if tx and plan.place == nil then
				drawLines(dashVertices, 1.5, 0.4, tx, ty, tz, p[3], groundY(p[3], p[5]), p[5])
			elseif tx and i == 1 then
				drawLines(dashVertices, 1.5, 0.4, tx, ty, tz, plan.cx, groundY(plan.cx, plan.cz), plan.cz)
			end
		end

		-- the nearest drop had to move off the cursor: show where to
		local first = plan.pads[1]
		if
			first
			and plan.place == nil
			and (mathAbs(first[3] - plan.cx) > defHalfX[first[2]] or mathAbs(first[5] - plan.cz) > defHalfZ[first[2]])
		then
			drawLines(
				dashVertices,
				1.5,
				0.6,
				plan.cx,
				groundY(plan.cx, plan.cz),
				plan.cz,
				first[3],
				groundY(first[3], first[5]),
				first[5]
			)
		end

		-- some transports found no spot within reach: a cross on the cursor
		if #plan.failed > 0 then
			local s = 20
			local y = groundY(plan.cx, plan.cz)
			gl.LineWidth(2.5)
			gl.Color(1, 0.25, 0.2, 0.9)
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
