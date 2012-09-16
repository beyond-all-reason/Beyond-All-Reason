function gadget:GetInfo()
	return {
		name = "Take Manager",
		desc = "Handles players AFK and drops",
		author = "BD",
		date = "2012",
		license = "WTFPL",
		layer = 1,
		enabled = true
	}
end

if ( not gadgetHandler:IsSyncedCode()) then
-- UNSYNCED code
	local maxIdleTreshold = 150*30 -- in frames (30 game frames per sec)

	local GetGameFrame = Spring.GetGameFrame
	local SendLuaRulesMsg = Spring.SendLuaRulesMsg
	local GetMouseState = Spring.GetMouseState

	local lastGameFrame = nil -- start with nil so first frame ( 0 ) is not skipped
	local lastActionFrame = 0
	local IsIdle = false

	local mx,my = GetMouseState()

	function WentIdle()
		if not IsIdle then
			IsIdle = true
			SendLuaRulesMsg("idleplayers 1" )
		end
	end

	function NotIdle()
		lastActionFrame = GetGameFrame()
		if IsIdle then
			SendLuaRulesMsg("idleplayers 0")
			IsIdle = false
		end
	end

	-- apparently gadget:GameFrame doesn't get called in unsynced context??!
	function gadget:DrawScreen()
		local gameFrame = GetGameFrame()
		if lastGameFrame == gameFrame then -- only once per gameFrame
			return
		end
		lastGameFrame = gameFrame
		if gameFrame%16 == 0 then
			return
		end

		-- ugly code to check if the mouse moved since the call-in doesn't work
		local x,y = GetMouseState()
		if ( (mx ~= x) or (my ~= y) ) then
			NotIdle()
		end
		my = y
		mx = x

		if gameFrame-lastActionFrame > maxIdleTreshold then
			WentIdle()
		end
	end

	-- MouseMove isn't called either??!
	function gadget:MouseMove()
		NotIdle()
	end

	function gadget:MousePress()
		NotIdle()
	end

	function gadget:MouseWheel()
		NotIdle()
	end

	function gadget:KeyPress()
		NotIdle()
	end

else

