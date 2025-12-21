local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Resource Transfer Controller",
		desc      = "Controls resource transfers via Water-Fill algorithm",
		author    = "Antigravity",
		date      = "2024",
		license   = "GPL-v2",
		layer     = -200,  -- Load very early so GG.* functions are available to other gadgets (ai_simpleai is -100)
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local ResourceTransfer = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_synced.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
local LuaRulesMsg = VFS.Include("common/luaUtilities/lua_rules_msg.lua")
local EconomyLog = VFS.Include("common/luaUtilities/economy/economy_log.lua")

local ResourceType = SharedEnums.ResourceType

--------------------------------------------------------------------------------
-- Module globals
--------------------------------------------------------------------------------

GG = GG or {}

---@type ISpring
local springRepo = Spring
local contextFactory = ContextFactoryModule.create(springRepo)
local lastPolicyUpdate = 0
local POLICY_UPDATE_RATE = 30 -- Update every SlowUpdate (1 second at 30fps)

--------------------------------------------------------------------------------
-- GG API (Lua-side conveniences for other gadgets)
--------------------------------------------------------------------------------

function GG.GetTeamResourceData(teamID, resource)
	return springRepo.GetTeamResourceData(teamID, resource)
end

function GG.SetTeamResourceData(teamID, resourceData)
	return springRepo.SetTeamResourceData(teamID, resourceData)
end

function GG.SetTeamResource(teamID, resource, amount)
	return springRepo.SetTeamResource(teamID, resource, amount)
end

function GG.GetTeamResources(teamID, resource)
	return springRepo.GetTeamResources(teamID, resource)
end

function GG.AddTeamResource(teamID, resource, amount)
	local current = springRepo.GetTeamResources(teamID, resource) or 0
	return springRepo.SetTeamResource(teamID, resource, current + amount)
end

---@param teamID number Sender team ID
---@param targetTeamID number Receiver team ID  
---@param resource string|ResourceType Resource type
---@param amount number Desired amount to transfer
---@return ResourceTransferResult
function GG.ShareTeamResource(teamID, targetTeamID, resource, amount)
	local policyResult = Shared.GetCachedPolicyResult(teamID, targetTeamID, resource, springRepo)
	local ctx = contextFactory.resourceTransfer(teamID, targetTeamID, resource, amount, policyResult)
	local transferResult = ResourceTransfer.ResourceTransfer(ctx)
	
	if transferResult.success then
		ResourceTransfer.RegisterPostTransfer(ctx, transferResult)
		Comms.SendTransferChatMessages(transferResult, transferResult.policyResult)
	end
	
	return transferResult
end

---@param teamID number
---@param resource string|ResourceType
---@param level number
function GG.SetTeamShareLevel(teamID, resource, level)
	Spring.SetTeamShareLevel(teamID, resource, level)
	lastPolicyUpdate = 0 -- Force policy cache refresh on next ProcessEconomy
end

---@param teamID number
---@param resource string|ResourceType
---@return number?
function GG.GetTeamShareLevel(teamID, resource)
	local _, _, _, _, _, share = springRepo.GetTeamResources(teamID, resource)
	return share
end

local function InitializeNewTeam(senderTeamId)
	local taxRate, thresholds = SharedConfig.getTaxConfig(springRepo)
	local resultFactory = ResourceTransfer.BuildResultFactory(taxRate, thresholds[ResourceType.METAL], thresholds[ResourceType.ENERGY])
	local allTeams = springRepo.GetTeamList() or {}

	for _, receiverID in ipairs(allTeams) do
		local ctx = contextFactory.policy(senderTeamId, receiverID)
		
		-- Initialize accumulators
		for _, resourceType in ipairs(SharedEnums.ResourceTypes) do
			local param = Shared.GetCumulativeParam(resourceType)
			springRepo.SetTeamRulesParam(senderTeamId, param, 0)
		end

		local metalPolicy = resultFactory(ctx, ResourceType.METAL)
		ResourceTransfer.CachePolicyResult(springRepo, senderTeamId, receiverID, ResourceType.METAL, metalPolicy)
		
		local energyPolicy = resultFactory(ctx, ResourceType.ENERGY)
		ResourceTransfer.CachePolicyResult(springRepo, senderTeamId, receiverID, ResourceType.ENERGY, energyPolicy)
	end
