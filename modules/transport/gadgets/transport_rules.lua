local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Transport Rules",
		desc = "One owner for what a carrier may load, where it may set down, how fast it flies loaded, and what becomes of cargo",
		author = "Doo, Bluestone, raaar, Hornet, knorke, icexuick, beherith, Niobium, Chronographer, Beyond All Reason",
		date = "August 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local Rules = VFS.Include("modules/transport/lib/rules.lua") ---@type TransportRules
local TransportEnums = VFS.Include("modules/transport/enums.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")

local pipelines = ModuleHandler.LoadPolicies("transport") ---@type TransportPipelines

---@param ctx TransportLoadContext
---@return boolean
local function decideLoad(ctx)
	return ModuleHandler.Evaluate(pipelines.load, ctx)
end

---@param ctx TransportUnloadContext
---@return boolean
local function decideUnload(ctx)
	return ModuleHandler.Evaluate(pipelines.unload, ctx)
end

---@param ctx TransportLoadedSpeedContext
---@return number
local function decideLoadedSpeed(ctx)
	return ModuleHandler.Evaluate(pipelines.loaded_speed, ctx)
end

local modOptions = Spring.GetModOptions()
local commanderDrag = modOptions[TransportEnums.ModOptions.CommanderTransportSlow] == true
local FRAMES_PER_SECOND = Game.gameSpeed

local reach = {} ---@type table<integer, number> air transport def -> elmos
local canFly = {} ---@type table<integer, boolean>
local speed = {} ---@type table<integer, number>
local isCommander = {} ---@type table<integer, boolean>
local isParatrooper = {} ---@type table<integer, boolean>
local isStealthy = {} ---@type table<integer, boolean>
local stealthyTransport = {} ---@type table<integer, boolean>
local isNano = {} ---@type table<integer, boolean>
local leavesGhost = {} ---@type table<integer, boolean>

for unitDefID, unitDef in pairs(UnitDefs) do
	reach[unitDefID] = Rules.Reach(unitDef)
	canFly[unitDefID] = unitDef.canFly or nil
	speed[unitDefID] = unitDef.speed
	isCommander[unitDefID] = unitDef.customParams.iscommander == "1" or nil
	isParatrooper[unitDefID] = (unitDef.customParams.paratrooper or unitDef.customParams.subfolder == "other/hats")
			and true
		or nil
	isStealthy[unitDefID] = unitDef.stealth or nil
	stealthyTransport[unitDefID] = unitDef.customParams.stealths_passengers ~= nil or nil
	isNano[unitDefID] = unitDef.customParams.isnanoturret ~= nil or nil
	leavesGhost[unitDefID] = unitDef.leavesGhost == true or nil
end

local loadedSpeed = {} ---@type table<integer, number> air transport -> allowed elmos per frame
local settling = {} ---@type table<integer, table> unloaded unit -> where it landed, and when to pin it
local maybeDead = {} ---@type table<integer, integer> cargo -> the carrier that just let go

---@param transportID integer
---@param goalX number
---@param goalY number
---@param goalZ number
---@return number
local function distanceToGoal(transportID, goalX, goalY, goalZ)
	local x, y, z = Spring.GetUnitPosition(transportID)
	local dx, dy, dz = x - goalX, y - goalY, z - goalZ
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

---@param transportID integer
local function updateLoadedSpeed(transportID)
	local cargo = Spring.GetUnitIsTransporting(transportID)
	if cargo == nil then
		return
	end
	local carriesCommander = false
	for _, unitID in ipairs(cargo) do
		if isCommander[Spring.GetUnitDefID(unitID)] then
			carriesCommander = true
		end
	end
	loadedSpeed[transportID] = decideLoadedSpeed({
		carriesCommander = carriesCommander,
		transportSpeed = speed[Spring.GetUnitDefID(transportID)] or 0,
		dragEnabled = commanderDrag,
		framesPerSecond = FRAMES_PER_SECOND,
	})
end

---@param unitID integer
---@return boolean
local function deadOrCrashing(unitID)
	return Spring.GetUnitIsDead(unitID) ~= false or Spring.GetUnitMoveTypeData(unitID).aircraftState == "crashing"
