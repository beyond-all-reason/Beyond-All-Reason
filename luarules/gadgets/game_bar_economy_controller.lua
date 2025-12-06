local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "BAR Economy Controller",
		desc      = "Controls resource sharing via Water-Fill algorithm",
		author    = "Antigravity",
		date      = "2024",
		license   = "GPL-v2",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local BarEconomy = VFS.Include("common/luaUtilities/team_transfer/bar_economy.lua")
local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")
local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local ResourceTransfer = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_synced.lua")
local ResourceApi = VFS.Include("common/luaUtilities/economy/bar_economy.lua")

local ResourceType = SharedEnums.ResourceType

GG = GG or {}

---@type ISpring
local springRepo = Spring

function GG.GetTeamResourceData(teamID, resource)
	return springRepo.GetTeamResourceData(teamID, resource)
end

function GG.SetTeamResourceData(teamID, resourceData)
	return springRepo.SetTeamResourceData(teamID, resourceData)
end

function GG.SetTeamResource(teamID, resource, amount)
	return ResourceApi.setTeamResource(springRepo, teamID, resource, amount)
end

function GG.GetTeamResources(teamID, resource)
	return ResourceApi.getTeamResources(springRepo, teamID, resource)
end

function GG.AddTeamResource(teamID, resource, amount)
	return ResourceApi.addTeamResource(springRepo, teamID, resource, amount)
end

function GG.ShareTeamResource(teamID, targetTeamID, resource, amount)
	return ResourceApi.shareTeamResource(springRepo, teamID, targetTeamID, resource, amount)
end

function GG.SetTeamShareLevel(teamID, resource, level)
	return ResourceApi.setTeamShareLevel(springRepo, teamID, resource, level)
end

function GG.GetTeamShareLevel(teamID, resource)
	return ResourceApi.getTeamShareLevel(springRepo, teamID, resource)
end

local contextFactory = ContextFactoryModule.create(springRepo)
local lastPolicyUpdate = 0
local POLICY_UPDATE_RATE = 150 -- Update every ~5 seconds (assuming 30fps)

---@param frame number
local function UpdatePolicyCache(frame)
	if frame < lastPolicyUpdate + POLICY_UPDATE_RATE then
		return
	end

	local taxRate, thresholds = SharedConfig.getTaxConfig(springRepo)
	local resultFactory = ResourceTransfer.BuildResultFactory(taxRate, thresholds[ResourceType.METAL], thresholds[ResourceType.ENERGY])
	
	local allTeams = springRepo.GetTeamList()
	for _, senderID in ipairs(allTeams) do
		for _, receiverID in ipairs(allTeams) do
			local ctx = contextFactory.policy(senderID, receiverID)
			
			local metalPolicy = resultFactory(ctx, ResourceType.METAL)
			ResourceTransfer.CachePolicyResult(springRepo, senderID, receiverID, ResourceType.METAL, metalPolicy)
			
			local energyPolicy = resultFactory(ctx, ResourceType.ENERGY)
			ResourceTransfer.CachePolicyResult(springRepo, senderID, receiverID, ResourceType.ENERGY, energyPolicy)
		end
	end
end

--------------------------------------------------------------------------------
-- Resource Transfer
--------------------------------------------------------------------------------

---@param srcTeamID number
---@param dstTeamID number
function gadget:TeamShare(srcTeamID, dstTeamID)
	-- Transfer all resources
	local metalData = springRepo.GetTeamResourceData(srcTeamID, ResourceType.METAL)
	local energyData = springRepo.GetTeamResourceData(srcTeamID, ResourceType.ENERGY)

	if metalData and metalData.current > 0 then
		GG.ShareTeamResource(srcTeamID, dstTeamID, ResourceType.METAL, metalData.current)
	end
	if energyData and energyData.current > 0 then
		GG.ShareTeamResource(srcTeamID, dstTeamID, ResourceType.ENERGY, energyData.current)
	end

	-- Transfer all units
	local units = springRepo.GetTeamUnits(srcTeamID) or {}
	for _, unitID in ipairs(units) do
		springRepo.TransferUnit(unitID, dstTeamID, true)
	end
end


---@param frame number
---@param teams TeamResourceData[]
---@return table<number, TeamResourceData>
function gadget:ProcessEconomy(frame, teams)
	local updatedTeams, allLedgers = BarEconomy.ProcessEconomy(springRepo, teams)
	
	local result = {}
	for _, team in ipairs(updatedTeams) do
		if team.id then
			result[team.id] = {
				metal = {
					current = team.metal.current,
					sent = team.metal.sent,
					received = team.metal.received,
					excess = team.metal.excess
				},
				energy = {
					current = team.energy.current,
					sent = team.energy.sent,
					received = team.energy.received,
					excess = team.energy.excess
				}
			}
		end
	end
	
	UpdatePolicyCache(frame)
	return result
end