-- SYNCED code

	-- "autoshare" to use resource autoshare to all team, "takeall" to use AllowResourceTransfer
	local blockResourceTransferMode = Spring.GetModOptions().restakemode or "autoshare"

	local maxPing = 30000 -- in milliseconds

	local playerInfoTable = {}
	local TeamToRemainingPlayers = {}
	local playerList = {}
	local shareBarLevelMetal = {}
	local shareBarLevelEnergy = {}

	local AFKRegex = 'idleplayers (%d+)$'

	local TransferUnit = Spring.TransferUnit
	local GetPlayerList = Spring.GetPlayerList
	local ShareTeamResource = Spring.ShareTeamResource
	local GetTeamResources = Spring.GetTeamResources
	local GetPlayerInfo = Spring.GetPlayerInfo
	local GetTeamList = Spring.GetTeamList
	local SetTeamRulesParam = Spring.SetTeamRulesParam
	local GetTeamRulesParam = Spring.GetTeamRulesParam
	local GetTeamUnits = Spring.GetTeamUnits
	local SetTeamShareLevel = Spring.SetTeamShareLevel
	local GetTeamInfo = Spring.GetTeamInfo
	local GetTeamList = Spring.GetTeamList

	local function CheckPlayerState(playerID)
		local newval = playerInfoTable[playerID]
		if not newval then
			return false
		end
		local ok = true
		ok = ok and newval.connected
		ok = ok and newval.player
		ok = ok and newval.pingOK
		ok = ok and newval.present
		return ok
	end

	function gadget:PlayerChanged()
		playerList = GetPlayerList()
		UpdatePlayerInfos()
	end

	local function UpdatePlayerInfos()
		local inactiveTeamCopy = TeamToRemainingPlayers
		TeamToRemainingPlayers = {} -- reset active teams table
		local teamList = GetTeamList()
		for _,teamID in ipairs(teamList) do -- sum all AI first
			local _, _, _, isAI = GetTeamInfo(teamID)
			if isAI then
				TeamToRemainingPlayers[teamID] = 1
			else
				TeamToRemainingPlayers[teamID] = 0
			end
		end
		for _,playerID in ipairs(playerList) do -- update player infos
			local _,active,spectator,teamID,allyTeamID,ping = GetPlayerInfo(playerID)
			local playerInfoTableEntry = playerInfoTable[playerID]
			if not playerInfoTableEntry then
				playerInfoTableEntry = {}
			end
			playerInfoTableEntry.connected = active
			playerInfoTableEntry.player = not spectator
			playerInfoTableEntry.pingOK = ping < maxPing
			if playerInfoTableEntry.present == nil then
				playerInfoTableEntry.present = true -- initialize to not afk
			end
			playerInfoTable[playerID] = playerInfoTableEntry

			local ok = CheckPlayerState(playerID)

			local teamplayersok = TeamToRemainingPlayers[teamID]
			if ok then -- bump amount of active players in a team
				teamplayersok = teamplayersok + 1
			end
			TeamToRemainingPlayers[teamID] = teamplayersok
		end

		for teamID,teamCount in ipairs(TeamToRemainingPlayers) do
			-- set to a public readble value that there's nobody controlling the team
			SetTeamRulesParam(teamID, "numActivePlayers", teamCount )
		end

		if blockResourceTransferMode == "autoshare" then
			for teamID,oldcount in ipairs(inactiveTeamCopy) do
				newcount = TeamToRemainingPlayers[teamID]
				if ( oldcount == nil or oldcount == 0 ) and ( newcount ~= nil and newcount ~= 0 ) then
					-- team become active again, un-set share slider
					if shareBarLevelMetal[teamID] then
						SetTeamShareLevel(teamID,"metal",shareBarLevelMetal[teamID])
						shareBarLevelMetal[teamID] = nil
					end
					if shareBarLevelEnergy[teamID] then
						SetTeamShareLevel(teamID,"energy",shareBarLevelEnergy[teamID])
						shareBarLevelEnergy[teamID] = nil
					end
				end
			end
		end
	end

	function gadget:Initialize()
		playerList = GetPlayerList()
  		gadgetHandler:AddChatAction("take2", TakeTeam, "Take control of units and resouces from inactive players")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction('take2')
	end

	function gadget:GameStart()
		UpdatePlayerInfos()
	end

	function gadget:GameFrame(currentFrame)
		if currentFrame%16 == 0 then
			return
		end
		UpdatePlayerInfos()
	end

	function gadget:RecvLuaMsg(msg, playerID)
		local afk = tonumber(msg:match(AFKRegex))
		if not afk then --invalid message
			return
		end
		local playerInfoTableEntry = playerInfoTable[playerID]
		if not playerInfoTableEntry then
			playerInfoTableEntry = {}
		end
		playerInfoTableEntry.present = afk == 0
		playerInfoTable[playerID] = playerInfoTableEntry
	end

	function gadget:AllowResourceTransfer(teamID, restype, level)
		if blockResourceTransferMode ~= "takeall" then
			return true
		end
		-- prevent resources to leak to uncontrolled teams
		return GetTeamRulesParam(teamID,"numActivePlayers") ~= 0
	end


	function TakeTeam(cmd, line, words, playerID)
		if not CheckPlayerState(playerID) then
			return -- exclude taking rights from lagged players, etc
		end
		local _,_,_,takerID,allyTeamID = GetPlayerInfo(playerID)
		local teamList = GetTeamList(allyTeamID)
		for teamID in ipairs(teamList) do
			if GetTeamRulesParam(teamID,"numActivePlayers") == 0 then
				-- transfer all units
				local unitList = GetTeamUnits(teamID)
				for _,unitID in ipairs(unitList) do
					TransferUnit(unitID,takerID)
				end
				if blockResourceTransferMode == "autoshare" then
					-- set share bars to 0 and save old value
					_,_,_,_,_,shareBarLevelMetal[teamID] = GetTeamResources(teamID, "metal")
					_,_,_,_,_,shareBarLevelEnergy[teamID] = GetTeamResources(teamID, "energy")
					SetTeamShareLevel(teamID,"metal",0)
					SetTeamShareLevel(teamID,"energy",0)
				elseif blockResourceTransferMode == "takeall" then
					--send all resources en-block to the taker
					local shareAmount = GetTeamResources( teamID, "metal" )
					ShareTeamResource( teamID, takerID, "metal", shareAmount )
					shareAmount = GetTeamResources( teamID, "energy" )
					ShareTeamResource( teamID, takerID, "energy", shareAmount )
				end
			end
		end
	end
end
