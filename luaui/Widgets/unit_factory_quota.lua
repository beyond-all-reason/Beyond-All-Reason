local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Factory Quotas",
		desc = "Creates quotas of units that should be maintained(for example 5 Sheldons, 5 Sumos), that will be queued before factory queue.",
		author = "hihoman23",
		date = "2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetMyTeamID = Spring.GetLocalTeamID

local maxBuildProg = 0.075 -- maximum build progress that gets replaced in a repeat queue
local maxMetal = 500 -- maximum metal cost that gets replaced in a repeat queue(7.5% of a juggernaut is still over 2k metal)

-- factoryID is unitID of the factory
local quotas = {} -- {[factoryID] = {[unitDefID] = amount, ...}, ...}

local builtUnits = {} -- {[factoryID] = {[unitDefID] = {[unitID] = true, ...}, ...}, ...}
local unitToFactoryID = {} -- {[unitID] = factoryID, ...}

-- Quota orders cannot be told apart from player orders by their options alone.
-- - The engine marks an alt-queued factory build order internal, but only while repeat is on.
-- - With repeat off, the internal bit reads as "quota order".
-- - With repeat on, the internal bit reads as "quota or player priority order".

local quotaOrderTags = {}
local quotaOrderCounts = {}
local seenOrderTags = {}
local unclaimedOrders = {}
local unclaimedPasses = {}

local possibleFactories = {}
local factoryDefIDs = {}
local metalcosts = {}

for unitDefID, uDef in pairs(UnitDefs) do
	metalcosts[unitDefID] = uDef.metalCost
	if uDef.isFactory then
		factoryDefIDs[unitDefID] = true
		for _, opt in pairs(uDef.buildOptions) do
			possibleFactories[opt] = possibleFactories[opt] or {}
			possibleFactories[opt][unitDefID] = true
		end
	end
end

----- Speed ups ------
local myTeam = spGetMyTeamID()
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc

local CMD_INSERT = CMD.INSERT
local CMD_OPT_ALT = CMD.OPT_ALT
local CMD_OPT_CTRL = CMD.OPT_CTRL
local CMD_OPT_INTERNAL = CMD.OPT_INTERNAL
local CMD_QUOTA_BUILD_TOGGLE = GameCMD.QUOTA_BUILD_TOGGLE
-----

--------- quota logic -------------
local function getNumberOfUnits(factoryID, unitDefID)
	local numberOfUnits
	if builtUnits[factoryID] and builtUnits[factoryID][unitDefID] then
		numberOfUnits = table.count(builtUnits[factoryID][unitDefID])
	else
		numberOfUnits = 0
	end
	return numberOfUnits
end

local function getMostNeedQuota(quota, factoryID)
	local minimumQuota
	local minimumUnitDefID
	local minimumRatio
	for unitDefID, quotaNumber in pairs(quota) do
		if not minimumQuota then
			minimumQuota = quotaNumber
			minimumUnitDefID = unitDefID
			minimumRatio = getNumberOfUnits(factoryID, unitDefID) / quotaNumber
		else
			local currentRatio = getNumberOfUnits(factoryID, unitDefID) / quotaNumber
			if currentRatio < minimumRatio then
				minimumQuota = quotaNumber
				minimumUnitDefID = unitDefID
				minimumRatio = currentRatio
			end
		end
	end
	return minimumQuota, minimumUnitDefID
end

local function trackQuotaOrders(factoryID)
	local commandQueue = spGetFactoryCommands(factoryID, -1)
	if not commandQueue then
		quotaOrderTags[factoryID] = nil
		quotaOrderCounts[factoryID] = nil
		seenOrderTags[factoryID] = nil
		unclaimedOrders[factoryID] = nil
		unclaimedPasses[factoryID] = nil
		return
	end

	local ownedTags = quotaOrderTags[factoryID]
	local seenTags = seenOrderTags[factoryID]
	local unclaimed = unclaimedOrders[factoryID]

	local liveOwnedTags = {}
	local liveSeenTags = {}
	local counts = {}

	for i = 1, #commandQueue do
		local command = commandQueue[i]
		local unitDefID = -command.id
		if unitDefID > 0 and command.options.internal then
			local tag = command.tag
			liveSeenTags[tag] = true

			local isOurs = ownedTags and ownedTags[tag]
			if not isOurs and not (seenTags and seenTags[tag]) and unclaimed and (unclaimed[unitDefID] or 0) > 0 then
				unclaimed[unitDefID] = unclaimed[unitDefID] - 1
				isOurs = true
			end

			if isOurs then
				liveOwnedTags[tag] = unitDefID
				counts[unitDefID] = (counts[unitDefID] or 0) + 1
			end
		end
	end

	quotaOrderTags[factoryID] = liveOwnedTags
	quotaOrderCounts[factoryID] = counts
	seenOrderTags[factoryID] = liveSeenTags

	-- Keep a build order unclaimed for multiple passes so it continues to be pending.
	if unclaimed and next(unclaimed) then
		local passes = (unclaimedPasses[factoryID] or 0) + 1
		if passes > 1 then
			unclaimedOrders[factoryID] = nil
			unclaimedPasses[factoryID] = nil
		else
			unclaimedPasses[factoryID] = passes
		end
	else
		unclaimedOrders[factoryID] = nil
		unclaimedPasses[factoryID] = nil
	end
end

