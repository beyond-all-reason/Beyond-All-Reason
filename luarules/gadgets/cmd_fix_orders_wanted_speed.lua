-- Based from Zero-K: https://github.com/ZeroK-RTS/Zero-K/blob/a4deb57/LuaRules/Gadgets/unit_wanted_speed.lua
-- Authored by GoogleFrog
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- IMPORTANT -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- This gadget operates on the assumption units and unitdefs dont change max ---
-- speed neither movetype over a game.                                       ---
--                                                                           ---
-- Before implementing any kind of feature that changes these parameters     ---
-- dynamically this gadget must be modified to get the unit movetype speed   ---
-- correspondingly.                                                          ---
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Fix Wanted Speed",
		desc      = "Reset max wanted speed for orders given via Lua. Avoids persisted wanted speed states from hardcoded engine behavior.",
		author    = "badosu, adapted from 'Wanted Speed' by GoogleFrog",
		date      = "31 March 2023",
		license   = "GNU GPL, v2 or later",
		layer     = -9999999999, -- Before every state toggle gadget.
		enabled   = true,
	}
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local CMD_MOVE = CMD.MOVE
local SetGroundMoveTypeData = Spring.MoveCtrl.SetGroundMoveTypeData
local SetGunshipMoveTypeData = Spring.MoveCtrl.SetGunshipMoveTypeData

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local speedParamsByDefID = {}
do
	for i = 1, #UnitDefs do
		local uDef = UnitDefs[i]

		if not uDef.isImmobile then
			-- for air units only gunships are affected by engine hardcoded group speed commands
			-- ground/sea units are affected
			if uDef.isHoveringAirUnit or (not uDef.canFly and not uDef.isAirUnit) then
				local speed = uDef.speed

				if speed and speed > 0 then
					local funcIdx = uDef.isHoveringAirUnit and 2 or 1
					speedParamsByDefID[i] = { UnitDefs[i].speed, funcIdx }
				end
			end
		end
	end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Command Handling

function gadget:AllowCommand(unitID, unitDefID, _, cmdID, _, _, _, _, fromLua)
	-- Only operate on move commands issued by Lua
	if cmdID ~= CMD_MOVE or not fromLua then
		return true
	end

	local speedParams = speedParamsByDefID[unitDefID]

	if not speedParams then
		Spring.Echo('<Fix Wanted Speed> Speed Params not found for UnitDefID ', unitDefID)
		return true
	end

	if speedParams[2] == 2 then
		SetGunshipMoveTypeData(unitID, "maxWantedSpeed", speedParams[1])
	else
		SetGroundMoveTypeData(unitID, "maxWantedSpeed", speedParams[1])
	end

	return true
end
