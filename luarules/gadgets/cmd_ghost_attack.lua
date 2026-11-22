local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Ghost Attack",
		desc = "Resolve remembered buildings for the attacking allyteam",
		author = "BAR contributors",
		license = "GNU GPL, v2 or later",
		layer = -10, -- Terrain-only weapons resolve their targets first.
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() or not CMD.OPT_KEEP_HEIGHT then
	return false
end

local attack, insert, remove = CMD.ATTACK, CMD.INSERT, CMD.REMOVE
local height = CMD.OPT_KEEP_HEIGHT --[[@as integer]]
local clearHeight = (255 - height) --[[@as integer]]

-- GetUnitCommands always packs both fields, including for an empty parameter list.
---@alias GhostAttackQueueEntry { id: integer, tag: integer, params: number[], options: CommandOptions }
---@type fun(unitID: UnitID, count: integer): GhostAttackQueueEntry[]
local getQueue = Spring.GetUnitCommands
local giveOrder = Spring.GiveOrderToUnit
local getGhost = Spring.GetGhostPosition
local attackers = {} -- target unit -> units that have received an attack on it
local sightings = {} -- ghost ID -> observer and outstanding attack tags per unit
---@type number[]? Only this synchronous reissue may retain the height bit.
local issuing

local function issue(unitID, cmdID, params, bits, tag, outer)
	if outer then
		giveOrder(unitID, insert, { tag, cmdID, bits, unpack(params) }, outer.coded)
	else
		giveOrder(unitID, cmdID, params, bits)
	end
end

local function issueGhost(unitID, ghostID, x, y, z, bits, tag, outer)
	local previous = {}
	for _, command in ipairs(getQueue(unitID, -1)) do
		previous[command.tag] = true
	end
	local old = issuing
	issuing = { unitID, x, y, z }
	local ok, err = pcall(issue, unitID, attack, { x, y, z }, math.bit_or(bits, height), tag, outer)
	issuing = old
	if not ok then
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, err)
		return false
	end
	-- The engine assigns a tag on insertion, after UnitCommand. A shifted order
	-- can cancel an existing entry or be refused by a later gadget.
	for _, command in ipairs(getQueue(unitID, -1)) do
		if not previous[command.tag] and command.id == attack and command.options.keepheight then
			local sighting = sightings[ghostID]
			if not sighting then
				sighting = { allyTeam = Spring.GetUnitAllyTeam(unitID), orders = {} }
				sightings[ghostID] = sighting
			end
			local tags = sighting.orders[unitID] or {}
			sighting.orders[unitID] = tags
			tags[command.tag] = true
			return true
		end
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterCMDID(GameCMD.GHOST_ATTACK)
	gadgetHandler:RegisterAllowCommand(GameCMD.GHOST_ATTACK)
	gadgetHandler:RegisterAllowCommand(attack)
	gadgetHandler:RegisterAllowCommand(CMD.MANUALFIRE)
	gadgetHandler:RegisterUnitCommand(attack)
	gadgetHandler:RegisterUnitCommand(insert)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, params, opts, tag, playerID, fromSynced, fromLua, outer)
	if cmdID == GameCMD.GHOST_ATTACK then
		if getGhost and #params == 1 then
			local ghostID = params[1]
			local x, y, z, contact = getGhost(ghostID, Spring.GetUnitAllyTeam(unitID))
			if contact then
				issue(unitID, attack, { contact }, math.bit_and(opts.coded, clearHeight), tag, outer)
			elseif x then
				issueGhost(unitID, ghostID, x, y, z, opts.coded, tag, outer)
			end
		end
		return false
	end
	if
		issuing
		and fromSynced
		and fromLua
		and playerID == -1
		and cmdID == attack
		and #params == 3
		and unitID == issuing[1]
		and params[1] == issuing[2]
		and params[2] == issuing[3]
		and params[3] == issuing[4]
	then
		return true
	end
	-- Human orders to a team shared with a skirmish AI also pass through here.
	-- The engine normally exempts those teams from its terrain clamp.
	local aboveGround = false
	if #params >= 3 and (playerID >= 0 or opts.keepheight) then
		local ceiling = math.max(0, Spring.GetGroundHeight(params[1], params[3]))
		aboveGround = params[2] > ceiling
		if aboveGround then
			params[2] = ceiling
		end
	end
	if not opts.keepheight and not aboveGround then
		return true
	end
	issue(unitID, cmdID, params, math.bit_and(opts.coded, clearHeight), tag, outer)
	return false