end

function gadget:PlayerAdded(playerID)
	local _, _, _, teamID = springRepo.GetPlayerInfo(playerID, false)
	if teamID then
		InitializeNewTeam(teamID)
	end
end

--------------------------------------------------------------------------------
-- ProcessEconomy
-- Note: economyAudit.Begin("PE", frame) is called by C++ before this runs,
-- so source_path and frame context are already set for all logging.
--------------------------------------------------------------------------------

---@param frame number
---@param teams table<number, TeamResourceData>
---@return EconomyTeamResult[]
local function ProcessEconomy(frame, teams)
	local teamCount = 0
	for _ in pairs(teams) do teamCount = teamCount + 1 end
	
	local taxRate, thresholds = SharedConfig.getTaxConfig(springRepo)
	EconomyLog.FrameStart(taxRate, thresholds[ResourceType.METAL], thresholds[ResourceType.ENERGY], teamCount)
	
	EconomyLog.Breakpoint("Solver")
	
	local updatedTeams, allLedgers = ResourceTransfer.WaterfillSolve(springRepo, teams)
	
	local result = {}
	for teamId, team in pairs(updatedTeams) do
		local ledger = allLedgers[teamId] or {}
		
		result[#result + 1] = {
			teamId = teamId,
			resourceType = ResourceType.METAL,
			current = team.metal.current,
			sent = ledger[ResourceType.METAL] and ledger[ResourceType.METAL].sent or 0,
			received = ledger[ResourceType.METAL] and ledger[ResourceType.METAL].received or 0,
		}
		
		result[#result + 1] = {
			teamId = teamId,
			resourceType = ResourceType.ENERGY,
			current = team.energy.current,
			sent = ledger[ResourceType.ENERGY] and ledger[ResourceType.ENERGY].sent or 0,
			received = ledger[ResourceType.ENERGY] and ledger[ResourceType.ENERGY].received or 0,
		}
	end
	EconomyLog.Breakpoint("PostMunge")
	
	lastPolicyUpdate = ResourceTransfer.UpdatePolicyCache(springRepo, frame, lastPolicyUpdate, POLICY_UPDATE_RATE, contextFactory)
	EconomyLog.Breakpoint("PolicyCache")
	
	return result
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
	Spring.Echo("[ResourceTransferController] Initialize starting...")
	
	-- Mode is now controlled at engine level via modrules.lua economy_audit_mode
	local currentMode = Game.economyAuditMode or "off"
	Spring.Echo("[ResourceTransferController] Engine audit mode: " .. tostring(currentMode))
	
	local teamList = springRepo.GetTeamList() or {}
	Spring.Echo("[ResourceTransferController] Found " .. #teamList .. " teams")
	for _, senderTeamId in ipairs(teamList) do
		InitializeNewTeam(senderTeamId)
	end
	lastPolicyUpdate = springRepo.GetGameFrame()
	
	if Spring.IsEconomyAuditEnabled() then
		for _, teamId in ipairs(teamList) do
			local _, leader, _, isAI, _, allyTeam = Spring.GetTeamInfo(teamId)
			local name
			if isAI then
				local _, aiName = Spring.GetAIInfo(teamId)
				name = aiName or ("AI " .. teamId)
			else
				local playerName = leader and Spring.GetPlayerInfo(leader, false) or nil
				name = playerName or ("Player " .. teamId)
			end
			EconomyLog.TeamInfo(teamId, name, isAI)
		end
	end
	
	-- Register ProcessEconomy controller unless in pure RESOURCE_EXCESS mode
	-- (in ALTERNATE mode, the engine will skip calling ProcessEconomy on alternate cycles)
	if currentMode ~= "resource_excess" then
		Spring.Echo("[ResourceTransferController] Registering GameEconomyController...")
		---@type GameEconomyController
		local controller = { ProcessEconomy = ProcessEconomy }
		Spring.SetEconomyController(controller)
		Spring.Echo("[ResourceTransferController] SUCCESS: Registered GameEconomyController")
	else
		Spring.Echo("[ResourceTransferController] RESOURCE_EXCESS mode - skipping ProcessEconomy registration")
		Spring.Echo("[ResourceTransferController] ResourceExcessController will handle excess via gadget:ResourceExcess")
	end
end
