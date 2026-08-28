local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Wave Reactions",
		desc = "How a director's units answer being hit, or landing a hit: skirmish away, flee when hurt, or charge — some by teleport",
		author = "Damgam, Beyond All Reason",
		date = "August 2026",
		license = "GNU GPL, v2 or later",
		layer = 2,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local Reactions = VFS.Include("modules/waves/lib/reactions.lua")
local positionCheck = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")

local HOST_REFRESH = 30

local hostByTeam = {} ---@type table<integer, table>
local policies = {} ---@type table<string, WaveReactionRules>
local reactedAt = {} ---@type table<integer, number>

local function refreshHosts()
	hostByTeam = {}
	for _, host in ipairs(GG.Waves.Hosts()) do
		if host.reactions ~= nil then
			policies[host.name] = policies[host.name] or Reactions.Policy(host.reactions)
			hostByTeam[host.teamID] = host
		end
	end
end

---@param host table
---@param unitID integer
---@param defID integer
---@param record WaveReaction
---@param x number
---@param y number
---@param z number
---@param size number
---@return boolean
local function teleport(host, unitID, defID, record, x, y, z, size)
	local cooldowns = host.state.teleportCooldown
	if not record.teleport or (cooldowns[unitID] or 1) >= Spring.GetGameFrame() then
		return false
	end
	if not (positionCheck.FlatAreaCheck(x, y, z, size, 30, false) and positionCheck.MapEdgeCheck(x, y, z, size)) then
		return false
	end
	if size >= 128 and not positionCheck.OccupancyCheck(x, y, z, 64) then
		return false
	end
	local fx, fy, fz = Spring.GetUnitPosition(unitID)
	Spring.SetUnitPosition(unitID, x, z)
	Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
	if host.hooks.onUnitTeleported then
		host.hooks.onUnitTeleported(unitID, defID, fx, fy, fz, x, y, z)
	end
	cooldowns[unitID] = Spring.GetGameFrame() + (record.teleportCooldown or 0) * Game.gameSpeed
	return true
end

---@param host table
---@param unitID integer
local function hold(host, unitID)
	local policy = policies[host.name]
	GG.Waves.SetCowardCooldown(host.name, unitID, Spring.GetGameFrame() + policy.fleeSeconds * Game.gameSpeed)
end

---Move `unitID` away from (fromX, fromZ), by teleport when the def may and
---the ground allows, else by order.
local function flee(host, unitID, defID, record, fromX, fromZ)
	local x, y, z = Spring.GetUnitPosition(unitID)
	if x == nil or fromX == nil then
		return
	end
	local tx, tz = Reactions.FleeTarget(record, x, z, fromX, fromZ, math.random)
	if not teleport(host, unitID, defID, record, tx, y, tz, 64) then
		Spring.GiveOrderToUnit(unitID, CMD.MOVE, { tx, y, tz }, {})
	end
	hold(host, unitID)
end

---Charge `unitID` at the target when within the record's distance.
local function charge(host, unitID, defID, record, targetID)
	local ax, ay, az = Spring.GetUnitPosition(targetID)
	if ax == nil then
		return
	end
	local separation = Spring.GetUnitSeparation(unitID, targetID)
	if separation == nil or separation >= (record.distance or 10000) then
		return
	end
	ax = ax + math.random(-128, 128)
	az = az + math.random(-128, 128)
	if not teleport(host, unitID, defID, record, ax, ay, az, 128) then
		Spring.GiveOrderToUnit(unitID, CMD.MOVE, { ax, ay, az }, {})
	end
	hold(host, unitID)
end

---@param defID integer|nil
---@return UnitDefName|nil
local function nameOf(defID)
	local unitDef = defID and UnitDefs[defID]
	return unitDef and unitDef.name or nil
end

function gadget:GameFrame(frame)
	if frame % HOST_REFRESH == 0 and GG.Waves ~= nil then
		refreshHosts()
	end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, _, _, _, _, attackerID, attackerDefID, attackerTeam)
	if attackerID == nil or unitTeam == attackerTeam or GG.Waves == nil then
		return
	end
	local host = hostByTeam[unitTeam] or hostByTeam[attackerTeam]
	if host == nil then
		return
	end
	local policy = policies[host.name]
	local now = Spring.GetGameSeconds()
	if (reactedAt[unitID] or 0) >= now - policy.timeout then
		return
	end
	local health, maxHealth = Spring.GetUnitHealth(unitID)
	local decision = Reactions.Decide(policy, {
		unitDef = nameOf(unitDefID),
		attackerDef = nameOf(attackerDefID),
		unitIsWave = unitTeam == host.teamID,
		attackerIsWave = attackerTeam == host.teamID,
		healthFraction = (health and maxHealth and maxHealth > 0) and health / maxHealth or nil,
	}, math.random)
	if decision == nil then
		return
	end
	reactedAt[unitID] = now
	if decision.kind == "none" then
		return
	end
	local actorID, actorDefID = unitID, unitDefID
	local otherID = attackerID
	if decision.actor == "attacker" then
		actorID, actorDefID, otherID = attackerID, attackerDefID, unitID
	end
	if decision.kind == "flee" then
		local ox, _, oz = Spring.GetUnitPosition(otherID)
		flee(host, actorID, actorDefID, decision.record, ox, oz)
	else
		charge(host, actorID, actorDefID, decision.record, otherID)
	end
end

function gadget:UnitDestroyed(unitID)
	reactedAt[unitID] = nil
end

function gadget:Initialize()
	if GG.Waves ~= nil then
		refreshHosts()
	end
end