end

function gadget:AllowUnitTransport(_, transporterDefID, _, transporteeID, transporteeDefID)
	local _, y = Spring.GetUnitPosition(transporteeID)
	return decideLoad({
		goalY = y,
		height = Spring.GetUnitHeight(transporteeID),
		carrierDef = UnitDefs[transporterDefID],
		passengerDef = UnitDefs[transporteeDefID],
	})
end

function gadget:AllowUnitTransportLoad(
	transporterID,
	transporterDefID,
	_,
	transporteeID,
	transporteeDefID,
	_,
	goalX,
	goalY,
	goalZ
)
	local airReach = reach[transporterDefID]
	local allowed = decideLoad({
		carrierDef = UnitDefs[transporterDefID],
		passengerDef = UnitDefs[transporteeDefID],
		goalY = goalY,
		height = Spring.GetUnitHeight(transporteeID),
		reach = airReach,
		distance = airReach and distanceToGoal(transporterID, goalX, goalY, goalZ) or 0,
		allied = Spring.AreTeamsAllied(Spring.GetUnitTeam(transporterID), Spring.GetUnitTeam(transporteeID)),
		passengerSpeed = select(4, Spring.GetUnitVelocity(transporteeID)),
	})
	if allowed and airReach then
		-- An air transport stops dead to load.
		Spring.SetUnitVelocity(transporterID, 0, 0, 0)
	end
	return allowed
end

function gadget:AllowUnitTransportUnload(transporterID, transporterDefID, _, transporteeID, _, _, goalX, goalY, goalZ)
	local airReach = reach[transporterDefID]
	local allowed = decideUnload({
		goalY = goalY,
		height = Spring.GetUnitHeight(transporteeID),
		reach = airReach,
		distance = airReach and distanceToGoal(transporterID, goalX, goalY, goalZ) or 0,
	})
	if allowed and airReach then
		Spring.SetUnitVelocity(transporterID, 0, 0, 0)
	end
	return allowed
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams)
	if not UnitDefs[unitDefID].isTransport then
		return false
	end
	if cmdID == CMD.LOAD_UNITS then
		if #cmdParams == 1 then
			local targetID = cmdParams[1]
			if Spring.ValidUnitID(targetID) and isNano[Spring.GetUnitDefID(targetID)] then
				local ownTeam = Spring.GetUnitTeam(targetID) == teamID
				local enemy = Spring.GetUnitAllyTeam(targetID) ~= Spring.GetUnitAllyTeam(unitID)
				if not ownTeam and not enemy then
					return false
				end
			end
		end
	elseif cmdParams[1] and cmdParams[3] then
		local cargo = Spring.GetUnitIsTransporting(unitID)
		if cargo and cargo[1] and isNano[Spring.GetUnitDefID(cargo[1])] then
			local _, normalY = Spring.GetGroundNormal(cmdParams[1], cmdParams[3])
			return decideUnload({ goalY = cmdParams[2], height = 0, nano = true, groundNormalY = normalY })
		end
	end
	return true
end

