local gadget = gadget

function gadget:GetInfo()
	return {
		name = "Pregame command queues",
		desc = "Engine command queues for each player's starting builder",
		author = "BAR contributors",
		layer = -100000,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local substitution = VFS.Include("luaui/Include/blueprint_substitution/logic.lua")
local missionOptions = VFS.Include("luaui/Include/mission_options.lua")
local proxies, owners, builders = {}, {}, {}
local positions, published = {}, {}
local generation = 0

local function queueKey(playerID, teamID)
	return GG.coopMode and playerID or "team" .. teamID
end

local function members(key)
	local result = {}
	for _, playerID in ipairs(Spring.GetPlayerList()) do
		local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID, false)
		if active and not spectator and queueKey(playerID, teamID) == key then
			result[#result + 1] = playerID
		end
	end
	return result
end
local started = false

local function publish(playerID, teamID, unitID)
	Spring.SetTeamRulesParam(teamID, "pregameQueue_" .. playerID, unitID or -1, { allied = true })
end

local function trackBuilder(unitID, key)
	generation = generation + 1
	local pending = {}
	for _, playerID in ipairs(members(key)) do
		pending[playerID] = true
	end
	builders[unitID] = { generation = generation, pending = pending }
	Spring.SetUnitRulesParam(unitID, "pregame_generation", generation, { allied = true })
end

local function giveCommand(target, id, params, options, generated)
	local side = substitution.getSideFromUnitName(UnitDefs[Spring.GetUnitDefID(target)].name)
	if id < 0 then
		id = -substitution.getEquivalentUnitDefID(-id, side)
		local supported = false
		for _, buildDefID in ipairs(UnitDefs[Spring.GetUnitDefID(target)].buildOptions or {}) do
			supported = supported or buildDefID == -id
		end
		if not supported then
			return
		end
	end
	local previousCount = generated and #(Spring.GetUnitCommands(target, -1) or {})
	Spring.GiveOrderToUnit(target, id, params, options)
	if generated then
		local queue = Spring.GetUnitCommands(target, -1)
		local command = queue and queue[#queue]
		if command and #queue == previousCount + 1 then
			Spring.SetUnitRulesParam(target, "pregame_generated_" .. command.tag, 1, { allied = true })
		end
	end
end

local function snapshotQueue(unitID)
	local queue = Spring.GetUnitCommands(unitID, -1) or {}
	for _, command in ipairs(queue) do
		command.generated = Spring.GetUnitRulesParam(unitID, "pregame_generated_" .. command.tag) == 1
	end
	return queue
end

local function restoreQueue(queue, target)
	for _, command in ipairs(queue) do
		local options = command.options.coded + (command.options.shift and 0 or CMD.OPT_SHIFT)
		giveCommand(target, command.id, command.params, options, command.generated)
	end
end

local function removeProxy(key, reuseID)
	local unitID = proxies[key]
	if not unitID then
		return
	end
	for playerID, proxy in pairs(published) do
		if proxy == unitID then
			publish(playerID, Spring.GetUnitTeam(unitID), nil)
			published[playerID] = nil
		end
	end
	proxies[key], owners[unitID] = nil, nil
	Spring.DestroyUnit(unitID, false, true, nil, reuseID)
end

-- Called from the normal and coop spawners, outside the engine's unit update loop.
local function createStartUnit(playerID, defID, x, y, z, facing, teamID)
	local key = queueKey(playerID, teamID)
	local unitID = proxies[key]
	local queue = unitID and snapshotQueue(unitID)
	if unitID then
		removeProxy(key, true)
	end
	local target = Spring.CreateUnit(defID, x, y, z, facing, teamID, false, true, unitID)
	if target and queue then
		trackBuilder(target, key)
		restoreQueue(queue, target)
		for _, member in ipairs(members(key)) do
			Spring.SetTeamRulesParam(teamID, "pregameQueueTarget_" .. member, target, { allied = true })
		end
	end
	return target
end

local function refresh(playerID)
	local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID, false)
	local previous = published[playerID]
	if previous and (not active or spectator or Spring.GetUnitTeam(previous) ~= teamID) then
		publish(playerID, Spring.GetUnitTeam(previous), nil)
		published[playerID] = nil
	end
	for key in pairs(proxies) do
		if #members(key) == 0 then
			removeProxy(key)
		end
	end
	if not active or spectator or not teamID then
		return
	end
	local key = queueKey(playerID, teamID)
	local defID = GG.coopMode and GG.playerStartingUnits and GG.playerStartingUnits[playerID]
	defID = defID or Spring.GetTeamRulesParam(teamID, "startUnit")
	if not defID or defID == UnitDefNames.dummycom.id then
		defID = proxies[key] and Spring.GetUnitDefID(proxies[key]) or UnitDefNames.armcom.id
	end
	local x, y, z = Spring.GetTeamStartPosition(teamID)
	local coopPosition = GG.coopStartPoints and GG.coopStartPoints[playerID]
	if coopPosition and coopPosition[1] > 0 then
		x, y, z = unpack(coopPosition)
	end
	if not x or x <= 0 or z <= 0 then
		x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	end
	local position = positions[key]
	if position and position.team == teamID then
		x, z = position.x, position.z
	end
	y = Spring.GetGroundHeight(x, z)
	local unitID = proxies[key]
	if unitID and Spring.GetUnitDefID(unitID) == defID and Spring.GetUnitTeam(unitID) == teamID then
		Spring.SetUnitPosition(unitID, x, z)
		Spring.SetUnitRulesParam(unitID, "pregame_positioned", position and position.team == teamID and 1 or 0)
		for _, member in ipairs(members(key)) do
			publish(member, teamID, unitID)
			published[member] = unitID
		end
		return
	end
	local queue = unitID and snapshotQueue(unitID)
	if unitID then
		removeProxy(key, true)
	end
	-- Reuse the ID so commands already on the network still address this builder.
	-- The final argument excludes this temporary unit from engine unit statistics.
	local replacement = Spring.CreateUnit(defID, x, y, z, 0, teamID, false, false, unitID, nil, true)
	if not replacement then
		return
	end
	-- GameStart resets team storage; removing the proxy must not subtract it again.
	Spring.SetUnitStorage(replacement, { metal = 0, energy = 0 })
	Spring.SetUnitRulesParam(replacement, "pregame_proxy", 1, { public = true })
	Spring.SetUnitRulesParam(replacement, "pregame_positioned", position and position.team == teamID and 1 or 0)
	Spring.SetUnitRulesParam(replacement, "startingOwner", playerID, { allied = true })
	Spring.SetUnitRulesParam(replacement, "remove_decorations", 1)
	Spring.SetUnitBlocking(replacement, false, false, false, false, false, false, false)
	Spring.SetUnitNoDraw(replacement, true)
	Spring.SetUnitNoMinimap(replacement, true)
	trackBuilder(replacement, key)
	if queue then
		restoreQueue(queue, replacement)
	end
	proxies[key], owners[replacement] = replacement, key
	for _, member in ipairs(members(key)) do
		publish(member, teamID, replacement)
		published[member] = replacement
	end
end

function gadget:Initialize()
	if
		not Game.allowPreGameCommands
		or Spring.GetGameFrame() > 0
		or missionOptions.IsStartUnitSpawnDisabled()
		or Spring.GetModOptions().scenariooptions
		or Spring.GetModOptions().editor_sandbox == "1"
	then
		gadgetHandler:RemoveGadget(self)
		return
	end
	GG.CreatePregameStartUnit = createStartUnit
	GG.UpdatePregameQueuePosition = function(playerID, x, z)
		if started or x <= 0 or z <= 0 then
			return
		end
		local _, _, _, teamID = Spring.GetPlayerInfo(playerID, false)
		positions[queueKey(playerID, teamID)] = { team = teamID, x = x, z = z }
		refresh(playerID)
	end
	gadgetHandler:RegisterAllowCommand(CMD.ANY)
	for _, playerID in ipairs(Spring.GetPlayerList()) do
		refresh(playerID)
	end
end

function gadget:RecvLuaMsg(message, playerID)
	local unitID, seenGeneration = message:match("^pregameQueueAck:(%d+):(%d+)$")
	local builder = unitID and builders[tonumber(unitID)]
	if builder and builder.generation == tonumber(seenGeneration) then
		builder.pending[playerID] = nil
		return true
	end
	if not started and message:sub(1, 16) == "pregameQueueSet:" then
		local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID, false)
		local target = active and not spectator and proxies[queueKey(playerID, teamID)]
		if not target then
			return true
		end
		local ok, queue = pcall(Json.decode, message:sub(17))
		if not ok or type(queue) ~= "table" then
			return true
		end
		-- Validate the entire request before changing the engine queue.
		for _, item in ipairs(queue) do
			if type(item) ~= "table" or type(item[1]) ~= "number" or item[1] % 1 ~= 0 then
				return true
			end
			if item[1] < 0 and not UnitDefs[-item[1]] then
				return true
			end
			if
				type(item[2]) ~= "table"
				or type(item[3]) ~= "number"
				or item[3] % 1 ~= 0
				or item[3] < 0
				or item[3] > 255
			then
				return true
			end
			for _, value in ipairs(item[2]) do
				if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
					return true
				end
			end
		end
		Spring.GiveOrderToUnit(target, CMD.STOP, {}, 0)
		for _, item in ipairs(queue) do
			local options = item[3]
			if math.floor(options / CMD.OPT_SHIFT) % 2 == 0 then
				options = options + CMD.OPT_SHIFT
			end
			giveCommand(target, item[1], item[2], options, item[4] == true)
		end
		return true
	end
	if message == "pregameQueueRefresh" and not started then
		refresh(playerID)
		return true
	end
