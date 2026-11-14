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

local TransportUI = VFS.Include("luaui/Include/transport_ui.lua")

local CMD_UNLOAD_UNIT = CMD.UNLOAD_UNIT
local UNLOAD_COMMANDS = { [CMD.UNLOAD_UNIT] = true, [CMD.UNLOAD_UNITS] = true }
local LOAD_COMMANDS = {
	[GameCMD.TRANSPORT_AREA_LOAD] = true,
	[GameCMD.TRANSPORT_LOAD_UNIT] = true,
	[GameCMD.TRANSPORT_LOAD_WAIT] = true,
}

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

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHeading = Spring.GetUnitHeading
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spSetActiveCommand = Spring.SetActiveCommand
local spPos2BuildPos = Spring.Pos2BuildPos
local spTestBuildOrder = Spring.TestBuildOrder
local spGetGroundHeight = Spring.GetGroundHeight
local spGetBuildFacing = Spring.GetBuildFacing
local spGetGameFrame = Spring.GetGameFrame
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers

local mathAbs = math.abs
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathSin = math.sin
local mathCos = math.cos
local mathSqrt = math.sqrt
local HALF_PI = math.pi / 2

-- same look as the other placement previews: blueprint ghost alpha, the unload command's colour
local GHOST_ALPHA = 0.6
local UNLOAD_R, UNLOAD_G, UNLOAD_B = 1.0, 0.8, 0.0
local DASH, DASH_PERIOD = 14, 24

local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ

local TransportAPI ---@type table

local isFactory = {} ---@type table<integer, true>
local isImmobile = {} ---@type table<integer, boolean> these land on the build grid, facing a cardinal direction
local defHalfX, defHalfZ = {}, {} ---@type table<integer, number>, table<integer, number>
local maxFactoryHalf = 0 ---@type number
for unitDefID, ud in pairs(UnitDefs) do
	isImmobile[unitDefID] = ud.speed == 0
	defHalfX[unitDefID] = ud.xsize * Game.squareSize * 0.5
	defHalfZ[unitDefID] = ud.zsize * Game.squareSize * 0.5
	if ud.isFactory then
		isFactory[unitDefID] = true
		maxFactoryHalf = mathMax(maxFactoryHalf, defHalfX[unitDefID], defHalfZ[unitDefID])
	end
end

-- build squares around the target, nearest first
local searchOffsets = {} ---@type { dx: number, dz: number, dist2: number }[]
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

---@class UnloadRect
---@field x number
---@field z number
---@field hx number
---@field hz number

---@class UnloadSpot
---@field defID integer
---@field x number
---@field y number
---@field z number
---@field rot number

---@class QueuedPad
---@field padDefID integer the unload pad, or the building's own def when placed like a build order
---@field x number
---@field y number
---@field z number
---@field facing integer? build facing of a building

---@class UnloadPad : QueuedPad
---@field transportID integer
---@field passengerID integer? a single named drop
---@field spots UnloadSpot[] where each passenger lands
---@field fits boolean? a building's spot is free

---@class UnloadEntry
---@field unitID integer
---@field padDefID integer
---@field passengerID integer?
---@field hasCargo boolean?
---@field dist number?

---@class UnloadPlan
---@field cx number
---@field cz number
---@field squareX integer?
---@field squareZ integer?
---@field shift boolean
---@field frame integer
---@field facing integer? build facing, buildings only
---@field place boolean? nil for cargo on pads; for buildings placed like a build order, whether they all fit
---@field pads UnloadPad[]
---@field failed UnloadEntry[] transports that found no spot

---@class CargoOffset
---@field id integer
---@field defID integer
---@field fwd number
---@field side number
---@field heading number
---@field ox number
---@field oz number

local plan ---@type UnloadPlan?
local ghosts = {} ---@type { id: any, defID: integer, x: number, z: number, rot: number }[]
local queuedPads = {} ---@type QueuedPad[] unloads the selection already has queued
local recentPads = {} ---@type { pad: QueuedPad, timer: any }[] pads just ordered, until the queue shows them
local press ---@type { notified: boolean?, formation: boolean?, otherOwner: boolean? }? a right press custom formations may swallow
local drop ---@type { [1]: integer, [2]: integer }? transportID, passengerID picked in the info panel
local dropPlaced = false -- disarm after a single drop
local rearmDrop = false -- re-arm after a click on a blocked building spot
local lineReserve ---@type UnloadRect[]? pads already handed out along the line custom formations is giving
local testCache, testCacheFrame = {}, -math.huge ---@type table<number, boolean>, number
local lastQueueScan = -math.huge

