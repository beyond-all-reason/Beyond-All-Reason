---@diagnostic disable: param-type-mismatch
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Transport To (Gadget)",
		desc = "Synced support for the Transport To command",
		author = "Silla Noble, Isajoefeat",
		license = "GNU GPL v2 or later",
		layer = 1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

--------------------------------------------------------------------------------
-- Overview
--
-- This gadget is the synced counterpart to the Transport To widget.
-- Responsibilities:
--   * validates that Transport To can only be issued by transportable units
--   * marks the command complete once the unit is loaded or reaches destination
--   * receives POS / TSTP LuaRules messages from the widget and applies
--     synced move-goal updates safely for the issuing player's team
--------------------------------------------------------------------------------

local ValidUnitID = Spring.ValidUnitID

local CMD_TRANSPORT_TO = GameCMD.TRANSPORT_TO
local TRANSPORT_COMMAND_COMPLETE_RADIUS = 20

local isTransportableDef = {}
local loadedUnits = {} -- [unitID] = true while carried by a transport

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function distanceSq(ax, az, bx, bz)
	local dx, dz = ax - bx, az - bz
	return dx * dx + dz * dz
end

local function buildDefCaches()
	for defID, ud in pairs(UnitDefs) do
		local grounded = not ud.canFly
		local notCantBeTransported = (ud.cantBeTransported == nil) or (ud.cantBeTransported == false)
		local isNano = ud.isBuilder and not ud.canMove and not ud.isFactory
		local isFactory = ud.isFactory

		if grounded and notCantBeTransported then
			isTransportableDef[defID] = true
		end
		if isNano then
			isTransportableDef[defID] = true
		end
		if isFactory then
			isTransportableDef[defID] = true
		end
	end
end

--------------------------------------------------------------------------------
-- Command completion
--------------------------------------------------------------------------------

function gadget:CommandFallback(unitID, _, _, cmdID, cmdParams)
	if cmdID ~= CMD_TRANSPORT_TO then
		return false
	end

	local ux, _, uz = Spring.GetUnitPosition(unitID)
	local distance = distanceSq(ux, uz, cmdParams[1], cmdParams[3])

	if loadedUnits[unitID] or distance < TRANSPORT_COMMAND_COMPLETE_RADIUS then
		loadedUnits[unitID] = nil
		return true, true
	end

	return true, false
end

function gadget:UnitLoaded(unitID)
	loadedUnits[unitID] = true
end

function gadget:UnitUnloaded(unitID)
	loadedUnits[unitID] = nil
end

--------------------------------------------------------------------------------
-- Widget -> gadget move-goal bridge
--------------------------------------------------------------------------------

function gadget:RecvLuaMsg(msg, playerID)
	local _, _, _, teamID = Spring.GetPlayerInfo(playerID)

	if msg:sub(1, 4) == "POS|" then
		local _, unitID, x, y, z = msg:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)")
		unitID = tonumber(unitID)

		if unitID and ValidUnitID(unitID) and Spring.GetUnitTeam(unitID) == teamID then
			x, y, z = tonumber(x), tonumber(y), tonumber(z)

			if x and y and z then
				Spring.SetUnitMoveGoal(unitID, x, y, z)
			end
			return true
		end
	elseif msg:sub(1, 4) == "TSTP" then
		local _, unitID = msg:match("([^|]+)|([^|]+)")
		unitID = tonumber(unitID)

		if unitID and ValidUnitID(unitID) and Spring.GetUnitTeam(unitID) == teamID then
			local x, y, z = Spring.GetUnitPosition(unitID)
			Spring.ClearUnitGoal(unitID)
			Spring.SetUnitMoveGoal(unitID, x, y, z)
			return true
		end
	end
end

--------------------------------------------------------------------------------
-- Validation
--------------------------------------------------------------------------------

function gadget:AllowCommand(_, unitDefID, _, cmdID)
	if cmdID == CMD_TRANSPORT_TO and not isTransportableDef[unitDefID] then
		return false
	end
	return true
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function gadget:Initialize()
	buildDefCaches()
end