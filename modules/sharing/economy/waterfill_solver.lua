local ResourceTypes = VFS.Include("gamedata/resource_types.lua")
local SharedConfig = VFS.Include("modules/sharing/economy/shared_config.lua")

local ResourceType = ResourceTypes
local RESOURCE_TYPES = { ResourceTypes.METAL, ResourceTypes.ENERGY }

local Gadgets = {}
Gadgets.__index = Gadgets

local EPSILON = 1e-6
-- cast: the library meta declares tracy unconditionally, but profiler-less engine builds lack it
local tracyAvailable = (tracy and tracy.ZoneBeginN and tracy.ZoneEnd) ~= nil --[[@as boolean]]

local memberCache = {} ---@type table<integer, EconomyShareMember>
local groupCache = {} ---@type table<integer, EconomyShareMember[]>
local groupSizes = {} ---@type table<integer, integer>
local teamLedgerCache = {} ---@type table<integer, table<ResourceName, EconomyFlowLedger>>

---@param value number?
---@return number
local function normalizeSlider(value)
	if type(value) ~= "number" then
		return 0
	end
	if value > 1 then
		value = value * 0.01
	end
	if value < 0 then
		return 0
	end
	if value > 1 then
		return 1
	end
	return value
end

---@param teamsList table<integer, TeamResourceData>
---@param resourceType ResourceName
---@return table<integer, EconomyShareMember[]>, table<integer, integer>
local function collectMembers(teamsList, resourceType)
	for allyTeam in pairs(groupCache) do
		groupSizes[allyTeam] = 0
	end

	for teamId, team in pairs(teamsList) do
		if not team.isDead then
			local resource = team[resourceType]
			if resource then
				local allyTeam = team.allyTeam
				local storage = resource.storage
				local excess = resource.excess
				local current = resource.current + excess
				local shareCursor = storage * normalizeSlider(resource.shareSlider)
				if shareCursor > storage then
					shareCursor = storage
				end

				local member = memberCache[teamId]
				if not member then
					member = {}
					memberCache[teamId] = member
				end
				member.teamId = teamId
				member.allyTeam = allyTeam
				member.resourceType = resourceType
				member.resource = resource
				member.current = current
				member.storage = storage
				member.shareCursor = shareCursor

				local group = groupCache[allyTeam]
				if not group then
					group = {}
					groupCache[allyTeam] = group
				end
				local size = (groupSizes[allyTeam] or 0) + 1
				groupSizes[allyTeam] = size
				group[size] = member
			end
		end
	end
	return groupCache, groupSizes
end

local LIFT_ITERATIONS = 32

local function effectiveSupply(m, target, rate)
	if m.current <= target + EPSILON then
		return 0
	end
	return (m.current - target) * (1 - rate)
end

local function demand(m, target)
	if m.current >= target - EPSILON then
		return 0
	end
	return target - m.current
end

local function balance(mems, memberCount, lift, rate)
	local supply, dem = 0, 0 ---@type number, number
	for i = 1, memberCount do
		local m = mems[i] --[[@as EconomyShareMember]]
		local target = math.min(m.shareCursor + lift, m.storage)
		supply = supply + effectiveSupply(m, target, rate)
		dem = dem + demand(m, target)
	end
	return supply - dem
end

local function calcGrossForEffective(effective, taxRate)
	if taxRate >= 1 - EPSILON then
		return 0
	end
	return effective / (1 - taxRate)
end