local function selectedTransports()
	return TransportUI.tractorTransports(TransportAPI, spGetSelectedUnits())
end

local function unloadMode()
	return TransportUI.commandMode(UNLOAD_COMMANDS)
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
	return queue ~= nil and #queue == 1 and LOAD_COMMANDS[queue[1].id] == true
end

local function isCarrying(transportID, passengerID)
	local carried = spGetUnitIsTransporting(transportID) or {}
	for i = 1, #carried do
		if carried[i] == passengerID then
			return true
		end
	end
	return false
end

-- footprint half sizes turned to a build facing (1 and 3 swap x and z)
local function footprintHalf(defID, facing)
	if facing and facing % 2 == 1 then
		return defHalfZ[defID], defHalfX[defID]
	end
	return defHalfX[defID], defHalfZ[defID]
end

---@param pad QueuedPad
---@return UnloadRect
local function padRect(pad)
	local hx, hz = footprintHalf(pad.padDefID, pad.facing)
	return { x = pad.x, z = pad.z, hx = hx, hz = hz }
end

---@param rects UnloadRect[]
local function overlaps(x, z, hx, hz, rects)
	for i = 1, #rects do
		local rect = rects[i]
		if mathAbs(x - rect.x) < hx + rect.hx and mathAbs(z - rect.z) < hz + rect.hz then
			return true
		end
	end
	return false
end

---@return UnloadRect[]
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
			local yardX, yardZ = defHalfX[defID] + FACTORY_YARD_MARGIN, defHalfZ[defID] + FACTORY_YARD_MARGIN
			if ux and mathAbs(x - ux) < hx + yardX and mathAbs(z - uz) < hz + yardZ then
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

---@param reserved UnloadRect[]
---@return number? x, number? y, number? z, number budget
local function findPadSpot(padDefID, cx, cz, reserved, budget)
	local hx, hz = defHalfX[padDefID], defHalfZ[padDefID]
	for i = 1, #searchOffsets do
		if budget <= 0 then
			break
		end
		local wx, wz = cx + searchOffsets[i].dx, cz + searchOffsets[i].dz
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