function gadget:UnitLoaded(unitID, unitDefID, _, transportID)
	local transportDefID = Spring.GetUnitDefID(transportID)
	if canFly[transportDefID] then
		updateLoadedSpeed(transportID)
	end
	if stealthyTransport[transportDefID] and not isStealthy[unitDefID] then
		Spring.SetUnitStealth(unitID, true)
	end
	if leavesGhost[unitDefID] then
		-- The old ghost persists until the position re-enters LOS.
		Spring.SetUnitLeavesGhost(unitID, false, true)
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, _, transportID)
	if unitID == nil or unitDefID == nil or transportID == nil then
		return
	end
	local transportDefID = Spring.GetUnitDefID(transportID)
	if canFly[transportDefID] then
		local cargo = Spring.GetUnitIsTransporting(transportID)
		if cargo == nil or cargo[1] == nil then
			loadedSpeed[transportID] = nil
		else
			updateLoadedSpeed(transportID)
		end
	end
	if stealthyTransport[transportDefID] and not isStealthy[unitDefID] then
		Spring.SetUnitStealth(unitID, false)
	end
	if leavesGhost[unitDefID] then
		Spring.SetUnitLeavesGhost(unitID, true)
	end

	if isParatrooper[unitDefID] then
		local vx, vy, vz = Spring.GetUnitVelocity(transportID)
		vx, vz = Rules.ClampParatrooperVelocity(vx), Rules.ClampParatrooperVelocity(vz)
		local x, y, z = Spring.GetUnitPosition(unitID)
		if y - Spring.GetGroundHeight(x, z) < Rules.PARATROOPER_GROUND_MARGIN then
			vx, vy, vz = 0, 0, 0
		end
		Spring.SetUnitVelocity(unitID, vx, vy, vz)
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
		return
	end

	-- Anything else is pinned back where it landed a few frames later, so
	-- stored impulse cannot fire it across the map.
	local px, py, pz = Spring.GetUnitPosition(unitID)
	local dx, dy, dz, rx, ry, rz = Spring.GetUnitDirection(unitID)
	settling[unitID] = {
		px = px,
		py = py,
		pz = pz,
		dx = dx,
		dy = dy,
		dz = dz,
		rx = rx,
		ry = ry,
		rz = rz,
		frame = Spring.GetGameFrame() + Rules.UNLOAD_SETTLE_FRAMES,
	}
	Spring.SetUnitVelocity(unitID, 0, 0, 0)

	-- A carrier unloads as it dies; whether it did is only knowable after the
	-- frame's cleanup, so the cargo is marked and judged in GameFramePost.
	if not Spring.GetUnitRulesParam(unitID, "unit_effigy") then
		maybeDead[unitID] = transportID
	end
end

function gadget:GameFrame(frame)
	for transportID, allowed in pairs(loadedSpeed) do
		local vx, vy, vz, vw = Spring.GetUnitVelocity(transportID)
		if vw and vw > allowed then
			local factor = allowed / vw
			Spring.SetUnitVelocity(transportID, vx * factor, vy * factor, vz * factor)
		end
	end
	for unitID, landing in pairs(settling) do
		if landing.frame <= frame then
			settling[unitID] = nil
			if Spring.ValidUnitID(unitID) then
				Spring.SetUnitPhysics(unitID, landing.px, landing.py, landing.pz, 0, 0, 0, 0, 0, 0, 0, 0, 0)
				Spring.SetUnitDirection(unitID, landing.dx, landing.dy, landing.dz, landing.rx, landing.ry, landing.rz)
			end
		end
	end
end

function gadget:GameFramePost()
	if next(maybeDead) == nil then
		return
	end
	for unitID, transportID in pairs(maybeDead) do
		if deadOrCrashing(transportID) and not deadOrCrashing(unitID) then
			Spring.UnitDetach(unitID)
			Spring.AddUnitDamage(unitID, 1e6, nil, nil, Game.envDamageTypes.TransportKilled)
		end
	end
	maybeDead = {}
end

function gadget:UnitDestroyed(unitID)
	loadedSpeed[unitID] = nil
	settling[unitID] = nil
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.LOAD_UNITS)
	gadgetHandler:RegisterAllowCommand(CMD.UNLOAD_UNITS)
	GG.Transport = {
		---@param unitID integer
		---@return boolean
		IsCarried = function(unitID)
			return Spring.GetUnitTransporter(unitID) ~= nil
		end,
		---@param unitID integer
		---@return integer|nil
		CarrierOf = function(unitID)
			return Spring.GetUnitTransporter(unitID)
		end,
		---@param transportID integer
		---@return integer[]
		Cargo = function(transportID)
			return Spring.GetUnitIsTransporting(transportID) or {}
		end,
		---@param transportDefID integer
		---@param unitDefID integer
		---@param carriedMass number|nil
		---@param carriedCount integer|nil
		---@return boolean
		CanCarry = function(transportDefID, unitDefID, carriedMass, carriedCount)
			local transportDef, unitDef = UnitDefs[transportDefID], UnitDefs[unitDefID]
			return transportDef ~= nil
				and unitDef ~= nil
				and Rules.CanCarry(transportDef, unitDef, carriedMass, carriedCount)
		end,
	}
end

function gadget:Shutdown()
	GG.Transport = nil
end