---@param members EconomyShareMember[]
---@param memberCount number
---@param taxRate number
---@return number lift
---@return table<integer, EconomyShareDelta> deltas
local function solveWaterfill(members, memberCount, taxRate)
	if memberCount == 0 then
		return 0, {}
	end

	local maxLift = 0 ---@type number
	for i = 1, memberCount do
		local m = members[i] --[[@as EconomyShareMember]]
		local headroom = m.storage - m.shareCursor
		if headroom > maxLift then
			maxLift = headroom
		end
	end

	local lo, hi = 0, maxLift ---@type number, number
	for _ = 1, LIFT_ITERATIONS do
		local mid = 0.5 * (lo + hi)
		if balance(members, memberCount, mid, taxRate) >= 0 then
			lo = mid
		else
			hi = mid
		end
	end
	local lift = lo

	local totalSupply, totalDemand = 0, 0 ---@type number, number
	local senderData = {}
	local receiverData = {}

	for i = 1, memberCount do
		local m = members[i] --[[@as EconomyShareMember]]
		local target = math.min(m.shareCursor + lift, m.storage)
		if m.current > target + EPSILON then
			local eff = effectiveSupply(m, target, taxRate)
			senderData[i] = { idx = i, member = m, target = target, effective = eff }
			totalSupply = totalSupply + eff
		elseif m.current < target - EPSILON then
			local dem = demand(m, target)
			receiverData[i] = { idx = i, member = m, target = target, demand = dem }
			totalDemand = totalDemand + dem
		end
	end

	local flowRatio = 1 ---@type number
	if totalDemand > EPSILON and totalSupply < totalDemand - EPSILON then
		flowRatio = totalSupply / totalDemand
	end
	-- senders scale down too: over-supply beyond demand stays as excess, not phantom sends
	local sendRatio = 1 ---@type number
	if totalSupply > EPSILON and totalDemand < totalSupply - EPSILON then
		sendRatio = totalDemand / totalSupply
	end

	local deltas = {}

	for i, sd in pairs(senderData) do
		local d = { gross = 0, net = 0, taxed = 0 } ---@type EconomyShareDelta
		local eff = sd.effective * sendRatio
		local grossSend = calcGrossForEffective(eff, taxRate)
		d.gross = -grossSend
		d.taxed = grossSend * taxRate
		d.net = -(grossSend - d.taxed)
		if math.abs(d.gross) >= EPSILON then
			deltas[i] = d
		end
	end

	for i, rd in pairs(receiverData) do
		local d = { gross = 0, net = 0, taxed = 0 } ---@type EconomyShareDelta
		local received = rd.demand * flowRatio
		d.gross = received
		d.net = received
		if math.abs(d.gross) >= EPSILON then
			deltas[i] = d
		end
	end

	return lift, deltas
end

---@param members EconomyShareMember[]
---@param memberCount number
---@param lift number
---@param deltas table<integer, EconomyShareDelta>
---@param taxRate number
---@return table<number, EconomyFlowLedger>
local function applyDeltas(members, memberCount, lift, deltas, taxRate)
	local ledgerCache = {}

	for i = 1, memberCount do
		local member = members[i] --[[@as EconomyShareMember]]
		local teamId = member.teamId
		local delta = deltas[i]

		local ledger = ledgerCache[teamId]
		if not ledger then
			ledger = { sent = 0, received = 0, taxed = 0, wasted = 0, snapshot = 0 } ---@type EconomyFlowLedger
			ledgerCache[teamId] = ledger
		end

		local target = member.shareCursor + lift
		if target > member.storage then
			target = member.storage
		end
		member.target = target

		local resource = member.resource
		if delta and math.abs(delta.gross) > EPSILON then
			if delta.gross < 0 then
				local grossSend = -delta.gross
				local taxedReceivable = grossSend * (1 - taxRate)

				local newCurrent = member.current - grossSend
				if newCurrent < 0 then
					newCurrent = 0
				end
				resource.current = newCurrent

				ledger.sent = grossSend
				ledger.taxed = taxedReceivable
			else
				local received = delta.net
				resource.current = member.current + received

				ledger.received = received
			end
		else
			resource.current = member.current
		end
	end

	for i = 1, memberCount do
		local member = members[i] --[[@as EconomyShareMember]]
		local resource = member.resource
		if resource.current > member.storage then
			ledgerCache[member.teamId].wasted = resource.current - member.storage
			resource.current = member.storage
		end
	end

	return ledgerCache
end