---@param pad QueuedPad
local function rememberIssued(pad)
	local queued = { padDefID = pad.padDefID, x = pad.x, y = pad.y, z = pad.z, facing = pad.facing }
	recentPads[#recentPads + 1] = { pad = queued, timer = spGetTimer() }
	queuedPads[#queuedPads + 1] = queued
end

---@return QueuedPad[]
local function collectQueuedPads(transports)
	local pads = {}
	for i = 1, #transports do
		local unitID = transports[i]
		local queue = spGetUnitCommands(unitID, -1) or {}
		for j = 1, #queue do
			local params = queue[j].params
			if queue[j].id == CMD_UNLOAD_UNIT and params then
				-- a queued building takes its own footprint, everything else the unload pad
				local passengerID = params[4] --[[@as integer?]]
				local buildingDefID = passengerID and spGetUnitDefID(passengerID)
				local isBuilding = buildingDefID and isImmobile[buildingDefID]
				local padDefID = isBuilding and buildingDefID
					or TransportAPI.GetUnloadPadType(unitID, passengerID, true)
				if padDefID then
					local facing = isBuilding and params[5] or nil
					pads[#pads + 1] =
						{ padDefID = padDefID, x = params[1], y = params[2], z = params[3], facing = facing }
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

---@return UnloadEntry[]?
local function chooseTransports(cx, cz, shift)
	if drop then
		local padDefID = TransportAPI.GetUnloadPadType(drop[1], drop[2])
		return padDefID and { { unitID = drop[1], padDefID = padDefID, passengerID = drop[2] } }
	end

	local transports = selectedTransports()
	if #transports == 0 then
		return nil
	end

	-- transports with something to drop (now or by the time they get there); empty ones only if all are empty
	local entries = {} ---@type UnloadEntry[]
	local anyCargo = false
	for i = 1, #transports do
		local unitID = transports[i]
		local queued = keepsQueuedLoads(unitID, shift)
		local cargo = queued and TransportAPI.GetExpectedCargo(unitID) or spGetUnitIsTransporting(unitID) or {}
		anyCargo = anyCargo or #cargo > 0
		local padDefID = TransportAPI.GetUnloadPadType(unitID, nil, queued)
		entries[#entries + 1] = { unitID = unitID, hasCargo = #cargo > 0, padDefID = padDefID }
	end
	local chosen = {} ---@type UnloadEntry[]
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

-- a forward and sideways offset turned to a heading
---@return number, number
local function turned(fwd, side, sinA, cosA)
	return fwd * sinA + side * cosA, fwd * cosA - side * sinA
end

-- each passenger's offset from the transport, forward and sideways of the transport's heading
---@return CargoOffset[]? layout, number heading, number tx, number tz
local function cargoLayout(transportID, passengers)
	local tx, _, tz = spGetUnitPosition(transportID)
	if not tx then
		return nil, 0, 0, 0
	end
	local heading = spGetUnitHeading(transportID, true) or 0
	local sinH, cosH = mathSin(heading), mathCos(heading)
	local layout = {} ---@type CargoOffset[]
	for i = 1, #passengers do
		local passengerID = passengers[i]
		local defID = spGetUnitDefID(passengerID)
		local px, _, pz = spGetUnitPosition(passengerID)
		if defID and px then
			local ox, oz = px - tx, pz - tz
			layout[#layout + 1] = {
				id = passengerID,
				defID = defID,
				fwd = ox * sinH + oz * cosH,
				side = ox * cosH - oz * sinH,
				heading = spGetUnitHeading(passengerID, true) or 0,
				ox = 0,
				oz = 0,
			}
		end
	end
	return layout, heading, tx, tz
end

-- where each passenger touches down: the animator keeps its offset from the transport, turned to the heading
-- the transport arrives with (facing the pad from where it is now)
---@return UnloadSpot[]
local function landingSpots(transportID, passengers, padX, padZ)
	local layout, heading, tx, tz = cargoLayout(transportID, passengers)
	local spots = {}
	if not layout then
		return spots
	end
	local dx, dz = padX - tx, padZ - tz
	local arrive = dx * dx + dz * dz > ARRIVE_TURN_DIST * ARRIVE_TURN_DIST and math.atan2(dx, dz) or heading
	local sinA, cosA = mathSin(arrive), mathCos(arrive)
	for i = 1, #layout do
		local passenger = layout[i]
		local ox, oz = turned(passenger.fwd, passenger.side, sinA, cosA)
		local x, z = padX + ox, padZ + oz
		local y = mathMax(spGetGroundHeight(x, z), 0)
		local rot = passenger.heading - heading + arrive
		if isImmobile[passenger.defID] then
			x, y, z = spPos2BuildPos(passenger.defID, x, y, z)
			rot = mathFloor(rot / HALF_PI + 0.5) * HALF_PI
		end
		spots[#spots + 1] = { defID = passenger.defID, x = x, y = y, z = z, rot = rot }
	end
	return spots
end

-- buildings to set down: one picked in the info panel, or the whole cargo of the only selected transport
-- when all of it is buildings
---@return integer? transportID, integer[]? passengers
local function buildingsToPlace(shift)
	if drop then
		local defID = spGetUnitDefID(drop[2])
		if defID and isImmobile[defID] then
			return drop[1], { drop[2] }
		end
		return nil
	end
	local transports = selectedTransports()
	if #transports ~= 1 then
		return nil
	end
	local transportID = transports[1]
	local carried = spGetUnitIsTransporting(transportID) or {} ---@type integer[]
	local moreComing = keepsQueuedLoads(transportID, shift) and #TransportAPI.GetExpectedCargo(transportID) > #carried
	if #carried == 0 or moreComing then
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

-- buildings go down like a build order: laid out as they sit in the transport, turned by the build facing
-- (the build rotate keys), spread so footprints don't overlap, each on the grid with its own footprint tested
---@return UnloadPlan?
local function placementPlan(transportID, passengers, cx, cz, shift)
	local layout = cargoLayout(transportID, passengers)
	if not layout or #layout == 0 then
		return nil
	end
	local facing = spGetBuildFacing() or 0
	local facingAngle = facing * HALF_PI
	local sinF, cosF = mathSin(facingAngle), mathCos(facingAngle)

	local minGap, widest = math.huge, 0 ---@type number, number
	for i = 1, #layout do
		local entry = layout[i]
		if #layout > 1 then
			entry.ox, entry.oz = turned(entry.fwd, entry.side, sinF, cosF)
		end
		widest = mathMax(widest, 2 * defHalfX[entry.defID], 2 * defHalfZ[entry.defID])
		for j = 1, i - 1 do
			local other = layout[j] --[[@as CargoOffset]]
			minGap = mathMin(minGap, mathSqrt((entry.ox - other.ox) ^ 2 + (entry.oz - other.oz) ^ 2))
		end
	end
	local spread = (#layout > 1 and minGap > 0 and minGap < widest) and widest / minGap or 1

	local reserved = shift and queuedRects() or {}
	local placed = {} ---@type UnloadRect[]
	---@type UnloadPlan
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
	for i = 1, #layout do
		local entry = layout[i]
		local hx, hz = footprintHalf(entry.defID, facing)
		local wx, wz = cx + entry.ox * spread, cz + entry.oz * spread
		local bx, by, bz = spPos2BuildPos(entry.defID, wx, spGetGroundHeight(wx, wz), wz, facing)
		-- grid snapping can still bring two together: step this one outward until it is clear
		local stepX, stepZ = entry.ox >= 0 and BUILD_SQUARE or -BUILD_SQUARE, 0
		if mathAbs(entry.oz) > mathAbs(entry.ox) then
			stepX, stepZ = 0, entry.oz >= 0 and BUILD_SQUARE or -BUILD_SQUARE
		end
		for _ = 1, 8 do
			if not overlaps(bx, bz, hx, hz, placed) then
				break
			end
			local nx, nz = bx + stepX, bz + stepZ
			bx, by, bz = spPos2BuildPos(entry.defID, nx, spGetGroundHeight(nx, nz), nz, facing)
		end
		placed[#placed + 1] = { x = bx, z = bz, hx = hx, hz = hz }
		-- units in the way get pushed aside
		local fits = spotFree(entry.defID, bx, by, bz, facing) and not overlaps(bx, bz, hx, hz, reserved)
		newPlan.place = newPlan.place and fits
		newPlan.pads[i] = {
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

---@return UnloadPlan?
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
	---@type UnloadPlan
	local newPlan = { cx = cx, cz = cz, shift = shift, frame = spGetGameFrame(), pads = {}, failed = {} }
	local budget = SEARCH_BUDGET ---@type number
	for i = 1, #chosen do
		local entry = chosen[i]
		local x, y, z
		x, y, z, budget = findPadSpot(entry.padDefID, cx, cz, reserved, budget)
		if x and y and z then
			local cargo = entry.passengerID and { entry.passengerID } or spGetUnitIsTransporting(entry.unitID) or {}
			---@type UnloadPad
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

-- stops drawing the ghosts past the first keep
local function trimGhosts(keep)
	local stopDraw = WG.StopDrawUnitShapeGL4 -- gone when DrawUnitShape GL4 shuts down first
	for i = #ghosts, keep + 1, -1 do
		if stopDraw and ghosts[i].id then
			stopDraw(ghosts[i].id)
		end
		ghosts[i] = nil
	end
end

-- the cargo as ghosts where it lands; the brackets in DrawWorld carry the preview when DrawUnitShape GL4 is off
local function syncGhosts()
	if not WG.DrawUnitShapeGL4 then
		return
	end
	if not TransportUI.settingOn("ghosts") then
		trimGhosts(0)
		return
	end
	local pads = plan and plan.pads or {} ---@type UnloadPad[]
	local myTeam = Spring.GetMyTeamID()
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
				local updateID = ghost and ghost.id
				local id = WG.DrawUnitShapeGL4(
					spot.defID,
					spot.x,
					spot.y,
					spot.z,
					spot.rot,
					GHOST_ALPHA,
					myTeam,
					0,
					0,
					updateID
				)
				ghosts[count] = { id = id, defID = spot.defID, x = spot.x, z = spot.z, rot = spot.rot }
			end
		end
	end
	trimGhosts(count)
end

-- transports only have the area unload button; CommandNotify gets its click as a point
local function armUnload()
	local index = Spring.GetCmdDescIndex(CMD.UNLOAD_UNITS)
	return index ~= nil and spSetActiveCommand(index)
end

local function finishDrop()
	if drop then
		drop = nil
		dropPlaced = true
	end
end

---@param p UnloadPlan
local function issuePlan(p, options)
	if p.place == false then
		return
	end
	for i = 1, #p.pads do
		local pad = p.pads[i]
		if p.place then
			-- buildings: one exact drop each, queued one after another
			local params = { pad.x, pad.y, pad.z, pad.passengerID, p.facing }
			spGiveOrderToUnit(pad.transportID, CMD_UNLOAD_UNIT, params, i == 1 and options or CMD.OPT_SHIFT)
		else
			spGiveOrderToUnit(pad.transportID, CMD_UNLOAD_UNIT, { pad.x, pad.y, pad.z, pad.passengerID }, options)
		end
		rememberIssued(pad)
	end
	-- no free spot found here: hand the raw point to the gadget, which searches with everything it knows
	for i = 1, #p.failed do
		local entry = p.failed[i]
		local params = { p.cx, spGetGroundHeight(p.cx, p.cz), p.cz, entry.passengerID }
		spGiveOrderToUnit(entry.unitID, CMD_UNLOAD_UNIT, params, options)
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
	local arg = args and args[1]
	local facing = spGetBuildFacing() or 0
	local newFacing = FACING_NAMES[arg] ---@type number?
	if arg == "inc" then
		newFacing = (facing + 1) % 4
	elseif arg == "dec" then
		newFacing = (facing - 1) % 4
	end
	if newFacing then
		Spring.SetBuildFacing(newFacing --[[@as FacingInteger]])
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
	trimGhosts(0)
	WG.UnloadSnap = nil
	widgetHandler.actionHandler:RemoveAction(self, "buildfacing", "p")
end

function widget:SelectionChanged()
	plan = nil
	drop = nil
end

-- custom formations swallows a short unload click when several transports are selected: give it here
local function releaseSwallowedClick(rmb)
	if not press then
		return
	end
	local owner = widgetHandler.mouseOwner
	if owner and not (owner.whInfo and owner.whInfo.name == "CustomFormations2") then
		press.otherOwner = true
	end
	if not rmb then
		if plan and not (press.notified or press.formation or press.otherOwner) then
			issuePlan(plan, plan.shift and { "shift" } or {})
		end
		press = nil
	end
end

local function clearPreview()
	plan = nil
	trimGhosts(0)
end

function widget:Update()
	local mx, my, _, _, rmb = Spring.GetMouseState()
	lineReserve = nil -- custom formations gives a whole line inside one mouse release
	releaseSwallowedClick(rmb)

	local mode = not Spring.GetSpectatingState() and unloadMode() or nil
	-- a single drop is one click; a shift click would leave the unload armed for the whole cargo
	if dropPlaced then
		dropPlaced = false
		if mode == "active" then
			spSetActiveCommand(0)
			mode = nil
		end
	end
	-- a click on a blocked spot gives no order and leaves the single drop armed, like a build order would
	if rearmDrop then
		rearmDrop = false
		if drop and mode ~= "active" and armUnload() then
			mode = "active"
		end
	end
	if drop and (mode ~= "active" or not isCarrying(drop[1], drop[2])) then
		drop = nil
		plan = nil
	end
	if not mode then
		if #queuedPads > 0 then
			queuedPads = {}
		end
		clearPreview()
		return
	end

	-- by draw frame: the preview keeps up while paused
	local drawFrame = Spring.GetDrawFrame()
	if drawFrame - lastQueueScan >= REPLAN_FRAMES then
		lastQueueScan = drawFrame
		queuedPads = collectQueuedPads(selectedTransports())
	end

	local cx, _, cz = TransportUI.cursorGround(mx, my)
	if not cx or not cz or (press and press.formation) then
		clearPreview()
		return
	end
	local shift = TransportUI.shiftHeld()
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

---@param mx integer
---@param my integer
function widget:MousePress(mx, my, button)
	if
		button == 3
		and unloadMode() == "default"
		and not widgetHandler:IsAbove(mx, my)
		and not Spring.IsAboveMiniMap(mx, my)
	then
		press = {}
	end
	return false -- custom formations still gets the drag for line unloads
end

-- a drawn line: custom formations hands out one unload per transport; each gets the free pad nearest its point,
-- clear of the pads given to the others on the same line
function widget:UnitCommandNotify(unitID, cmdID, params, options)
	if not UNLOAD_COMMANDS[cmdID] or not params or not params[3] or (cmdID == CMD_UNLOAD_UNIT and params[4]) then
		return false
	end
	if press then
		press.formation = true
	end
	if not TransportAPI.IsTractorTransport(unitID) then
		return false
	end
	local shift = options.shift
	lineReserve = lineReserve or (shift and queuedRects() or {})
	local padDefID = TransportAPI.GetUnloadPadType(unitID, nil, keepsQueuedLoads(unitID, shift))
	if not padDefID then
		return false
	end
	local x, y, z = findPadSpot(padDefID, params[1], params[3], lineReserve, LINE_BUDGET)
	if not (x and y and z) then
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
	if not UNLOAD_COMMANDS[cmdID] or (cmdID == CMD_UNLOAD_UNIT and params[4]) or not params[3] then
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

-- a line along the ground in short steps
local function groundLineVertices(ax, az, bx, bz)
	local steps = mathMax(1, mathFloor(mathMax(mathAbs(bx - ax), mathAbs(bz - az)) / 8))
	for step = 0, steps - 1 do
		local t1, t2 = step / steps, (step + 1) / steps
		local x1, z1 = ax + (bx - ax) * t1, az + (bz - az) * t1
		local x2, z2 = ax + (bx - ax) * t2, az + (bz - az) * t2
		gl.Vertex(x1, groundY(x1, z1), z1)
		gl.Vertex(x2, groundY(x2, z2), z2)
	end
end

-- a building's footprint edge, following the ground
local function footprintVertices(x, z, hx, hz)
	groundLineVertices(x - hx, z - hz, x + hx, z - hz)
	groundLineVertices(x + hx, z - hz, x + hx, z + hz)
	groundLineVertices(x + hx, z + hz, x - hx, z + hz)
	groundLineVertices(x - hx, z + hz, x - hx, z - hz)
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

---@param pad QueuedPad
local function drawBrackets(pad, width, alpha)
	local hx, hz = footprintHalf(pad.padDefID, pad.facing)
	drawLines(bracketVertices, width, alpha, pad.x, pad.z, hx, hz)
end

-- a building placed like a build order: green where it can go, red where it cannot (blueprint colours)
local function drawFootprint(defID, x, z, placeable, facing)
	local hx, hz = footprintHalf(defID, facing)
	local r, g = placeable and 0 or 1, placeable and 1 or 0
	gl.Color(r, g, 0, 0.12)
	gl.BeginEnd(GL.QUADS, function()
		gl.Vertex(x - hx, groundY(x - hx, z - hz), z - hz)
		gl.Vertex(x + hx, groundY(x + hx, z - hz), z - hz)
		gl.Vertex(x + hx, groundY(x + hx, z + hz), z + hz)
		gl.Vertex(x - hx, groundY(x - hx, z + hz), z + hz)
	end)
	drawLinesColored(footprintVertices, 2, r, g, 0, 0.9, x, z, hx, hz)
end

---@param p UnloadPlan
local function drawPlan(p)
	local cursorY = groundY(p.cx, p.cz)
	for i = 1, #p.pads do
		local pad = p.pads[i]
		local tx, ty, tz = spGetUnitPosition(pad.transportID)
		if p.place ~= nil then
			drawFootprint(pad.padDefID, pad.x, pad.z, pad.fits, p.facing)
			-- buildings: one line from the transport to the cursor
			if tx and i == 1 then
				drawLines(dashVertices, 1.5, 0.4, tx, ty, tz, p.cx, cursorY, p.cz)
			end
		else
			drawBrackets(pad, 2, 0.85)
			if tx then
				drawLines(dashVertices, 1.5, 0.4, tx, ty, tz, pad.x, groundY(pad.x, pad.z), pad.z)
			end
		end
	end

	-- the nearest drop had to move off the cursor: show where to
	local first = p.pads[1]
	if first and p.place == nil then
		local moved = mathAbs(first.x - p.cx) > defHalfX[first.padDefID]
			or mathAbs(first.z - p.cz) > defHalfZ[first.padDefID]
		if moved then
			drawLines(dashVertices, 1.5, 0.6, p.cx, cursorY, p.cz, first.x, groundY(first.x, first.z), first.z)
		end
	end

	-- some transports found no spot within reach
	if #p.failed > 0 then
		drawLinesColored(TransportUI.crossVertices, 2.5, 1, 0.25, 0.2, 0.9, p.cx, cursorY, p.cz, CROSS_SIZE)
	end
end

function widget:DrawWorld()
	if (not plan and #queuedPads == 0) or Spring.IsGUIHidden() then
		return
	end
	gl.DepthTest(false)
	-- faint, so the new drop reads apart from them
	for i = 1, #queuedPads do
		drawBrackets(queuedPads[i], 1.5, 0.3)
	end
	if plan then
		drawPlan(plan)
	end
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
	gl.DepthTest(true)
end
