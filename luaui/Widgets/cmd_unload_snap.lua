local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unload Snap and Preview",
		desc = "Shows where each selected tractor beam transport will set its cargo down, and sends it exactly there",
		author = "DoodVanDaag, PtaQ",
		version = "v2.0",
		date = "November 2026",
		license = "GNU GPL, v2 or later",
		layer = -1, -- takes the unload before Area Unload and Custom Formations split it their own way
		enabled = true,
	}
end

if Spring.GetModOptions().beta_tractorbeam == "disabled" then
	return false
end

-- Each transport is ordered straight to a free pad spot, which the gadget's ClosestBuildPos keeps,
-- so the ghost is where the cargo lands. Search with TestBuildOrder only: it is LOS aware here, ClosestBuildPos is not.

local CMD_UNLOAD_UNIT = CMD.UNLOAD_UNIT
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_AREA_LOAD = GameCMD.TRANSPORT_AREA_LOAD
local CMD_LOAD_UNIT = GameCMD.TRANSPORT_LOAD_UNIT
local CMD_LOAD_WAIT = GameCMD.TRANSPORT_LOAD_WAIT

local SEARCH_RADIUS = 512 -- same radius the gadget snaps with
local BUILD_SQUARE = Game.squareSize * 2
local FACTORY_YARD_MARGIN = Game.squareSize * 2 -- ClosestBuildPos keeps 2 squares off factories with an open yard
local SEARCH_BUDGET = 6000 -- TestBuildOrder calls per plan, all transports together
local LINE_BUDGET = SEARCH_BUDGET / 4 -- per transport of a drawn line, which plans many at once
local REPLAN_FRAMES = 15 -- cargo and queues change without a cursor move
local RECENT_SECONDS = 2 -- an order shows up in the queue only after a round trip; hold its pad until then
local ARRIVE_TURN_DIST = 64 -- closer than this the transport arrives without turning to face the pad
local CROSS_SIZE = 20

-- TestBuildOrder: 0 blocked, 1 mobile unit in the way, 2 free; a feature comes back as a 2nd value
-- (ClosestBuildPos never keeps such a spot)
local MOBILE, FREE = 1, 2

local spGetActiveCommand = Spring.GetActiveCommand
local spGetDefaultCommand = Spring.GetDefaultCommand
local spSetActiveCommand = Spring.SetActiveCommand
local spGetCmdDescIndex = Spring.GetCmdDescIndex
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spIsAboveMiniMap = Spring.IsAboveMiniMap
local spPos2BuildPos = Spring.Pos2BuildPos
local spTestBuildOrder = Spring.TestBuildOrder
local spGetGroundHeight = Spring.GetGroundHeight
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetModKeyState = Spring.GetModKeyState
local spGetInvertQueueKey = Spring.GetInvertQueueKey
local spGetGameFrame = Spring.GetGameFrame
local spGetDrawFrame = Spring.GetDrawFrame
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spGetMyTeamID = Spring.GetMyTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spIsGUIHidden = Spring.IsGUIHidden
local spGetUnitHeading = Spring.GetUnitHeading
local spGetBuildFacing = Spring.GetBuildFacing
local spSetBuildFacing = Spring.SetBuildFacing

