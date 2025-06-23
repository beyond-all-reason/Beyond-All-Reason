if Spring.GetModOptions().allowpausegameplay or Spring.Utilities.Gametype.IsSinglePlayer() then
	return
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name 	= "Paused is paused",
		desc	= "Prevent commands being queued while paused",
		author	= "Floris",
		date	= "May 2023",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled = true,
	}
end

local paused = false

function gadget:GamePaused(playerID, isPaused)
	paused = isPaused
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if paused and not Spring.IsCheatingEnabled() then
		return false
	else
		return true
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.ANY)
end
