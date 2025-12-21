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
local Stopwatch = VFS.Include("common/luaUtilities/stopwatch.lua")
local AuditLog = VFS.Include("common/luaUtilities/economy/economy_audit_log.lua")

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
--------------------------------------------------------------------------------

---@param frame number
---@param teams table<number, TeamResourceData>
---@return EconomyTeamResult[]
local function ProcessEconomy(frame, teams)
	local stopwatch = Stopwatch.new(Spring.GetAuditTimer)
	stopwatch:Start()
	
	
	stopwatch:Breakpoint("PE_Solver")
	
	local updatedTeams, allLedgers = ResourceTransfer.WaterfillSolve(springRepo, teams, frame)
	
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
	stopwatch:Breakpoint("PE_PostMunge")
	
	lastPolicyUpdate = ResourceTransfer.UpdatePolicyCache(springRepo, frame, lastPolicyUpdate, POLICY_UPDATE_RATE, contextFactory)
	stopwatch:Breakpoint("PE_PolicyCache")
	
	stopwatch:Log(frame)
	
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
	local currentMode = AuditLog.GetMode()  -- Returns "off", "process_economy", "resource_excess", or "alternate"
	Spring.Echo("[ResourceTransferController] Engine audit mode: " .. tostring(currentMode))
	
	if Spring.GetAuditTimer then
		Spring.Echo("[ResourceTransferController] Timer available: Spring.GetAuditTimer")
	else
		Spring.Echo("[ResourceTransferController] WARNING: Spring.GetAuditTimer not available - rebuild engine for Lua-side timing")
	end
	
	local teamList = springRepo.GetTeamList() or {}
	Spring.Echo("[ResourceTransferController] Found " .. #teamList .. " teams")
	for _, senderTeamId in ipairs(teamList) do
		InitializeNewTeam(senderTeamId)
	end
	lastPolicyUpdate = springRepo.GetGameFrame()
	
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
