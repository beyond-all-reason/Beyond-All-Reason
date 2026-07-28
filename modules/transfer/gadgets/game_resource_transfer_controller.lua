local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Resource Transfer Controller",
		desc = "Allied resource shares: the policy, the ledger, the chat, and the assist tax",
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

local ModuleHandler = VFS.Include("modules/module_handler.lua")
local ResourceTypes = VFS.Include("gamedata/resource_types.lua")
local ContextFactoryModule = VFS.Include("modules/transfer/context_factory.lua")
local ResourceTransfer = VFS.Include("modules/transfer/resource/synced.lua")
local Shared = VFS.Include("modules/transfer/resource/shared.lua")
local TransferApi = VFS.Include("modules/transfer/api.lua")
local Comms = VFS.Include("modules/transfer/resource/comms.lua")
local TechBlockingShared = VFS.Include("modules/transfer/resource/tax.lua")
local LuaRulesMsg = VFS.Include("modules/transfer/lib/lua_rules_msg.lua")
local ManualShareLedger = VFS.Include("modules/transfer/economy/manual_share_ledger.lua")

local modOptions = Spring.GetModOptions()

local METAL = ResourceTypes.METAL
local ENERGY = ResourceTypes.ENERGY

local springRepo = Spring

local spUseUnitResource = Spring.UseUnitResource
local contextFactory = ContextFactoryModule.create(springRepo)
local lastPolicyUpdate = 0

---@param teamID integer Sender team ID
---@param targetTeamID integer Receiver team ID
---@param resource ResourceName Resource type
---@param amount number Desired amount to transfer
---@return ResourceTransferResult
function GG.ShareTeamResource(teamID, targetTeamID, resource, amount)
	local policyResult = Shared.GetCachedPolicyResult(teamID, targetTeamID, resource, springRepo)
	local ctx = contextFactory.resourceTransfer(teamID, targetTeamID, resource, amount, policyResult)
	local transferResult = ResourceTransfer.ResourceTransfer(ctx)

	local policyResult = transferResult.policyResult
	if transferResult.success and policyResult then
		ManualShareLedger.Record(
			teamID,
			targetTeamID,
			policyResult.resourceType,
			transferResult.sent,
			transferResult.received
		)
		Comms.SendTransferChatMessages(transferResult, policyResult)
	end

	return transferResult
end

---@param teamID integer
---@param resource ResourceName
---@param level number
function GG.SetTeamShareLevel(teamID, resource, level)
	-- share level is read live (waterfill cursor + UI), not a cached factor, so no refresh forced
	Spring.SetTeamShareLevel(teamID, resource, level)
end

local function InitializeNewTeam(teamId)
	contextFactory.clearResourceCache()
	local ctx = contextFactory.policy(teamId, teamId)
	ResourceTransfer.CacheTeamFactor(Spring, teamId, ResourceTypes.METAL, ctx)
	ResourceTransfer.CacheTeamFactor(Spring, teamId, ResourceTypes.ENERGY, ctx)
end

function gadget:PlayerAdded(playerID)
	local _, _, _, teamID = springRepo.GetPlayerInfo(playerID, false)
	if teamID then
		InitializeNewTeam(teamID)
	end
end

-- economy stamps the frame it redistributed on; the factors read the currents it left
local lastRedistribution = -1
function gadget:GameFrame(frame)
	local stamp = Spring.GetGameRulesParam("economy_redistributed_frame")
	if stamp ~= nil and stamp ~= lastRedistribution then
		lastRedistribution = stamp
		lastPolicyUpdate = ResourceTransfer.UpdatePolicyCache(springRepo, frame, lastPolicyUpdate, 0, contextFactory)
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	local params = LuaRulesMsg.ParseResourceShare(msg)
	if params then
		TransferApi.Resources(params.resourceType, params.amount, params.targetTeamID, params.senderTeamID)
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
end

if TechBlockingShared.AnyTaxConfigured(modOptions) then
	local AssistTax = VFS.Include("modules/transfer/lib/assist_tax.lua")
	local Construction = VFS.Include("modules/construction/api.lua")
	local constructionPipelines = ModuleHandler.LoadPolicies("construction") ---@type ConstructionPipelines

	-- The verdict is construction's build pipeline (this module contributes
	-- the affordability gate to it); the deduction is ours.
	---@param ctx ConstructionBuildContext
	---@return boolean
	local function payAssistTax(ctx)
		local quote = AssistTax.Quote(ctx, modOptions, springRepo)
		if quote == nil then
			return true
		end
		ctx.delayed = Construction.IsBuilderDelayed(ctx.builderID)
		if not ModuleHandler.Evaluate(constructionPipelines.build, ctx) then
			return false
		end
		spUseUnitResource(ctx.builderID, "metal", quote.metalTax)
		if quote.energyTax > 0 then
			spUseUnitResource(ctx.builderID, "energy", quote.energyTax)
		end
		return true
	end

	function gadget:AllowUnitBuildStep(builderID, builderTeam, unitID, unitDefID, part)
		return payAssistTax({
			builderID = builderID,
			builderTeam = builderTeam,
			delayed = false,
			unitID = unitID,
			unitDefID = unitDefID,
			part = part,
		})
	end

	function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
		return payAssistTax({
			builderID = builderID,
			builderTeam = builderTeam,
			delayed = false,
			featureID = featureID,
			part = part,
		})
	end
end
