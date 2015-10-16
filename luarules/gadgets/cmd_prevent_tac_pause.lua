
function gadget:GetInfo()
	return {
		name = "No Tactical Pause",
		desc = "Blocks sending orders and chat when paused",
		date = "-",
		license = "WTFPL",
		layer = -math.huge,
		enabled = true
	}
end

local GetGameSpeed = Spring.GetGameSpeed
local IsCheatingEnabled = Spring.IsCheatingEnabled
local GetPlayerInfo = Spring.GetPlayerInfo

if gadgetHandler:IsSyncedCode() then

	--allow internal commands or commands when game is not paused or cheats are on
	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
		return synced or IsCheatingEnabled() or not select(3,GetGameSpeed())
	end

else
	--block map marks and drawings from non spectators when game is paused and cheats are off
	function gadget:MapDrawCmd(playerID, cmdType, startx, starty, startz, a, b, c)
		return IsCheatingEnabled() or not select(3,GetGameSpeed()) or select(3,GetPlayerInfo(playerID))
	end

	--ideally we should block ally chat and whispers of non-spectators too

end