-- Whether a factory has any quota-issued build orders anywhere in its factory queue,
-- including issued orders that have not arrived yet over the env/net/msg boogie wop.
local function hasQuotaOrderPending(factoryID)
	local counts = quotaOrderCounts[factoryID]
	if counts and next(counts) then
		return true
	end
	local unclaimed = unclaimedOrders[factoryID]
	return (unclaimed and next(unclaimed)) ~= nil
end

-- Number of build orders in the factory's queue that this widget placed.
-- Subtract from the engine's queued count to get the count of orders by the player.
local function getQuotaOrderCount(factoryID, unitDefID)
	local counts = quotaOrderCounts[factoryID]
	return (counts and counts[unitDefID]) or 0
end

-- Check the head of the queue only to answer whether the factory can accept a quota order.
-- Quota defers to enqueued-first commands that players issue (with alt) as a panic button.
local function isFactoryUsable(factoryID)
	local commandQueue = spGetFactoryCommands(factoryID, 2)
	if not commandQueue then
		return true
	end
	return commandQueue
		and (
			#commandQueue == 0
			or not (
				commandQueue[1].options.alt
				or (commandQueue[2] and (commandQueue[2].options.alt or (commandQueue[2].id == CMD.WAIT)))
				or (commandQueue[1].id == CMD.WAIT)
			)
		)
end

local function appendToFactoryQueue(factoryID, unitDefID)
	local currentCmdID, targetID = Spring.GetUnitWorkerTask(factoryID)
	local insertPosition = 1
	if targetID then
		local _, _, _, _, buildProgress = Spring.GetUnitHealth(targetID)
		if
			buildProgress < maxBuildProg
			and metalcosts[-currentCmdID]
			and (buildProgress * metalcosts[-currentCmdID]) < maxMetal
		then -- 7.5 % is the most that it is willing to cancel, and maximally 500 metal
			insertPosition = 0
		end
	else
		insertPosition = 0 -- put in front of factory queue
	end
	spGiveOrderToUnit(
		factoryID,
		CMD_INSERT,
		{ insertPosition, -unitDefID, CMD_OPT_ALT + CMD_OPT_INTERNAL },
		CMD_OPT_ALT + CMD_OPT_CTRL
	)

	-- Claimed by tag on the next pass, once the order has reached the queue.
	unclaimedOrders[factoryID] = unclaimedOrders[factoryID] or {}
	unclaimedOrders[factoryID][unitDefID] = (unclaimedOrders[factoryID][unitDefID] or 0) + 1
	unclaimedPasses[factoryID] = 0
end

local function fillQuotas()
	for factoryID, quota in pairs(quotas) do
		trackQuotaOrders(factoryID)
		if isFactoryUsable(factoryID) and not hasQuotaOrderPending(factoryID) then
			for unitDefID, num in pairs(quota) do
				if num == 0 then
					quota[unitDefID] = nil
				end
			end
			if table.count(quota) > 0 then
				local quotaNum, unitDefID = getMostNeedQuota(quota, factoryID)
				if quotaNum > getNumberOfUnits(factoryID, unitDefID) then
					appendToFactoryQueue(factoryID, unitDefID)
				end
			end
		end
	end
end

function widget:GameFrame(n)
	if n % 15 == 0 then -- improve performance
		fillQuotas()
	end
end

----- handle toggle
local function isOnQuotaBuildMode(unitID)
	local cmdDescIndex = spFindUnitCmdDesc(unitID, CMD_QUOTA_BUILD_TOGGLE)
	return cmdDescIndex and spGetUnitCmdDescs(unitID)[cmdDescIndex].params[1] + 0 == 1
end

----- handle unit tracking
function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderID and unitTeam == myTeam and factoryDefIDs[spGetUnitDefID(builderID)] then
		builtUnits[builderID] = builtUnits[builderID] or {}
		builtUnits[builderID][unitDefID] = builtUnits[builderID][unitDefID] or {}
		builtUnits[builderID][unitDefID][unitID] = true
		unitToFactoryID[unitID] = builderID
	end
end

local function removeUnit(unitID, unitDefID, unitTeam)
	if unitTeam == myTeam then --check if it was built by the same player
		local factoryID = unitToFactoryID[unitID]
		if factoryID and builtUnits[factoryID] and builtUnits[factoryID][unitDefID] then
			builtUnits[factoryID][unitDefID][unitID] = nil
			unitToFactoryID[unitID] = nil
		elseif builtUnits[unitID] then
			builtUnits[unitID] = nil
			quotas[unitID] = nil
			quotaOrderTags[unitID] = nil
			quotaOrderCounts[unitID] = nil
			seenOrderTags[unitID] = nil
			unclaimedOrders[unitID] = nil
			unclaimedPasses[unitID] = nil
		end
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	removeUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if myTeam == oldTeam and myTeam ~= newTeam then
		removeUnit(unitID, unitDefID, myTeam)
	end
end

function widget:PlayerChanged(playerID)
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
	myTeam = spGetMyTeamID()
end

function widget:Initialize()
	widget:PlayerChanged()

	WG.Quotas = {}
	WG.Quotas.getQuotas = function()
		return quotas
	end
	WG.Quotas.getUnitAmount = function(factoryID, unitDefID)
		return getNumberOfUnits(factoryID, unitDefID)
	end
	WG.Quotas.isOnQuotaMode = function(unitID)
		return isOnQuotaBuildMode(unitID)
	end
	WG.Quotas.getQuotaOrderCount = function(factoryID, unitDefID)
		return getQuotaOrderCount(factoryID, unitDefID)
	end
end

function widget:Shutdown()
	WG.Quotas = nil
end