local mathAbs = math.abs
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathSin = math.sin
local mathCos = math.cos
local mathSqrt = math.sqrt
local mathAtan2 = math.atan2
local HALF_PI = math.pi / 2

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
	local radius = mathFloor(SEARCH_RADIUS / BUILD_SQUARE)
	for dz = -radius, radius do
		for dx = -radius, radius do
			local dist2 = dx * dx + dz * dz
			if dist2 <= radius * radius then
				searchOffsets[#searchOffsets + 1] = { dx = dx * BUILD_SQUARE, dz = dz * BUILD_SQUARE, dist2 = dist2 }
			end
		end
	end
	table.sort(searchOffsets, function(a, b)
		if a.dist2 ~= b.dist2 then
			return a.dist2 < b.dist2
		end
		if a.dz ~= b.dz then
			return a.dz < b.dz
		end
		return a.dx < b.dx
	end)
end

---@class UnloadSpot
---@field defID number
---@field x number
---@field y number
---@field z number
---@field rot number

---@class UnloadPad
---@field transportID number
---@field padDefID number the unload pad, or the building's own def when placed like a build order
---@field x number
---@field y number
---@field z number
---@field passengerID number? a single named drop
---@field spots UnloadSpot[] where each passenger lands
---@field fits boolean? a building's spot is free
---@field facing number? build facing of a building

-- plan = { cx, cz, squareX, squareZ, shift, frame, facing?, place?, pads = UnloadPad[], failed = { entry } }
-- place: nil for cargo on pads, true/false for buildings placed like a build order (false = blocked)
local plan
local ghosts = {} -- { id, defID, x, z, rot }, one per unit about to land
local queuedPads = {} -- { padDefID, x, y, z, facing } of unloads the selection already has queued
local recentPads = {} -- pads just ordered, until the queue shows them: { pad, timer }
local press -- a right press that custom formations may swallow, see Update
local drop -- { transportID, passengerID }: one unit picked in the info panel, placed with the unload command
local dropPlaced -- disarm after a single drop
local rearmDrop -- re-arm after a click on a blocked building spot
local lineReserve -- pads already handed out along the line custom formations is giving
local testCache, testCacheFrame = {}, -math.huge

local function getTransports(units)
	local transports = {}
	for i = 1, #units do
		if TransportAPI.IsTractorTransport(units[i]) then
			transports[#transports + 1] = units[i]
		end
	end
	return transports
end

local function isLoadCommand(cmdID)
	return cmdID == CMD_AREA_LOAD or cmdID == CMD_LOAD_UNIT or cmdID == CMD_LOAD_WAIT
end

-- mirrors the gadget: an empty transport with exactly one load queued keeps it on an unshifted unload
local function keepsQueuedLoads(unitID, shift)
	if shift then
		return true
	end
	local carried = spGetUnitIsTransporting(unitID)
	if carried and #carried > 0 then
		return false
	end
	local queue = spGetUnitCommands(unitID, 2)
	return queue ~= nil and #queue == 1 and isLoadCommand(queue[1].id)
end

-- footprint half sizes turned to a build facing (1 and 3 swap x and z)
local function footprintHalf(defID, facing)
	if facing and facing % 2 == 1 then
		return defHalfZ[defID], defHalfX[defID]
	end
	return defHalfX[defID], defHalfZ[defID]
end

local function padRect(pad)
	local hx, hz = footprintHalf(pad.padDefID, pad.facing)
	return { x = pad.x, z = pad.z, hx = hx, hz = hz }
end

local function overlaps(x, z, hx, hz, rects)
	for i = 1, #rects do
		local rect = rects[i]
		if mathAbs(x - rect.x) < hx + rect.hx and mathAbs(z - rect.z) < hz + rect.hz then
			return true
		end
	end
	return false
end

local function queuedRects()
	local rects = {}
	for i = 1, #queuedPads do
		rects[i] = padRect(queuedPads[i])
	end
	return rects
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

-- a spot the gadget keeps as it is: free or only units in the way, no feature, off factory yards.
-- Cached for a few frames: hovering re-tests the same squares many times.
local function spotFree(defID, x, y, z, facing)
	local frame = spGetGameFrame()
	if frame - testCacheFrame >= REPLAN_FRAMES then
		testCache, testCacheFrame = {}, frame
	end
	local key = ((defID * 4 + facing) * 65536 + mathFloor(x)) * 65536 + mathFloor(z)
	local free = testCache[key]
	if free == nil then
		local status, featureID = spTestBuildOrder(defID, x, y, z, facing)
		local hx, hz = footprintHalf(defID, facing)
		free = (status == FREE or status == MOBILE) and not featureID and not nearFactory(x, z, hx, hz)
		testCache[key] = free
	end
	return free
end

local function findPadSpot(padDefID, cx, cz, reserved, budget)
	local hx, hz = defHalfX[padDefID], defHalfZ[padDefID]
	for i = 1, #searchOffsets do
		if budget <= 0 then
			break
		end
		local offset = searchOffsets[i]
		local wx, wz = cx + offset.dx, cz + offset.dz
		if wx > hx and wz > hz and wx < mapSizeX - hx and wz < mapSizeZ - hz then
			local bx, by, bz = spPos2BuildPos(padDefID, wx, spGetGroundHeight(wx, wz), wz)
			if not overlaps(bx, bz, hx, hz, reserved) then
				budget = budget - 1
				if spotFree(padDefID, bx, by, bz, 0) then
					return bx, by, bz, budget
				end
			end
		end
	end
	return nil, nil, nil, budget
end

local function rememberIssued(pad)
	local queued = { padDefID = pad.padDefID, x = pad.x, y = pad.y, z = pad.z, facing = pad.facing }
	recentPads[#recentPads + 1] = { pad = queued, timer = spGetTimer() }
	queuedPads[#queuedPads + 1] = queued
end

local function collectQueuedPads(transports)
	local pads = {}
	for i = 1, #transports do
		local unitID = transports[i]
		local queue = spGetUnitCommands(unitID, -1)
		if queue then
			for j = 1, #queue do
				local cmd = queue[j]
				if cmd.id == CMD_UNLOAD_UNIT then
					-- a queued building takes its own footprint, everything else the unload pad
					local buildingDefID = cmd.params[4] and spGetUnitDefID(cmd.params[4])
					local isBuilding = buildingDefID and isImmobile[buildingDefID]
					local padDefID = isBuilding and buildingDefID
						or TransportAPI.GetUnloadPadType(unitID, cmd.params[4], true)
					if padDefID then
						pads[#pads + 1] = {
							padDefID = padDefID,
							x = cmd.params[1],
							y = cmd.params[2],
							z = cmd.params[3],
							facing = isBuilding and cmd.params[5] or nil,
						}
					end
				end
			end
		end
	end
	local now = spGetTimer()
	for i = #recentPads, 1, -1 do
		if spDiffTimers(now, recentPads[i].timer) > RECENT_SECONDS then
			table.remove(recentPads, i)
		else
			pads[#pads + 1] = recentPads[i].pad
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
		local entry = entries[i]
		local ux, _, uz = spGetUnitPosition(entry.unitID)
		if ux and entry.padDefID and (entry.hasCargo or not anyCargo) then
			entry.dist = (ux - cx) * (ux - cx) + (uz - cz) * (uz - cz)
			chosen[#chosen + 1] = entry
		end
	end
	-- big pads claim the inner spots, then the closest transport goes first
	table.sort(chosen, function(a, b)
		local sizeA, sizeB = defHalfX[a.padDefID], defHalfX[b.padDefID]
		if sizeA ~= sizeB then
			return sizeA > sizeB
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
	local nowHeading = spGetUnitHeading(transportID, true) or 0
	local dx, dz = padX - tx, padZ - tz
	local turns = dx * dx + dz * dz > ARRIVE_TURN_DIST * ARRIVE_TURN_DIST
	local arriveHeading = turns and mathAtan2(dx, dz) or nowHeading
	local sinNow, cosNow = mathSin(nowHeading), mathCos(nowHeading)
	local sinArrive, cosArrive = mathSin(arriveHeading), mathCos(arriveHeading)
	for i = 1, #passengers do
		local passengerID = passengers[i]
		local defID = spGetUnitDefID(passengerID)
		local px, _, pz = spGetUnitPosition(passengerID)
		if defID and px then
			local ox, oz = px - tx, pz - tz
			local fwd, side = ox * sinNow + oz * cosNow, ox * cosNow - oz * sinNow
			local x = padX + fwd * sinArrive + side * cosArrive
			local z = padZ + fwd * cosArrive - side * sinArrive
			local rot = (spGetUnitHeading(passengerID, true) or 0) - nowHeading + arriveHeading
			local y = mathMax(spGetGroundHeight(x, z), 0)
			if isImmobile[defID] then
				x, y, z = spPos2BuildPos(defID, x, y, z)
				rot = mathFloor(rot / HALF_PI + 0.5) * HALF_PI
			end
			spots[#spots + 1] = { defID = defID, x = x, y = y, z = z, rot = rot }
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

local function footprintsOverlap(x1, z1, defID1, x2, z2, defID2, facing)
	local hx1, hz1 = footprintHalf(defID1, facing)
	local hx2, hz2 = footprintHalf(defID2, facing)
	return mathAbs(x1 - x2) < hx1 + hx2 and mathAbs(z1 - z2) < hz1 + hz2
end

-- buildings go down like a build order: laid out as they sit in the transport, turned by the build facing
-- (the build rotate keys), spread so footprints don't overlap, each on the grid with its own footprint tested
local function placementPlan(transportID, passengers, cx, cz, shift)
	local tx, _, tz = spGetUnitPosition(transportID)
	if not tx then
		return nil
	end
	local facing = spGetBuildFacing() or 0
	local nowHeading = spGetUnitHeading(transportID, true) or 0
	local facingAngle = facing * HALF_PI
	local sinNow, cosNow = mathSin(nowHeading), mathCos(nowHeading)
	local sinFacing, cosFacing = mathSin(facingAngle), mathCos(facingAngle)

	local entries, minGap, widest = {}, math.huge, 0
	for i = 1, #passengers do
		local passengerID = passengers[i]
		local defID = spGetUnitDefID(passengerID)
		local px, _, pz = spGetUnitPosition(passengerID)
		if defID and px then
			local ox, oz = px - tx, pz - tz
			local fwd, side = ox * sinNow + oz * cosNow, ox * cosNow - oz * sinNow
			entries[#entries + 1] = {
				id = passengerID,
				defID = defID,
				ox = fwd * sinFacing + side * cosFacing,
				oz = fwd * cosFacing - side * sinFacing,
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
			minGap = mathMin(minGap, mathSqrt((a.ox - b.ox) ^ 2 + (a.oz - b.oz) ^ 2))
		end
	end
	local spread = (#entries > 1 and minGap > 0 and minGap < widest) and widest / minGap or 1
	if #entries == 1 then
		entries[1].ox, entries[1].oz = 0, 0
	end

	local reserved = shift and queuedRects() or {}
	local newPlan = {
		cx = cx,
		cz = cz,
		shift = shift,
		facing = facing,
		frame = spGetGameFrame(),
		place = true,
		pads = {},
		failed = {},
	}
	for i = 1, #entries do
		local entry = entries[i]
		local wx, wz = cx + entry.ox * spread, cz + entry.oz * spread
		local bx, by, bz = spPos2BuildPos(entry.defID, wx, spGetGroundHeight(wx, wz), wz, facing)
		-- grid snapping can still bring two together: step this one outward until it is clear
		local stepX, stepZ = entry.ox >= 0 and BUILD_SQUARE or -BUILD_SQUARE, 0
		if mathAbs(entry.oz) > mathAbs(entry.ox) then
			stepX, stepZ = 0, entry.oz >= 0 and BUILD_SQUARE or -BUILD_SQUARE
		end
		for _ = 1, 8 do
			local clash = false
			for j = 1, #newPlan.pads do
				local other = newPlan.pads[j]
				if footprintsOverlap(bx, bz, entry.defID, other.x, other.z, other.padDefID, facing) then
					clash = true
					break
				end
			end
			if not clash then
				break
			end
			local nx, nz = bx + stepX, bz + stepZ
			bx, by, bz = spPos2BuildPos(entry.defID, nx, spGetGroundHeight(nx, nz), nz, facing)
		end
		local hx, hz = footprintHalf(entry.defID, facing)
		-- units in the way get pushed aside
		local fits = spotFree(entry.defID, bx, by, bz, facing) and not overlaps(bx, bz, hx, hz, reserved)
		newPlan.place = newPlan.place and fits
		newPlan.pads[#newPlan.pads + 1] = {
			transportID = transportID,
			padDefID = entry.defID,
			x = bx,
			y = by,
			z = bz,
			passengerID = entry.id,
			spots = { { defID = entry.defID, x = bx, y = by, z = bz, rot = facingAngle } },
			fits = fits,
			facing = facing,
		}
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

	local reserved = shift and queuedRects() or {}
	local newPlan = { cx = cx, cz = cz, shift = shift, frame = spGetGameFrame(), pads = {}, failed = {} }
	local budget = SEARCH_BUDGET
	for i = 1, #chosen do
		local entry = chosen[i]
		local x, y, z
		x, y, z, budget = findPadSpot(entry.padDefID, cx, cz, reserved, budget)
		if x then
			local cargo = entry.passengerID and { entry.passengerID } or spGetUnitIsTransporting(entry.unitID) or {}
			local pad = {
				transportID = entry.unitID,
				padDefID = entry.padDefID,
				x = x,
				y = y,
				z = z,
				passengerID = entry.passengerID,
				spots = landingSpots(entry.unitID, cargo, x, z),
			}
			newPlan.pads[#newPlan.pads + 1] = pad
			reserved[#reserved + 1] = padRect(pad)
		else
			newPlan.failed[#newPlan.failed + 1] = entry
		end
	end
	return newPlan
end

local function clearGhosts()
	for i = #ghosts, 1, -1 do
		if ghosts[i].id and WG.StopDrawUnitShapeGL4 then
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
	if WG.TransportSettings and WG.TransportSettings.ghosts == false then
		clearGhosts()
		return
	end
	local pads = plan and plan.pads or {}
	local myTeam = spGetMyTeamID()
	local count = 0
	for i = 1, #pads do
		local spots = pads[i].spots
		for j = 1, #spots do
			local spot = spots[j]
			count = count + 1
			local ghost = ghosts[count]
			if ghost and ghost.defID ~= spot.defID then
				if ghost.id then
					WG.StopDrawUnitShapeGL4(ghost.id)
				end
				ghost = nil
			end
			if not ghost or ghost.x ~= spot.x or ghost.z ~= spot.z or ghost.rot ~= spot.rot then
				local id = WG.DrawUnitShapeGL4(
					spot.defID,
					spot.x,
					spot.y,
					spot.z,
					spot.rot,
					GHOST_ALPHA,
					myTeam,
					nil,
					nil,
					ghost and ghost.id
				)
				ghosts[count] = { id = id, defID = spot.defID, x = spot.x, z = spot.z, rot = spot.rot }
			end
		end
	end
	for i = #ghosts, count + 1, -1 do
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

-- transports only have the area unload button; CommandNotify gets its click as a point
local function armUnload()
	local index = spGetCmdDescIndex(CMD_UNLOAD_UNITS)
	return index ~= nil and spSetActiveCommand(index)
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

local function finishDrop()
	if drop then
		drop = nil
		dropPlaced = true
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
				pad.transportID,
				CMD_UNLOAD_UNIT,
				{ pad.x, pad.y, pad.z, pad.passengerID, p.facing },
				i == 1 and options or CMD.OPT_SHIFT
			)
			rememberIssued(pad)
		end
		finishDrop()
		return
	end
	for i = 1, #p.pads do
		local pad = p.pads[i]
		spGiveOrderToUnit(pad.transportID, CMD_UNLOAD_UNIT, { pad.x, pad.y, pad.z, pad.passengerID }, options)
		rememberIssued(pad)
	end
	-- no free spot found here: hand the raw point to the gadget, which searches with everything it knows
	for i = 1, #p.failed do
		local entry = p.failed[i]
		spGiveOrderToUnit(
			entry.unitID,
			CMD_UNLOAD_UNIT,
			{ p.cx, spGetGroundHeight(p.cx, p.cz), p.cz, entry.passengerID },
			options
		)
	end
	finishDrop()
end

-- the info panel's cargo icons: arm the unload command for one passenger of the selected transport
local function dropUnit(transportID, passengerID)
	local selected = spGetSelectedUnits()
	if #selected ~= 1 or selected[1] ~= transportID or not TransportAPI.IsTractorTransport(transportID) then
		return false
	end
	if not isCarrying(transportID, passengerID) or not armUnload() then
		return false
	end
	drop = { transportID, passengerID }
	plan = nil
	return true
end

local FACING_NAMES = { south = 0, east = 1, north = 2, west = 3 }

-- the build rotate keys (any binding of the buildfacing action) turn buildings being placed from a transport
local function handleFacingAction(_, _, args)
	if not (plan and plan.place ~= nil and unloadMode()) then
		return
	end
	local facing = spGetBuildFacing() or 0
	local newFacing
	if args and args[1] == "inc" then
		newFacing = (facing + 1) % 4
	elseif args and args[1] == "dec" then
		newFacing = (facing - 1) % 4
	elseif args and FACING_NAMES[args[1]] then
		newFacing = FACING_NAMES[args[1]]
	end
	if newFacing then
		spSetBuildFacing(newFacing)
		Spring.PlaySoundFile("LuaUI/Sounds/buildbar_hover.wav", 0.75, nil, nil, nil, nil, nil, nil, "ui")
		return true
	end
end

function widget:Initialize()
	TransportAPI = WG.TransportAPI
	if not TransportAPI then
		widgetHandler:RemoveWidget()
		return
	end
	widgetHandler.actionHandler:AddAction(self, "buildfacing", handleFacingAction, nil, "p")
	WG.UnloadSnap = {
		DropUnit = dropUnit,
		GetDrop = function()
			if drop then
				return drop[1], drop[2]
			end
		end,
		---@return UnloadPad[]? the drops shown right now
		GetPads = function()
			return plan and plan.pads
		end,
		-- test hook: the drops an unload of the selection at x, z would get
		PreviewAt = function(x, z, shift)
			local p = makePlan(x, z, shift)
			return p and p.pads
		end,
	}
end

function widget:Shutdown()
	clearGhosts()
	WG.UnloadSnap = nil
	widgetHandler.actionHandler:RemoveAction(self, "buildfacing", "p")
end

function widget:SelectionChanged()
	plan = nil
	drop = nil
end

local lastQueueScan = -math.huge

local function isFormationsWidget(w)
	return w and w.whInfo and w.whInfo.name == "CustomFormations2"
end

function widget:Update()
	local mx, my, _, _, rmb = spGetMouseState()
	lineReserve = nil -- custom formations gives a whole line inside one mouse release

	-- custom formations swallows a short unload click when several transports are selected: give it here
	if press then
		local owner = widgetHandler.mouseOwner
		if owner and not isFormationsWidget(owner) then
			press.otherOwner = true
		end
		if not rmb then
			if not press.notified and not press.formation and not press.otherOwner and plan then
				issuePlan(plan, plan.shift and { "shift" } or {})
			end
			press = nil
		end
	end

	local mode = unloadMode()
	if spGetSpectatingState() then
		mode = nil
	end
	-- a single drop is one click; a shift click would leave the unload armed for the whole cargo
	if dropPlaced then
		dropPlaced = nil
		if mode == "active" then
			spSetActiveCommand(0)
			mode = nil
		end
	end
	-- a click on a blocked spot gives no order and leaves the single drop armed, like a build order would
	if rearmDrop then
		rearmDrop = nil
		if drop and mode ~= "active" and armUnload() then
			mode = "active"
		end
	end
	if drop and (mode ~= "active" or not isCarrying(drop[1], drop[2])) then
		drop = nil
		plan = nil
	end
	if not mode then
		plan = nil
		if #queuedPads > 0 then
			queuedPads = {}
		end
		clearGhosts()
		return
	end

	-- by draw frame: the preview keeps up while paused
	local drawFrame = spGetDrawFrame()
	if drawFrame - lastQueueScan >= REPLAN_FRAMES then
		lastQueueScan = drawFrame
		queuedPads = collectQueuedPads(getTransports(spGetSelectedUnits()))
	end

	local cx, cz = cursorGround(mx, my)
	if not cx or (press and press.formation) then
		plan = nil
		clearGhosts()
		return
	end
	local shift = shiftHeld()
	local squareX, squareZ = mathFloor(cx / BUILD_SQUARE), mathFloor(cz / BUILD_SQUARE)
	if
		not plan
		or plan.squareX ~= squareX
		or plan.squareZ ~= squareZ
		or plan.shift ~= shift
		or (plan.facing and plan.facing ~= spGetBuildFacing())
		or spGetGameFrame() - plan.frame >= REPLAN_FRAMES
	then
		plan = makePlan(cx, cz, shift)
		if plan then
			plan.squareX, plan.squareZ = squareX, squareZ
		end
	end
	syncGhosts()
end

function widget:MousePress(mx, my, button)
	if
		button == 3
		and unloadMode() == "default"
		and not widgetHandler:IsAbove(mx, my)
		and not spIsAboveMiniMap(mx, my)
	then
		press = {}
	end
	return false -- custom formations still gets the drag for line unloads
end

-- a drawn line: custom formations hands out one unload per transport; each gets the free pad nearest its point,
-- clear of the pads given to the others on the same line
function widget:UnitCommandNotify(unitID, cmdID, params, options)
	if not isUnloadCmd(cmdID) or not params or not params[3] or (cmdID == CMD_UNLOAD_UNIT and params[4]) then
		return false
	end
	if press then
		press.formation = true
	end
	if not TransportAPI.IsTractorTransport(unitID) then
		return false
	end
	local shift = options.shift
	if not lineReserve then
		lineReserve = shift and queuedRects() or {}
	end
	local padDefID = TransportAPI.GetUnloadPadType(unitID, nil, keepsQueuedLoads(unitID, shift))
	if not padDefID then
		return false
	end
	local x, y, z = findPadSpot(padDefID, params[1], params[3], lineReserve, LINE_BUDGET)
	if not x then
		return false -- the gadget snaps the raw point
	end
	local pad = { padDefID = padDefID, x = x, y = y, z = z }
	lineReserve[#lineReserve + 1] = padRect(pad)
	spGiveOrderToUnit(unitID, CMD_UNLOAD_UNIT, { x, y, z }, options.coded)
	rememberIssued(pad)
	return true
end

-- other transports in the selection still get the plain order
local function passToOtherTransports(cmdID, params, options)
	if drop then
		return
	end
	local selected = spGetSelectedUnits()
	for i = 1, #selected do
		local unitID = selected[i]
		local carried = spGetUnitIsTransporting(unitID)
		if carried and #carried > 0 and not TransportAPI.IsTractorTransport(unitID) then
			spGiveOrderToUnit(unitID, cmdID, params, options.coded)
		end
	end
end

function widget:CommandNotify(cmdID, params, options)
	if not isUnloadCmd(cmdID) or (cmdID == CMD_UNLOAD_UNIT and params[4]) or not params[3] then
		return false -- not a drop at a point (an unload of one named passenger is gui_info's)
	end
	local p = plan
	if
		not p
		or p.shift ~= options.shift
		or p.squareX ~= mathFloor(params[1] / BUILD_SQUARE)
		or p.squareZ ~= mathFloor(params[3] / BUILD_SQUARE)
	then
		p = makePlan(params[1], params[3], options.shift)
	end
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
	passToOtherTransports(cmdID, params, options)
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

local cornersX, cornersZ = {}, {}

-- a building's footprint edge, following the ground
local function footprintVertices(x, z, hx, hz)
	cornersX[1], cornersX[2], cornersX[3], cornersX[4] = x - hx, x + hx, x + hx, x - hx
	cornersZ[1], cornersZ[2], cornersZ[3], cornersZ[4] = z - hz, z - hz, z + hz, z + hz
	for i = 1, 4 do
		local ax, az = cornersX[i], cornersZ[i]
		local bx, bz = cornersX[i % 4 + 1], cornersZ[i % 4 + 1]
		local steps = mathMax(1, mathFloor(mathMax(mathAbs(bx - ax), mathAbs(bz - az)) / 8))
		for step = 0, steps - 1 do
			local x1, z1 = ax + (bx - ax) * step / steps, az + (bz - az) * step / steps
			local x2, z2 = ax + (bx - ax) * (step + 1) / steps, az + (bz - az) * (step + 1) / steps
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

local function drawBrackets(pad, width, alpha)
	local hx, hz = footprintHalf(pad.padDefID, pad.facing)
	drawLines(bracketVertices, width, alpha, pad.x, pad.z, hx, hz)
end

-- a building placed like a build order: green where it can go, red where it cannot (blueprint colours)
local function drawFootprint(defID, x, z, placeable, facing)
	local hx, hz = footprintHalf(defID, facing)
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

local function crossVertices(x, y, z)
	gl.Vertex(x - CROSS_SIZE, y, z - CROSS_SIZE)
	gl.Vertex(x + CROSS_SIZE, y, z + CROSS_SIZE)
	gl.Vertex(x - CROSS_SIZE, y, z + CROSS_SIZE)
	gl.Vertex(x + CROSS_SIZE, y, z - CROSS_SIZE)
end

function widget:DrawWorld()
	if (not plan and #queuedPads == 0) or spIsGUIHidden() then
		return
	end
	gl.DepthTest(false)

	-- faint, so the new drop reads apart from them
	for i = 1, #queuedPads do
		drawBrackets(queuedPads[i], 1.5, 0.3)
	end

	if plan then
		for i = 1, #plan.pads do
			local pad = plan.pads[i]
			if plan.place ~= nil then
				drawFootprint(pad.padDefID, pad.x, pad.z, pad.fits, plan.facing)
			else
				drawBrackets(pad, 2, 0.85)
			end
			-- a line from the transport (for buildings one, to the cursor)
			local tx, ty, tz = spGetUnitPosition(pad.transportID)
			if tx and plan.place == nil then
				drawLines(dashVertices, 1.5, 0.4, tx, ty, tz, pad.x, groundY(pad.x, pad.z), pad.z)
			elseif tx and i == 1 then
				drawLines(dashVertices, 1.5, 0.4, tx, ty, tz, plan.cx, groundY(plan.cx, plan.cz), plan.cz)
			end
		end

		-- the nearest drop had to move off the cursor: show where to
		local first = plan.pads[1]
		if
			first
			and plan.place == nil
			and (
				mathAbs(first.x - plan.cx) > defHalfX[first.padDefID]
				or mathAbs(first.z - plan.cz) > defHalfZ[first.padDefID]
			)
		then
			local cursorY, firstY = groundY(plan.cx, plan.cz), groundY(first.x, first.z)
			drawLines(dashVertices, 1.5, 0.6, plan.cx, cursorY, plan.cz, first.x, firstY, first.z)
		end

		-- some transports found no spot within reach
		if #plan.failed > 0 then
			drawLinesColored(crossVertices, 2.5, 1, 0.25, 0.2, 0.9, plan.cx, groundY(plan.cx, plan.cz), plan.cz)
		end
	end

	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
	gl.DepthTest(true)
end
