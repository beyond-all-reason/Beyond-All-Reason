
function gadget:GetInfo()
	return {
		name      = "Prevent FPS Hax",
		desc      = "Prevent FPS Hax",
		author    = "BD",
		date      = "Dec 2013",
		license   = "GNU GPL, v2 or later",
		layer     = 9001,
		enabled   = true
	}
end


if gadgetHandler:IsSyncedCode() then

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

	local GetGameFrame = Spring.GetGameFrame
	local GetTeamList = Spring.GetTeamList
	local GetPlayerList = Spring.GetPlayerList
	local GetPlayerInfo = Spring.GetPlayerInfo
	local GetPlayerControlledUnit = Spring.GetPlayerControlledUnit

	local playerControlledUnits = {}

	--those are stateful orders and therfore ok to enable ( cloak, hold fire, etc)
	local WHITELISTED_COMMAND = {
		[CMD.STOP] = true,
		[CMD.WAIT] = true,
		[CMD.GROUPADD] = true,
		[CMD.GROUPSELECT] = true,
		[CMD.GROUPCLEAR] = true,
		[CMD.FIRE_STATE] = true,
		[CMD.MOVE_STATE] = true,
		[CMD.SELFD] = true,
		[CMD.ONOFF] = true,
		[CMD.CLOAK] = true,
		[CMD.REPEAT] = true,
		[CMD.TRAJECTORY] = true,
		[CMD.AUTOREPAIRLEVEL] = true,
		[CMD.LOOPBACKATTACK] = true,
		[CMD.IDLEMODE] = true,
	}
	local checkIntervalFrame = 16

	function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
		if playerControlledUnits[unitID] then
			--we can only issue whitelisted stateful commands to the controlled unit
			--orders ( cloak, selfd, etc )
			--attack and manualfire orders in fps mode aren't processed by this call-in and are therefore automatically allowed
			return WHITELISTED_COMMAND[cmdID]
		end
		--allow rest of commands
		return true
	end

	function gadget:UnitDied(unitID)
		playerControlledUnits[unitID] = nil --to react faster to unit dieing
	end

	function gadget:UnitGiven(unitID)
		playerControlledUnits[unitID] = nil --to react faster to unit being transferred

	end

	function gadget:UnitTaken(unitID)
		playerControlledUnits[unitID] = nil --to react faster to unit being transferred

	end

	function gadget:GameFrame()
		if GetGameFrame() % checkIntervalFrame ~= 0 then
			return
		end
		playerControlledUnits = {}
		--we must refresh periodically the list of attached players to a team because people can !joinas and attach new players to teams
		--this way we can also check if players quit and remove them for sanity checks
		for _,teamID in pairs(GetTeamList()) do
			for _,playerID in pairs(GetPlayerList(teamID)) do
				local _,active,spectator = GetPlayerInfo(playerID)
				if active and not spectator then
					local unitID = GetPlayerControlledUnit(playerID)
					if unitID then
						playerControlledUnits[unitID] = true
					end
				end
			end
		end
	end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

else

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

	local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds
	local GetPlayerControlledUnit = Spring.GetPlayerControlledUnit
	local GetCameraState = Spring.GetCameraState
	local SendCommands = Spring.SendCommands

	local myPlayerID = Spring.GetMyPlayerID()
	local updateAccumulator = 0

	local checkInterval = 0.5 --in seconds
	local fpsCameraName = "fps"

	function gadget:Update()
		updateAccumulator = updateAccumulator + GetLastUpdateSeconds()
		if updateAccumulator < checkInterval then
			return
		end
		updateAccumulator = 0
		if GetPlayerControlledUnit(myPlayerID) then
			--if we're in fps mode, lock the camera type
			local cameraName = GetCameraState().name
			if cameraName ~= fpsCameraName then
				SendCommands("viewfps")
			end
		end
	end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
end