end

function gadget:UnitCommand(unitID, unitDefID, teamID, cmdID, params, opts)
	local target
	if cmdID == attack and #params == 1 and not opts.internal then
		target = params[1]
	elseif
		cmdID == insert
		and params[2] == attack
		and #params == 4
		and math.bit_and(params[3], CMD.OPT_INTERNAL) == 0
	then
		target = params[4]
	end
	if getGhost and target and Spring.GetUnitLeavesGhost(target) then
		attackers[target] = attackers[target] or {}
		attackers[target][unitID] = true
	end
end

-- Only the positions carrying this sighting's tags are eligible for conversion.
local function finishSighting(ghostID, contact)
	local sighting = sightings[ghostID]
	if not sighting then
		return
	end
	sightings[ghostID] = nil
	for unitID, tags in pairs(sighting.orders) do
		for _, cmd in ipairs(getQueue(unitID, -1)) do
			if tags[cmd.tag] and cmd.id == attack and cmd.options.keepheight then
				if contact and Spring.GetUnitAllyTeam(unitID) == sighting.allyTeam then
					local bits = math.bit_and(cmd.options.coded, clearHeight)
					giveOrder(unitID, insert, { cmd.tag, attack, bits, contact }, 0)
				end
				giveOrder(unitID, remove, { cmd.tag }, 0)
			end
		end
	end
end

local function updateContact(_, target, _, allyTeam, _, ghostID)
	if not ghostID or not (sightings[ghostID] or attackers[target]) then
		return
	end
	local x, y, z, contact = getGhost(ghostID, allyTeam)
	if not x then
		return
	end
	if contact then
		finishSighting(ghostID, contact)
	elseif attackers[target] then
		for unitID in pairs(attackers[target]) do
			if Spring.GetUnitAllyTeam(unitID) == allyTeam then
				for _, cmd in ipairs(getQueue(unitID, -1)) do
					if
						cmd.id == attack
						and #cmd.params == 1
						and cmd.params[1] == target
						and not cmd.options.internal
					then
						if issueGhost(unitID, ghostID, x, y, z, cmd.options.coded, cmd.tag, { coded = 0 }) then
							giveOrder(unitID, remove, { cmd.tag }, 0)
						end
					end
				end
				attackers[target][unitID] = nil
			end
		end
		if not next(attackers[target]) then
			attackers[target] = nil
		end
	end
end

gadget.UnitEnteredLos = updateContact
gadget.UnitEnteredRadar = updateContact
gadget.UnitLeftLos = updateContact
gadget.UnitLeftRadar = updateContact

function gadget:GameFrame(frame)
	if frame % 16 ~= 0 then
		return
	end
	for ghostID, sighting in pairs(sightings) do
		if not getGhost(ghostID, sighting.allyTeam) then
			finishSighting(ghostID)
		elseif frame % 160 == 0 then
			-- Shift cancellations and queue replacements may discard an order silently.
			for unitID, tags in pairs(sighting.orders) do
				local remaining = {}
				for _, cmd in ipairs(getQueue(unitID, -1)) do
					if tags[cmd.tag] and cmd.id == attack and cmd.options.keepheight then
						remaining[cmd.tag] = true
					end
				end
				sighting.orders[unitID] = next(remaining) and remaining or nil
			end
			if not next(sighting.orders) then
				sightings[ghostID] = nil
			end
		end
	end
end

function gadget:UnitTaken(unitID, unitDefID, teamID, newTeam)
	if Spring.GetUnitAllyTeam(unitID) == Spring.GetTeamAllyTeamID(newTeam) then
		return
	end
	for _, sighting in pairs(sightings) do
		local tags = sighting.orders[unitID]
		if tags then
			for _, cmd in ipairs(getQueue(unitID, -1)) do
				if tags[cmd.tag] and cmd.id == attack and cmd.options.keepheight then
					giveOrder(unitID, remove, { cmd.tag }, 0)
				end
			end
			sighting.orders[unitID] = nil
		end
	end
end

function gadget:UnitDestroyed(unitID)
	for _, sighting in pairs(sightings) do
		sighting.orders[unitID] = nil
	end
	attackers[unitID] = nil
	for _, units in pairs(attackers) do
		units[unitID] = nil
	end
end
