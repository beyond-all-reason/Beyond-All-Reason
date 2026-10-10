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

local AssistTax = require("modules/transfer/lib/assist_tax")
local Construction = require("modules/construction/api")
local ContextFactoryModule = require("modules/transfer/context_factory")
local LuaRulesMsg = require("modules/transfer/lib/lua_rules_msg")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local ResourceTransfer = require("modules/transfer/api_synced").Resources
local ResourceTypes = require("gamedata/resource_types")
local Tax = require("modules/transfer/resource/tax")

local METAL = ResourceTypes.METAL
local ENERGY = ResourceTypes.ENERGY

local springRepo = Spring

local spUseUnitResource = Spring.UseUnitResource
local contextFactory = ContextFactoryModule.create(springRepo)
local lastPolicyUpdate = 0 ---@type number

---@param teamID integer
---@param resource ResourceName
---@param level number
function GG.SetTeamShareLevel(teamID, resource, level)
	Spring.SetTeamShareLevel(teamID, resource, level)
end

local function InitializeNewTeam(teamId)
	contextFactory.clearResourceCache()
	local ctx = contextFactory.policy(teamId, teamId)
	ResourceTransfer.CacheTeamFactor(Spring, teamId, ResourceTypes.METAL, ctx)
	ResourceTransfer.CacheTeamFactor(Spring, teamId, ResourceTypes.ENERGY, ctx)
	Tax.Refresh({ teamId }, springRepo)
end

function gadget:PlayerAdded(playerID)
	local _, _, _, teamID = springRepo.GetPlayerInfo(playerID, false)
	---@cast teamID integer?
	if teamID then
		InitializeNewTeam(teamID)
	end
end

local lastRedistribution = -1 ---@type number
function gadget:GameFrame(frame)
	local stamp = Spring.GetGameRulesParam("economy_redistributed_frame")
	if stamp ~= nil and stamp ~= lastRedistribution then
		lastRedistribution = stamp
		lastPolicyUpdate = ResourceTransfer.UpdatePolicyCache(springRepo, frame, lastPolicyUpdate, 0, contextFactory)
		Tax.Refresh(springRepo.GetTeamList() or {}, springRepo)
	end
end

---@return boolean handled
function gadget:RecvLuaMsg(msg, playerID)
	local params = LuaRulesMsg.ParseResourceShare(msg)
	if params then
		ResourceTransfer.Share(params.resourceType, params.amount, params.targetTeamID, params.senderTeamID)
		return true
	end
	return false
end

-- The engine's own share, which the player list's slider still sends (Spring.ShareResources): the module does it
-- under the pair's terms, taxed, capped or refused as the mode says, and the engine's transfer does not happen. The
-- engine names the resource by its initial.
local RESOURCE_BY_ENGINE_NAME = { m = "metal", metal = "metal", e = "energy", energy = "energy" }
function gadget:AllowResourceTransfer(fromTeamID, toTeamID, resourceType, amount)
	local resource = RESOURCE_BY_ENGINE_NAME[resourceType]
	if resource == nil then
		return true
	end
	ResourceTransfer.Share(resource, amount, toTeamID, fromTeamID)
	return false
end

function gadget:Initialize()
	local teamList = Spring.GetTeamList()
	for _, senderTeamId in ipairs(teamList) do
		InitializeNewTeam(senderTeamId)
	end
	lastPolicyUpdate = Spring.GetGameFrame()
end

---@param ctx ConstructionBuildContext
---@return boolean
local function payAssistTax(ctx)
	---@type ConstructionContract
	local ConstructionContract = ModuleHandler.Contract(Modules.Construction)
	local quote = AssistTax.Quote(ctx, springRepo)
	if quote == nil then
		return true
	end
	ctx.delayed = Construction.IsBuilderDelayed(ctx.builderID)
	if not ModuleHandler.Evaluate(ConstructionContract.Build, ctx) then
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
		springRepo = springRepo,
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
		springRepo = springRepo,
		builderID = builderID,
		builderTeam = builderTeam,
		delayed = false,
		featureID = featureID,
		part = part,
	})
end
