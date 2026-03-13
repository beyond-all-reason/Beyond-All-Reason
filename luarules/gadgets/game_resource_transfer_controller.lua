local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Resource Transfer Controller",
		desc      = "Controls resource transfers via Water-Fill algorithm (ProcessEconomy path)",
		author    = "Antigravity",
		date      = "2024",
		license   = "GPL-v2",
		layer     = -200,
		enabled   = Game.gameEconomy == true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

--------------------------------------------------------------------------------
-- GG API (defined first so other gadgets can use them even if modules fail)
--------------------------------------------------------------------------------

GG = GG or {}

local TeamResourceData = VFS.Include("common/luaUtilities/team_transfer/team_resource_data.lua")

function GG.GetTeamResourceData(teamID, resource)
	return TeamResourceData.Get(Spring, teamID, resource)
end

function GG.GetTeamResources(teamID, resource)
	return Spring.GetTeamResources(teamID, resource)
end

function GG.AddTeamResource(teamID, resource, amount)
	local current = Spring.GetTeamResources(teamID, resource)
	return Spring.SetTeamResource(teamID, resource, current + amount)
end

--------------------------------------------------------------------------------
-- Module imports
--------------------------------------------------------------------------------

local ResourceTypes = VFS.Include("gamedata/resource_types.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local ResourceTransfer = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_synced.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
local LuaRulesMsg = VFS.Include("common/luaUtilities/lua_rules_msg.lua")
local EconomyLog = VFS.Include("common/luaUtilities/economy/economy_log.lua")

local WaterfillSolver = VFS.Include("common/luaUtilities/economy/economy_waterfill_solver.lua")

local tracyAvailable = tracy and tracy.ZoneBeginN and tracy.ZoneEnd

--------------------------------------------------------------------------------
-- Module globals
--------------------------------------------------------------------------------

local contextFactory = ContextFactoryModule.create(Spring)
local lastPolicyUpdate = 0
local POLICY_UPDATE_RATE = 30 -- Update every SlowUpdate (1 second at 30fps)

---@type table<number, TeamResourceData>
local teamsCache = {}
local statsSentBuffer = { sent = { 0, 0 } }
local statsRecvBuffer = { received = { 0, 0 } }

---@param teamID number Sender team ID
---@param targetTeamID number Receiver team ID  
---@param resource string|ResourceName Resource type
---@param amount number Desired amount to transfer
---@return ResourceTransferResult
function GG.ShareTeamResource(teamID, targetTeamID, resource, amount)
	local policyResult = Shared.GetCachedPolicyResult(teamID, targetTeamID, resource, Spring)
	local ctx = contextFactory.resourceTransfer(teamID, targetTeamID, resource, amount, policyResult)
	local transferResult = ResourceTransfer.ResourceTransfer(ctx)
	
	if transferResult.success then
		ResourceTransfer.RegisterPostTransfer(ctx, transferResult)
		Comms.SendTransferChatMessages(transferResult, transferResult.policyResult)
	end
	
	return transferResult
end

---@param teamID number
---@param resource string|ResourceName
---@param level number
function GG.SetTeamShareLevel(teamID, resource, level)
	Spring.SetTeamShareLevel(teamID, resource, level)
	lastPolicyUpdate = 0
end

---@param teamID number
---@param resource string|ResourceName
---@return number?
function GG.GetTeamShareLevel(teamID, resource)
	local _, _, _, _, _, share = Spring.GetTeamResources(teamID, resource)
	return share
end

local function InitializeNewTeam(senderTeamId)
	local allTeams = Spring.GetTeamList()

	for _, receiverID in ipairs(allTeams) do
		local ctx = contextFactory.policy(senderTeamId, receiverID)
		
		for _, resourceType in ipairs(ResourceTypes) do
			local param = Shared.GetCumulativeParam(resourceType)
			Spring.SetTeamRulesParam(senderTeamId, param, 0)
		end

		local metalPolicy = ResourceTransfer.CalcResourcePolicy(ctx, ResourceTypes.METAL)
		ResourceTransfer.CachePolicyResult(Spring, senderTeamId, receiverID, ResourceTypes.METAL, metalPolicy)

		local energyPolicy = ResourceTransfer.CalcResourcePolicy(ctx, ResourceTypes.ENERGY)
		ResourceTransfer.CachePolicyResult(Spring, senderTeamId, receiverID, ResourceTypes.ENERGY, energyPolicy)
	end
end

function gadget:PlayerAdded(playerID)
	local _, _, _, teamID = Spring.GetPlayerInfo(playerID, false)
	if teamID then
		InitializeNewTeam(teamID)
	end
end

--------------------------------------------------------------------------------
-- ProcessEconomy Controller
--------------------------------------------------------------------------------

local pendingPolicyUpdate = false
local pendingPolicyFrame = 0

---@param frame number
---@param teams table<number, TeamResourceData>
---@return EconomyTeamResult[]
local function ProcessEconomy(frame, teams)
	if tracyAvailable then tracy.ZoneBeginN("PE_Lua") end

	local results = WaterfillSolver.SolveToResults(Spring, teams)
	
	pendingPolicyUpdate = true
	pendingPolicyFrame = frame
	
	if tracyAvailable then tracy.ZoneEnd() end
	return results
end

local function DeferredPolicyUpdate()
	if not pendingPolicyUpdate then return end
	pendingPolicyUpdate = false
	
	if tracyAvailable then tracy.ZoneBeginN("PE_PolicyCache_Deferred") end
	lastPolicyUpdate = ResourceTransfer.UpdatePolicyCache(
		Spring, pendingPolicyFrame, lastPolicyUpdate, POLICY_UPDATE_RATE, contextFactory
	)
	if tracyAvailable then tracy.ZoneEnd() end
end

--------------------------------------------------------------------------------
-- Gadget callins
--------------------------------------------------------------------------------

function gadget:RecvLuaMsg(msg, playerID)
	local params = LuaRulesMsg.ParseResourceShare(msg)
	if params then
		GG.ShareTeamResource(params.senderTeamID, params.targetTeamID, params.resourceType, params.amount)
		return true
	end
	return false
end

function gadget:Initialize()
	local teamList = Spring.GetTeamList()
	for _, senderTeamId in ipairs(teamList) do
		InitializeNewTeam(senderTeamId)
	end
	lastPolicyUpdate = Spring.GetGameFrame()
	
	---@type GameEconomyController
	local controller = { ProcessEconomy = ProcessEconomy }
	Spring.SetEconomyController(controller)
end

function gadget:GameStart()
	if not Spring.IsEconomyAuditEnabled() then return end
	
	local gaiaTeamId = Spring.GetGaiaTeamID()
	local teamList = Spring.GetTeamList() or {}
	for _, teamId in ipairs(teamList) do
		local _, leader, _, isAI, _, allyTeam = Spring.GetTeamInfo(teamId)
		local isGaia = (teamId == gaiaTeamId)
		local name
		if isAI then
			local niceName = Spring.GetGameRulesParam('ainame_' .. teamId)
			if niceName then
				name = niceName
			else
				local _, aiName = Spring.GetAIInfo(teamId)
				name = aiName or ("AI " .. teamId)
			end
		else
			local playerName = leader and Spring.GetPlayerInfo(leader, false) or nil
			name = playerName or ("Player " .. teamId)
		end
		EconomyLog.TeamInfo(teamId, name, isAI, allyTeam, isGaia)
	end
end

function gadget:GameFrame(frame)
	DeferredPolicyUpdate()
end