---@param springRepo EngineSynced
---@param teamsList table<integer, TeamResourceData>?
---@return table<integer, TeamResourceData>? teamsList the input table, updated in place (nil input passes through)
---@return EconomyFlowSummary
function Gadgets.Solve(springRepo, teamsList)
	if tracyAvailable then
		tracy.ZoneBeginN("WaterfillSolver.Solve")
	end

	if not teamsList then
		if tracyAvailable then
			tracy.ZoneEnd()
		end
		return teamsList, {}
	end

	local teamCount = 0
	for _ in pairs(teamsList) do
		teamCount = teamCount + 1
	end
	if teamCount == 0 then
		if tracyAvailable then
			tracy.ZoneEnd()
		end
		return teamsList, {}
	end

	-- tax is resolved per ally-group below (uniform tech level within an allyteam)

	for teamId in pairs(teamsList) do
		local teamLedger = teamLedgerCache[teamId]
		if not teamLedger then
			teamLedger = {
				[ResourceType.METAL] = { sent = 0, received = 0, taxed = 0, wasted = 0, snapshot = 0 },
				[ResourceType.ENERGY] = { sent = 0, received = 0, taxed = 0, wasted = 0, snapshot = 0 },
			}
			teamLedgerCache[teamId] = teamLedger
		end
		local team = teamsList[teamId]
		local m = teamLedger[ResourceType.METAL]
		m.sent = 0
		m.received = 0
		m.taxed = 0
		m.wasted = 0
		m.snapshot = team.metal and team.metal.current or 0
		local e = teamLedger[ResourceType.ENERGY]
		e.sent = 0
		e.received = 0
		e.taxed = 0
		e.wasted = 0
		e.snapshot = team.energy and team.energy.current or 0
	end

	for _, resourceType in ipairs(RESOURCE_TYPES) do
		if tracyAvailable then
			tracy.ZoneBeginN("CollectMembers:" .. resourceType)
		end
		local groups, sizes = collectMembers(teamsList, resourceType)
		if tracyAvailable then
			tracy.ZoneEnd()
		end

		for allyTeam, members in pairs(groups) do
			local memberCount = sizes[allyTeam] or 0
			if memberCount > 0 then
				local taxRate = SharedConfig.getTeamTaxRate(springRepo, (members[1] --[[@as EconomyShareMember]]).teamId)
				local lift, deltas = solveWaterfill(members, memberCount, taxRate)

				if tracyAvailable and tracy.LuaTracyPlot then
					tracy.LuaTracyPlot("Economy/Lift/" .. resourceType, lift)
				end

				if tracyAvailable then
					tracy.ZoneBeginN("ApplyDeltas")
				end
				local ledgers = applyDeltas(members, memberCount, lift, deltas, taxRate)
				if tracyAvailable then
					tracy.ZoneEnd()
				end

				for i = 1, memberCount do
					local member = members[i] --[[@as EconomyShareMember]]
					local teamId = member.teamId
					-- applyDeltas guarantees a ledger per member team
					local ledger = ledgers[teamId]
					local summary = teamLedgerCache[teamId][resourceType]
					summary.sent = summary.sent + ledger.sent
					summary.received = summary.received + ledger.received
					summary.taxed = summary.taxed + (ledger.taxed or 0)
					summary.wasted = summary.wasted + (ledger.wasted or 0)
				end
			end
		end
	end

	for teamId, team in pairs(teamsList) do
		local ledger = teamLedgerCache[teamId]
		if team.metal then
			local m = ledger[ResourceType.METAL]
			team.metal.sent = m.sent
			team.metal.received = m.received
		end
		if team.energy then
			local e = ledger[ResourceType.ENERGY]
			team.energy.sent = e.sent
			team.energy.received = e.received
		end
	end

	if tracyAvailable then
		tracy.ZoneEnd()
	end
	return teamsList, teamLedgerCache
end

local resultPool = {}

local function getPooledResult(teamId, resourceType)
	local key = teamId * 10 + (resourceType == ResourceType.METAL and 1 or 2)
	local entry = resultPool[key]
	if not entry then
		entry = { teamId = 0, resourceType = "", delta = 0, sent = 0, received = 0, excess = 0 }
		resultPool[key] = entry
	end
	return entry
end

---@param springRepo EngineSynced
---@param teamsList table<integer, TeamResourceData>?
---@return EconomyTeamResult[]
function Gadgets.SolveToResults(springRepo, teamsList)
	if tracyAvailable then
		tracy.ZoneBeginN("WaterfillSolver.SolveToResults")
	end

	local updatedTeams, allLedgers = Gadgets.Solve(springRepo, teamsList)

	local results = {} ---@type EconomyTeamResult[]
	local idx = 0

	if not updatedTeams then
		if tracyAvailable then
			tracy.ZoneEnd()
		end
		return results
	end

	for teamId, team in pairs(updatedTeams) do
		local ledger = allLedgers[teamId]

		if team.metal then
			idx = idx + 1
			local entry = getPooledResult(teamId, ResourceType.METAL)
			local m = ledger[ResourceType.METAL]
			entry.teamId = teamId
			entry.resourceType = ResourceType.METAL
			entry.delta = team.metal.current - m.snapshot
			entry.sent = m.sent
			entry.received = m.received
			entry.excess = m.wasted
			results[idx] = entry
		end

		if team.energy then
			idx = idx + 1
			local entry = getPooledResult(teamId, ResourceType.ENERGY)
			local e = ledger[ResourceType.ENERGY]
			entry.teamId = teamId
			entry.resourceType = ResourceType.ENERGY
			entry.delta = team.energy.current - e.snapshot
			entry.sent = e.sent
			entry.received = e.received
			entry.excess = e.wasted
			results[idx] = entry
		end
	end

	if tracyAvailable then
		tracy.ZoneEnd()
	end
	return results
end

return Gadgets
