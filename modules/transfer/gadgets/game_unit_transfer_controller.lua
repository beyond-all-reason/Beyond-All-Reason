---@class UnitTransferGadget : Gadget
---@field TeamShare fun(self, srcTeamID: number, dstTeamID: number)
local gadget = gadget ---@type UnitTransferGadget

function gadget:GetInfo()
	return {
		name = "Unit Transfer Controller",
		desc = "Controls unit ownership changes: sharing, takeovers, AllowUnitTransfer",
		author = "Rimilel, Attean, Antigravity",
		date = "April 2024",
		license = "GNU GPL, v2 or later",
		layer = -200,
		enabled = true,
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local TransferEnums = VFS.Include("modules/context/enums.lua")
local ContextFactoryModule = VFS.Include("modules/context/context_factory.lua")
local Shared = VFS.Include("modules/transfer/unit/shared.lua")
local TransferApi = VFS.Include("modules/transfer/api.lua")
local Construction = VFS.Include("modules/construction/api.lua")
local UnitTransfer = VFS.Include("modules/transfer/unit/synced.lua")
local UnitSharingCategories = VFS.Include("modules/transfer/unit/categories.lua")
local LuaRulesMsg = VFS.Include("common/luaUtilities/lua_rules_msg.lua")

-- mobile builders get buildspeed-0 debuff instead of stun

-- reused scratch tables; separate ones because AllowUnitTransfer fires inside ShareUnits' loop (shared would clobber)
local shareValidationScratch = {}

local mobileBuilderDefs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if UnitSharingCategories.isMobileBuilderDef(unitDef) then
		mobileBuilderDefs[unitDefID] = true
	end
end

local function applyBuildDelay(unitID, unitDefID, stunSeconds)
	-- Construction serves the delay: it owns the answer the engine asks for
	-- (may this builder build), and it sits underneath this module.
	Construction.DelayBuilder(unitID, stunSeconds)
end

local function shouldStunUnit(unitDefID, stunCategory)
	if not stunCategory then
		return false
	end
	return Shared.IsShareableDef(unitDefID, stunCategory, UnitDefs)
end

local function applyStun(unitID, unitDefID, policyResult)
	-- mobile builders get build-delay debuff instead of stun, independent of eco-building stun
	local buildDelaySeconds = tonumber(policyResult.buildDelaySeconds) or 0
	if buildDelaySeconds > 0 and mobileBuilderDefs[unitDefID] then
		applyBuildDelay(unitID, unitDefID, buildDelaySeconds)
		return
	end

	local stunSeconds = tonumber(policyResult.stunSeconds) or 0
	if stunSeconds <= 0 then
		return
	end

	local stunCategory = policyResult.stunCategory
	if not shouldStunUnit(unitDefID, stunCategory) then
		return
	end
	local _, maxHealth = Spring.GetUnitHealth(unitID)
	Spring.AddUnitDamage(unitID, maxHealth * 5, stunSeconds)
end

-- engine contract via SetUnitTransferController: AllowUnitTransfer + TeamShare

local springRepo = Spring
local contextFactory = ContextFactoryModule.create(springRepo)

local POLICY_CACHE_UPDATE_RATE = 150 -- 5 seconds
local lastPolicyCacheUpdate = 0

GG = GG or {}

local UnitTransferController = {}

-- per-team factor; GetCachedPolicyResult pairs it against other teams on read
---@param teamId integer
local function InitializeNewTeam(teamId)
	local ctx = contextFactory.policy(teamId, teamId)
	UnitTransfer.CacheTeamFactor(springRepo, teamId, ctx)
end

local function UpdatePolicyCache(frame)
	if frame < lastPolicyCacheUpdate + POLICY_CACHE_UPDATE_RATE then
		return
	end
	lastPolicyCacheUpdate = frame

	local teamList = springRepo.GetTeamList() or {}
	for _, teamId in ipairs(teamList) do
		InitializeNewTeam(teamId)
	end
end

---@param unitID integer
---@param newTeamID integer
---@param given boolean?
function GG.TransferUnit(unitID, newTeamID, given)
	springRepo.TransferUnit(unitID, newTeamID, given or false)
end

---@param unitIDs integer[]
---@param newTeamID integer
---@param given boolean?
---@return integer transferred count of successfully transferred units
function GG.TransferUnits(unitIDs, newTeamID, given)
	local transferred = 0
	for _, unitID in ipairs(unitIDs) do
		local success = springRepo.TransferUnit(unitID, newTeamID, given or false)
		if success then
			transferred = transferred + 1
		end
	end
	return transferred
end

---@param senderTeamID integer
---@param targetTeamID integer
---@param unitIDs integer[]
---@return UnitTransferResult
function GG.ShareUnits(senderTeamID, targetTeamID, unitIDs)
	local policyResult = Shared.GetCachedPolicyResult(senderTeamID, targetTeamID, springRepo)
	local validation = Shared.ValidateUnits(policyResult, unitIDs, springRepo, nil, shareValidationScratch)

	if validation.status == TransferEnums.UnitValidationOutcome.Failure then
		---@type UnitTransferResult
		return {
			success = false,
			outcome = validation.status,
			senderTeamId = senderTeamID,
			receiverTeamId = targetTeamID,
			validationResult = validation,
			policyResult = policyResult,
		}
	end

	local transferCtx = contextFactory.unitTransfer(senderTeamID, targetTeamID, unitIDs, true, policyResult, validation)
	local result = UnitTransfer.UnitTransfer(transferCtx)

	local outcome = result.outcome
	if
		outcome == TransferEnums.UnitValidationOutcome.Success
		or outcome == TransferEnums.UnitValidationOutcome.PartialSuccess
	then
		for _, unitID in ipairs(validation.validUnitIds) do
			applyStun(unitID, springRepo.GetUnitDefID(unitID), policyResult)
		end
		Spring.SendLuaUIMsg("unit_transfer:success:" .. senderTeamID, "")
	else
		Spring.SendLuaUIMsg("unit_transfer:failed:" .. senderTeamID, "")
	end

	return result
end

---@param unitID integer
---@param unitDefID integer
---@param fromTeamID integer
---@param toTeamID integer
---@param capture boolean
---@return boolean
function UnitTransferController.AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	-- The engine hook is an adapter: the module's API owns the answer, so a
	-- unit the engine offers to move and a unit a player offers to share are
	-- judged by the same code.
	return TransferApi.MayTransfer(unitID, fromTeamID, toTeamID, capture)
end

---@param srcTeamID integer
---@param dstTeamID integer
function UnitTransferController.TeamShare(srcTeamID, dstTeamID)
	local units = springRepo.GetTeamUnits(srcTeamID) or {}
	for _, unitID in ipairs(units) do
		springRepo.TransferUnit(unitID, dstTeamID, true)
	end
end

function gadget:Initialize()
	local teams = springRepo.GetTeamList() or {}
	for _, teamId in ipairs(teams) do
		InitializeNewTeam(teamId)
	end
	lastPolicyCacheUpdate = springRepo.GetGameFrame()

	if Spring.SetUnitTransferController then
		---@type GameUnitTransferController
		local controller = {
			AllowUnitTransfer = UnitTransferController.AllowUnitTransfer,
			TeamShare = UnitTransferController.TeamShare,
		}
		Spring.SetUnitTransferController(controller)
	else
		Spring.Echo(
			"[UnitTransferController] WARNING: Spring.SetUnitTransferController not available - using gadget callins"
		)
	end
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	return UnitTransferController.AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
end

function gadget:TeamShare(srcTeamID, dstTeamID)
	UnitTransferController.TeamShare(srcTeamID --[[@as integer]], dstTeamID --[[@as integer]])
end

function gadget:RecvLuaMsg(msg, playerID)
	local params = LuaRulesMsg.ParseUnitTransfer(msg)
	if params then
		local _, _, _, senderTeamID = springRepo.GetPlayerInfo(playerID, false)
		if senderTeamID then
			-- Through the module's own action, so a player dragging units onto
			-- an ally takes the same path as a mission handing them over.
			TransferApi.Units(params.unitIDs, params.targetTeamID, senderTeamID)
		end
		return true
	end
	return false
end

function gadget:GameFrame(frame)
	UpdatePolicyCache(frame)
end
