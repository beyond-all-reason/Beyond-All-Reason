local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	if Game.nativeExcessSharing ~= false then
		Spring.Echo("ERROR: Resource Redistribution requires nativeExcessSharing=false (Lua-owned redistribution)")
	end
	return {
		name = "Resource Redistribution",
		desc = "Each team's excess goes to its allies by waterfill, on the gadget:ResourceExcess callin",
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

GG = GG or {}

local TeamResourceData = VFS.Include("modules/economy/lib/team_resource_data.lua")
local ShareStats = VFS.Include("modules/economy/lib/share_stats.lua")
local ResourceTypes = VFS.Include("gamedata/resource_types.lua")
local WaterfillSolver = VFS.Include("modules/economy/lib/waterfill_solver.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Contract = VFS.Include("modules/economy/contract.lua") ---@type EconomyContract

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
	local current = Spring.GetTeamResources(teamID, resource) or 0
	return Spring.SetTeamResource(teamID, resource, current + amount)
end

-- cast: the library meta declares tracy unconditionally, but profiler-less engine builds lack it
local tracyAvailable = (tracy and tracy.ZoneBeginN and tracy.ZoneEnd) ~= nil --[[@as boolean]]

local METAL = ResourceTypes.METAL
local ENERGY = ResourceTypes.ENERGY

local springRepo = Spring
local spGetTeamResources = springRepo.GetTeamResources
local spSetTeamResource = springRepo.SetTeamResource
local spAddTeamResourceExcessStats = springRepo.AddTeamResourceExcessStats
local spGetTeamInfo = springRepo.GetTeamInfo
local spGetTeamList = springRepo.GetTeamList
local spGetGameFrame = springRepo.GetGameFrame

local gaiaTeamID = springRepo.GetGaiaTeamID()

-- redistribution cadence (matches native TEAM_SLOWUPDATE_RATE); per-frame overflow accumulates between ticks
local CADENCE = 30

---What another module says a team's redistribution costs; nothing, when nobody says.
---@param teamId integer
---@return number
local function taxRateFor(_, teamId)
	---@type EconomyTeamContext
	local ctx = { teamId = teamId, springRepo = springRepo }
	local terms = ModuleHandler.Enrich(Contract.Distribution, springRepo.GetModOptions(), ctx)
	return tonumber(terms[Contract.Distribution.TaxRate]) or 0
end

---The tick's results as other modules amend them before they are published.
---@param results EconomyTeamResult[]
---@return EconomyTeamResult[]
local function amended(results)
	---@type EconomyRedistributionContext
	local ctx = { results = results }
	local amendedResults = ModuleHandler.Enrich(Contract.Redistribution, springRepo.GetModOptions(), ctx)
	return amendedResults[Contract.Redistribution.Results] or results
end

local overflowAccum = {} ---@type table<integer, [number, number]>

-- Pooled snapshot entries so the cadence tick does not allocate per team per second.
local snapshotPool = {} ---@type table<integer, TeamResourceData>

---@return table<integer, TeamResourceData>
local function buildSnapshot()
	local teams = {} ---@type table<integer, TeamResourceData>
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
				entry = {
					allyTeam = 0,
					isDead = false,
					metal = {
						resourceType = METAL,
						current = 0,
						storage = 0,
						shareSlider = 0,
						sent = 0,
						received = 0,
						excess = 0,
					},
					energy = {
						resourceType = ENERGY,
						current = 0,
						storage = 0,
						shareSlider = 0,
						sent = 0,
						received = 0,
						excess = 0,
					},
				}
				snapshotPool[teamID] = entry
			end
			entry.allyTeam = allyTeam
			entry.isDead = isDead

			local m = entry.metal --[[@as ResourceData]]
			m.current = mCur
			m.storage = mStor
			m.shareSlider = mShare
			m.excess = acc and acc[1] or 0

			local e = entry.energy --[[@as ResourceData]]
			e.current = eCur
			e.storage = eStor
			e.shareSlider = eShare
			e.excess = acc and acc[2] or 0

			teams[teamID] = entry
		end
	end
	return teams
end

---@param frame number
local function redistribute(frame)
	if tracyAvailable then
		tracy.ZoneBeginN("ResourceExcess_Cadence")
	end

	local teams = buildSnapshot()
	local results = amended(WaterfillSolver.SolveToResults(springRepo, teams, taxRateFor))

	for i = 1, #results do
		local r = results[i]
		local team = teams[r.teamId]
		local resData = team and team[r.resourceType]
		if resData then
			spSetTeamResource(r.teamId, r.resourceType, resData.current)
			if spAddTeamResourceExcessStats then
				spAddTeamResourceExcessStats(r.teamId, r.resourceType, r.excess)
			end
		end
	end

	ShareStats.Publish(springRepo, results)

	for _, acc in pairs(overflowAccum) do
		acc[1] = 0
		acc[2] = 0
	end

	-- whoever caches post-redistribution state watches this stamp
	Spring.SetGameRulesParam("economy_redistributed_frame", frame)

	if tracyAvailable then
		tracy.ZoneEnd()
	end
end

---Returning true takes ownership so the engine does not native-buffer the overflow
---into resDelayedShare.
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
		redistribute(frame)
	end

	return true
end

if not springRepo.AddTeamResourceExcessStats then
	-- Engine without RecoilEngine#2642: ResourceExcess never fires, so the cadence
	-- tick runs from GameFrame; only slider excess redistributes.
	function gadget:GameFrame(frame)
		if frame % CADENCE == 0 then
			redistribute(frame)
		end
	end
end

function gadget:Initialize()
	if not spAddTeamResourceExcessStats then
		Spring.Echo(
			"ERROR: Resource Redistribution requires Spring.AddTeamResourceExcessStats (engine resource-excess-callin + excess-stats port); excess stats will be unavailable"
		)
	end
end