end

function gadget:AllowCommand(
	unitID,
	unitDefID,
	teamID,
	cmdID,
	params,
	options,
	tag,
	playerID,
	fromSynced,
	fromLua,
	fromInsert
)
	if fromSynced and fromLua then
		return true
	end
	local owner = owners[unitID]
	if owner ~= nil then
		local _, active, spectator, playerTeam = Spring.GetPlayerInfo(playerID, false)
		if not active or spectator or playerTeam ~= teamID or owner ~= queueKey(playerID, teamID) then
			return false
		end
	end
	local builder = builders[unitID]
	-- Restoring a queue assigns new command tags. Until this client has observed
	-- the replacement, discard old tag references rather than editing the wrong order.
	-- Its acknowledgement follows its earlier commands on the same ordered connection.
	if
		builder
		and builder.pending[playerID]
		and ((cmdID == CMD.REMOVE and not options.alt) or (fromInsert and not fromInsert.alt))
	then
		return false
	end
	if builder and cmdID < 0 then
		local def = UnitDefs[unitDefID]
		-- Only substitute foreign build options, never a valid command of this builder.
		for _, buildDefID in ipairs(def.buildOptions or {}) do
			if buildDefID == -cmdID then
				return true
			end
		end
		if not UnitDefs[-cmdID] then
			return false
		end
		local side = substitution.getSideFromUnitName(def.name)
		local equivalent = substitution.getEquivalentUnitDefID(-cmdID, side)
		for _, buildDefID in ipairs(def.buildOptions or {}) do
			if buildDefID == equivalent then
				Game.Commands.ReissueOrder(unitID, -equivalent, params, options, tag, fromInsert)
				return false
			end
		end
		return false
	end
	return true
end

function gadget:UnitDestroyed(unitID)
	builders[unitID] = nil
end

function gadget:GameStart()
	started = true
end

function gadget:GameFrame(frame)
	if frame == 1 then
		-- Remove previews whose normal spawner deliberately did not create a commander.
		for key in pairs(proxies) do
			removeProxy(key)
		end
	end
end

function gadget:Shutdown()
	GG.UpdatePregameQueuePosition = nil
	GG.CreatePregameStartUnit = nil
end
