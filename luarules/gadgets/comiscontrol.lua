function gadget:GetInfo()
	return {
		name = "C Is For Control",
		desc = "A player without commanders is no longer in control",
		author = "KDR_11k (David Becker)",
		date = "2008-06-28",
		license = "Public domain",
		layer = 1,
		enabled = true
	}
end

local takeDelay=5 --time in seconds before a .luarules take can be performed after a player is takeable


if (gadgetHandler:IsSyncedCode()) then

--SYNCED

local aliveCount = {}

local isAlive = {}

local transferList={}

local takeDelays={}

local GetTeamList=Spring.GetTeamList
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local DestroyUnit=Spring.DestroyUnit
local AreTeamsAllied=Spring.AreTeamsAllied
local GetTeamInfo=Spring.GetTeamInfo
local GetPlayerInfo=Spring.GetPlayerInfo
local TransferUnit=Spring.TransferUnit
local GetGameFrame=Spring.GetGameFrame

function gadget:UnitCreated(u, ud, team)
	isAlive[u] = true
	if UnitDefs[ud].customParams.iscommander then
		--Spring.Echo("Created",team)
		aliveCount[team] = aliveCount[team] + 1
	end
end

function gadget:UnitGiven(u, ud, team)
	if UnitDefs[ud].customParams.iscommander then
		--Spring.Echo("Given",team)
		aliveCount[team] = aliveCount[team] + 1
	end
end

local function TeamTakeable(team)
	local _,_,_,_,_,allyTeam=GetTeamInfo(team)
	SendToUnsynced("teamWithoutCom",team,allyTeam)
	takeDelays[team]=GetGameFrame()+takeDelay*30
end

function gadget:UnitDestroyed(u, ud, team)
	isAlive[u] = nil
	if UnitDefs[ud].customParams.iscommander then
		--Spring.Echo("Destroyed",team)
		aliveCount[team] = aliveCount[team] - 1
		if aliveCount[team]<= 0 then
			TeamTakeable(team)
		end
	end
end

function gadget:UnitTaken(u, ud, team)
	if isAlive[u] and UnitDefs[ud].customParams.iscommander then
		--Spring.Echo("Taken",team)
		aliveCount[team] = aliveCount[team] - 1
		if aliveCount[team]<= 0 then
			TeamTakeable(team)
		end
	end
end

function gadget:AllowCommand(u, ud, team, cmd, param, opt)
	if aliveCount[team] > 0 then
		return true
	else
		return false
	end
end

function gadget:AllowUnitTransfer(u, ud, fromTeam, toTeam, capture)
	if not capture and aliveCount[fromTeam]<=0 then
		return AreTeamsAllied(fromTeam, toTeam)
	end
	return true
end

local function wantToTake(cmd,msg,words,player)
	local _,_,spec,playerTeam,allyTeam=GetPlayerInfo(player)
	if spec then
		return false
	end
	for _,t in ipairs(GetTeamList(allyTeam)) do
		if aliveCount[t] <= 0 then
			if takeDelays[t] and takeDelays[t] > GetGameFrame() then
				SendToUnsynced("takeFailed",t,allyTeam)
			else
				table.insert(transferList,{from=t, to=playerTeam})
			end
		end
	end
	return true
end

function gadget:GameFrame(f)
	for i,d in pairs(transferList) do
		for _,u in ipairs(GetTeamUnits(d.from)) do
			TransferUnit(u,d.to,false)
		end
		transferList[i]=nil
	end
end

function gadget:Initialize()
	if Spring.GetModOptions().deathmode~="comcontrol" then
		gadgetHandler:RemoveGadget()
	end
	for _,t in ipairs(GetTeamList()) do
		aliveCount[t] = 0
	end
	_G.playerCommsAlive=aliveCount
	gadgetHandler:AddChatAction("take",wantToTake,"Takes unused units")
end

else

--UNSYNCED

local GetSpectatingState=Spring.GetSpectatingState
local GetLocalTeamID=Spring.GetLocalTeamID
local Text=gl.Text
local GetGameFrame=Spring.GetGameFrame
local GetPlayerList=Spring.GetPlayerList
local GetPlayerInfo=Spring.GetPlayerInfo
local SendMessageToAllyTeam=Spring.SendMessageToAllyTeam

function gadget:DrawScreen(vsx,vsy)
	local _,_,spec=GetSpectatingState()
	--Text("Comms: "..SYNCED.playerCommsAlive[GetLocalTeamID()],vsx*.5, 200,18,"oc")
	if not spec and GetGameFrame() > 0 then
		if SYNCED.playerCommsAlive[GetLocalTeamID()] <= 0 then
			Text("You have no Commander!",vsx*.5, vsy*.6,24,"oc")
			Text("UNIT CONTROL DISABLED",vsx*.5, vsy*.5,24,"oc")
			Text("Please share your units to allies that need them",vsx*.5, vsy*.4,18,"oc")
		end
	end
end

function gadget:RecvFromSynced(event,team,allyTeam)
	if event=="teamWithoutCom" then
		local names=""
		for _,p in ipairs(GetPlayerList(team,true)) do
			local name,_,spec = GetPlayerInfo(p)
			if not spec then
				names=names..name.." "
			end
		end
		SendMessageToAllyTeam(allyTeam, "Team "..team.." ("..names..') is without a Commander. Use ".luarules take" to take their units or share them a Commander.')
		return true
	elseif event=="takeFailed" then
		SendMessageToAllyTeam(allyTeam, "Failed to take Team "..team..", taking is only possible "..takeDelay.." seconds after the commander died")
	end
	return false
end

function gadget:Initialize()
	if Spring.GetModOptions().deathmode~="comcontrol" then
		gadgetHandler:RemoveGadget()
	end
end

end
