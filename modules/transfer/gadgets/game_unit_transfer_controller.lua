---@class TransferUnitController
---@field AllowUnitTransfer fun(unitID: integer, unitDefID: integer, fromTeamID: integer, toTeamID: integer, capture: boolean): boolean
---@field TeamShare fun(srcTeamID: integer, dstTeamID: integer)

---@class UnitTransferGadget : Gadget
---@field TeamShare fun(self, srcTeamID: number, dstTeamID: number)
local gadget = gadget ---@type UnitTransferGadget

function gadget:GetInfo()
	return {
		name = "Unit Transfer Controller",
		desc = "Routes unit share requests to the transfer actions; AllowUnitTransfer asks the policy",
		author = "Rimilel, Attean, Antigravity",
		date = "April 2024",
		license = "GNU GPL, v2 or later",
		layer = -200,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local LuaRulesMsg = require("modules/transfer/lib/lua_rules_msg")
local TransferApi = require("modules/transfer/api")
local UnitTransfer = require("modules/transfer/api_synced").Units

local springRepo = Spring --[[@as SpringSynced]]

local UnitTransferController = {}

---@param unitID integer
---@param unitDefID integer
---@param fromTeamID integer
---@param toTeamID integer
---@param capture boolean
---@return boolean
function UnitTransferController.AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
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
	if Spring.SetUnitTransferController then
		---@type TransferUnitController
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

---@return boolean handled
function gadget:RecvLuaMsg(msg, playerID)
	local params = LuaRulesMsg.ParseUnitTransfer(msg)
	if params then
		local _, _, _, senderTeamID = springRepo.GetPlayerInfo(playerID, false)
		---@cast senderTeamID integer?
		if senderTeamID then
			UnitTransfer.Share(params.unitIDs, params.targetTeamID, senderTeamID)
		end
		return true
	end
	return false
end
