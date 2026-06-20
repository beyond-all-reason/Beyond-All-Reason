local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	if Game.nativeExcessSharing ~= false then
		Spring.Echo("ERROR: Resource Transfer Controller requires nativeExcessSharing=false (Lua-owned resource sharing); economy GG API unavailable")
	end
	return {
		name = "Resource Transfer Controller",
		desc = "Controls allied resource sharing via Water-Fill on the gadget:ResourceExcess callin",
		author = "Antigravity",
		date = "2024",
		license = "GPL-v2",
		layer = -200,
		enabled = Game.nativeExcessSharing == false,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- GG API defined before module imports so it survives module failure

GG = GG or {}

local TeamResourceData = VFS.Include("common/luaUtilities/team_transfer/team_resource_data.lua")
local ShareStats = VFS.Include("common/luaUtilities/economy/share_stats.lua")

-- single place the GG economy boundary applies Lua-owned sent/received (engine no longer tracks them)
local function overlaySharing(teamID, resource, sent, received)
	local s = ShareStats.Read(Spring, teamID, resource)
	return s.sentRecent or sent, s.receivedRecent or received
end

function GG.GetTeamResourceData(teamID, resource)
	local d = TeamResourceData.Get(Spring, teamID, resource)
	d.sent, d.received = overlaySharing(teamID, resource, d.sent, d.received)
	return d
end

function GG.GetTeamResources(teamID, resource)
	local cur, stor, pull, inc, exp, share, sent, received = Spring.GetTeamResources(teamID, resource)
	sent, received = overlaySharing(teamID, resource, sent, received)
	return cur, stor, pull, inc, exp, share, sent, received
end

function GG.AddTeamResource(teamID, resource, amount)
	local current = Spring.GetTeamResources(teamID, resource)
	return Spring.SetTeamResource(teamID, resource, current + amount)
end

local ResourceTypes = VFS.Include("gamedata/resource_types.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local ResourceTransfer = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_synced.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
local TechBlockingShared = VFS.Include("common/luaUtilities/team_transfer/tech_blocking_shared.lua")
local LuaRulesMsg = VFS.Include("common/luaUtilities/lua_rules_msg.lua")
local ManualShareLedger = VFS.Include("common/luaUtilities/economy/manual_share_ledger.lua")

local WaterfillSolver = VFS.Include("common/luaUtilities/economy/economy_waterfill_solver.lua")

local tracyAvailable = tracy and tracy.ZoneBeginN and tracy.ZoneEnd

local modOptions = Spring.GetModOptions()

local METAL = ResourceTypes.METAL
local ENERGY = ResourceTypes.ENERGY

local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitTeam = Spring.GetUnitTeam
local spGetTeamResources = Spring.GetTeamResources
local spUseUnitResource = Spring.UseUnitResource
local spGetFeatureResources = Spring.GetFeatureResources
local spGetFeatureResurrect = Spring.GetFeatureResurrect
local spAreTeamsAllied = Spring.AreTeamsAllied
local spSetTeamResource = Spring.SetTeamResource
local spAddTeamResourceExcessStats = Spring.AddTeamResourceExcessStats
local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamList = Spring.GetTeamList
local spGetGameFrame = Spring.GetGameFrame

local gaiaTeamID = Spring.GetGaiaTeamID()

local springRepo = Spring
local contextFactory = ContextFactoryModule.create(springRepo)
local lastPolicyUpdate = 0

-- The engine fires gadget:ResourceExcess every frame, but redistribution runs on a
-- slower cadence (matches the native TEAM_SLOWUPDATE_RATE the gadget replaces). The
-- per-frame overflow is accumulated and folded into the snapshot on the cadence tick.
local CADENCE = 30

---@param teamID number Sender team ID
---@param targetTeamID number Receiver team ID
---@param resource string|ResourceName Resource type
---@param amount number Desired amount to transfer
---@return ResourceTransferResult
function GG.ShareTeamResource(teamID, targetTeamID, resource, amount)
	local policyResult = Shared.GetCachedPolicyResult(teamID, targetTeamID, resource, springRepo)
	local ctx = contextFactory.resourceTransfer(teamID, targetTeamID, resource, amount, policyResult)
	local transferResult = ResourceTransfer.ResourceTransfer(ctx)

	if transferResult.success then
		ManualShareLedger.Record(teamID, targetTeamID, transferResult.policyResult.resourceType, transferResult.sent, transferResult.received)
		Comms.SendTransferChatMessages(transferResult, transferResult.policyResult)
	end

	return transferResult
end

---@param teamID number
---@param resource string|ResourceName
---@param level number
function GG.SetTeamShareLevel(teamID, resource, level)
	-- Share level feeds the waterfill cursor (read live from GetTeamResources each
	-- cadence tick) and the UI reads it directly; it is not a cached policy factor,
	-- so no factor refresh is forced here.
	Spring.SetTeamShareLevel(teamID, resource, level)
end

---@param teamID number
---@param resource string|ResourceName
---@return number?
function GG.GetTeamShareLevel(teamID, resource)
	local _, _, _, _, _, share = Spring.GetTeamResources(teamID, resource)
	return share
end

local function InitializeNewTeam(teamId)
	-- Factors are per-team and independent, so a new/changed team only needs its own
	-- record rewritten; GetCachedPolicyResult pairs it against every other team on read.
	contextFactory.clearResourceCache()
	local ctx = contextFactory.policy(teamId, teamId)
	ResourceTransfer.CacheTeamFactor(Spring, teamId, ResourceTypes.METAL, ctx)
	ResourceTransfer.CacheTeamFactor(Spring, teamId, ResourceTypes.ENERGY, ctx)
end

function gadget:PlayerAdded(playerID)
	local _, _, _, teamID = Spring.GetPlayerInfo(playerID, false)
	if teamID then
		InitializeNewTeam(teamID)
	end
end

-- Per-team overflow accumulator. The engine has already deducted this overflow from
-- the producer (clamped to storage) before the callin, so the solver re-injects it as
-- the snapshot's `excess` and the apply step hands it to recipients.
local overflowAccum = {} ---@type table<number, number[]>

-- Pooled snapshot entries so the cadence tick does not allocate per team per second.
local snapshotPool = {} ---@type table<number, TeamResourceData>

---Build the waterfill input from live engine state plus the accumulated overflow.
---@return table<number, TeamResourceData>
local function buildSnapshot()
	local teams = {}
	local teamList = spGetTeamList()
	for i = 1, #teamList do
		local teamID = teamList[i]
		if teamID ~= gaiaTeamID then
			local _, _, isDead, _, _, allyTeam = spGetTeamInfo(teamID, false)
			local acc = overflowAccum[teamID]
			local mCur, mStor, _, _, _, mShare = spGetTeamResources(teamID, METAL)
			local eCur, eStor, _, _, _, eShare = spGetTeamResources(teamID, ENERGY)

			local entry = snapshotPool[teamID]
			if not entry then
				entry = { metal = { resourceType = METAL }, energy = { resourceType = ENERGY } }
				snapshotPool[teamID] = entry
			end
			entry.allyTeam = allyTeam
			entry.isDead = isDead

			local m = entry.metal
			m.current = mCur
			m.storage = mStor
			m.shareSlider = mShare
			m.excess = acc and acc[1] or 0

			local e = entry.energy
			e.current = eCur
			e.storage = eStor
			e.shareSlider = eShare
			e.excess = acc and acc[2] or 0

			teams[teamID] = entry
		end
	end
	return teams
end

---Redistribute accumulated overflow + share-slider excess across allied teams, then
---refresh the policy factor cache. Runs on the cadence tick inside gadget:ResourceExcess.
---@param frame number
local function ProcessEconomy(frame)
	if tracyAvailable then
		tracy.ZoneBeginN("ResourceExcess_Cadence")
	end

	local teams = buildSnapshot()
	local results = ManualShareLedger.FoldInto(WaterfillSolver.SolveToResults(springRepo, teams))

	-- The solver wrote each team's clamped post-share total back into the snapshot.
	-- SetTeamResource moves the pools; AddTeamResourceExcessStats records only excess (the
	-- engine's conservation ledger legitimately accounts for resource leaving the system).
	-- sent/received are conserved transfers, tracked Lua-side via ShareStats below.
	for i = 1, #results do
		local r = results[i]
		local team = teams[r.teamId]
		local resData = team and team[r.resourceType]
		if resData then
			spSetTeamResource(r.teamId, r.resourceType, resData.current)
			spAddTeamResourceExcessStats(r.teamId, r.resourceType, r.excess)
		end
	end

	ShareStats.Publish(springRepo, results)

	-- Overflow consumed this tick; clear so the next window starts from zero.
	for _, acc in pairs(overflowAccum) do
		acc[1] = 0
		acc[2] = 0
	end

	-- Policy factor refresh, folded into the same cadence tick and reading the
	-- post-redistribution currents. updateRate 0 => always runs when called.
	lastPolicyUpdate = ResourceTransfer.UpdatePolicyCache(springRepo, frame, lastPolicyUpdate, 0, contextFactory)

	if tracyAvailable then
		tracy.ZoneEnd()
	end
end

---Synced, fires every frame for every team. excesses[teamID] = { [1]=metal, [2]=energy }
---overflow the engine has already deducted from the producer this frame. Returning true
---takes ownership so the engine does not native-buffer the overflow into resDelayedShare.
---@param excesses ResourceExcesses
---@return boolean handled
function gadget:ResourceExcess(excesses)
	for teamID, pack in pairs(excesses) do
		local acc = overflowAccum[teamID]
		if not acc then
			acc = { 0, 0 }
			overflowAccum[teamID] = acc
		end
		acc[1] = acc[1] + (pack[1] or 0)
		acc[2] = acc[2] + (pack[2] or 0)
	end

	local frame = spGetGameFrame()
	if frame % CADENCE == 0 then
		ProcessEconomy(frame)
	end

	return true
end

function gadget:RecvLuaMsg(msg, playerID)
	local params = LuaRulesMsg.ParseResourceShare(msg)
	if params then
		GG.ShareTeamResource(params.senderTeamID, params.targetTeamID, params.resourceType, params.amount)
		return true
	end
	return false
end

function gadget:Initialize()
	if not spAddTeamResourceExcessStats then
		Spring.Echo("ERROR: Resource Transfer Controller requires Spring.AddTeamResourceExcessStats (engine resource-excess-callin + excess-stats port); excess stats will be unavailable")
	end

	local teamList = Spring.GetTeamList()
	for _, senderTeamId in ipairs(teamList) do
		InitializeNewTeam(senderTeamId)
	end
	lastPolicyUpdate = Spring.GetGameFrame()
end

if TechBlockingShared.AnyTaxConfigured(modOptions) then
	function gadget:AllowUnitBuildStep(builderID, builderTeam, unitID, unitDefID, part)
		if part <= 0 then -- reclaiming
			return true
		end

		local beingBuilt = spGetUnitIsBeingBuilt(unitID)
		if not beingBuilt then -- repair, not construction
			return true
		end

		local unitTeam = spGetUnitTeam(unitID)
		if not unitTeam or builderTeam == unitTeam then
			return true -- own unit, no tax
		end

		if not spAreTeamsAllied(builderTeam, unitTeam) then
			return true -- enemy, not taxable
		end

		local unitDef = UnitDefs[unitDefID]
		if not unitDef then
			return true
		end

		local taxRate = TechBlockingShared.GetTaxRate(builderTeam, modOptions)
		if taxRate <= 0 then
			return true -- no tax at this team's tech level
		end

		local metalCost = unitDef.metalCost
		local energyCost = unitDef.energyCost
		local metalTax = metalCost * part * taxRate
		local energyTax = energyCost * part * taxRate
		local currentMetal = spGetTeamResources(builderTeam, "metal")
		local currentEnergy = spGetTeamResources(builderTeam, "energy")

		if currentMetal < (metalTax + metalCost * part) or currentEnergy < (energyTax + energyCost * part) then
			return false -- can't afford tax
		end

		spUseUnitResource(builderID, "metal", metalTax)
		spUseUnitResource(builderID, "energy", energyTax)
		return true
	end

	function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
		if part < 0 then -- reclaiming
			return true
		end

		local resurrectUnitName = spGetFeatureResurrect(featureID)
		if not resurrectUnitName or resurrectUnitName == "" then
			return true -- not a resurrectable wreck
		end

		-- Only tax during metal insertion phase (phase 1)
		local featureMetal, featureMaxMetal = spGetFeatureResources(featureID)
		if not featureMetal or featureMaxMetal <= 0 or featureMetal >= featureMaxMetal then
			return true -- phase 2 (actual resurrection), no metal cost
		end

		local taxRate = TechBlockingShared.GetTaxRate(builderTeam, modOptions)
		if taxRate <= 0 then
			return true -- no tax at this team's tech level
		end

		local metalTax = featureMaxMetal * part * taxRate
		local teamMetal = spGetTeamResources(builderTeam, "metal")

		if teamMetal < (metalTax + featureMaxMetal * part) then
			return false -- can't afford tax
		end

		spUseUnitResource(builderID, "metal", metalTax)
		return true
	end
end -- if AnyTaxConfigured
