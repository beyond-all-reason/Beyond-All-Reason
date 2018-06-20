--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "LOS hack warning",
    desc      = "Warns players when someone is using engine exploits",
    author    = "Doo",
    date      = "2018",
    license   = "GNU GPL, v2 or later",
    layer     = 5,
    enabled   = true
  }
end

local devs = {
	["[teh]Flow"] = true,
	['FlowerPower'] = true,
	['Floris'] = true,
	['[Fx]Doo'] = true,
	['[PiRO]JiZaH'] = true,
	['[PinK]triton'] = true,
	['[PinK]pta[Q___Q]'] = true,
	['UnnamedPlayer'] = true,
	}

if (gadgetHandler:IsSyncedCode()) then
		function gadget:UnitCreated(unitID, unitDefID, unitTeam)
				LastCheck = LastCheck or 0
				if LastCheck + 5400 <= Spring.GetGameFrame() then -- check once every 100 units
					SendToUnsynced("VisibilityUnsyncedCheck", tostring(unitID), tostring(unitTeam))
					LastCheck = Spring.GetGameFrame()
				end
		end
		
		function gadget:GameFrame(f)
			if f%9000 == 0 then -- check once every 5 minutes
				SendToUnsynced("CasualFullViewCheck")
			end
		end
		
		function gadget:GotChatMsg(msg, player)
			if string.find(msg, "imacheat")then
				local name = Spring.GetPlayerInfo(player)
				SendToWidget("Player "..(name).." is using SpecFullView despite not being a spectator!")
			end
			if string.find(msg, "loshackprevent;") then
			local data = string.sub(msg, string.find(msg, "loshackprevent;") + 15)
			if string.find(data, ";") then
				sunitID = string.sub(data, 0, string.find(data, ";")-1)
				data = string.sub(data, string.find(data, ";")+1)
				if string.find(data, ";") then
					sunitTeam = string.sub(data,0, string.find(data, ";")-1)
					data = string.sub(data, string.find(data, ";")+1)
					stestedTeam = data
				end
			end
			end
			if sunitID and sunitTeam and stestedTeam and tonumber(sunitID) and tonumber(sunitTeam) and tonumber(stestedTeam) then
				unitID, unitTeam, testedTeam = tonumber(sunitID), tonumber(sunitTeam), tonumber(stestedTeam)
				TestSyncedVisibility(unitID, unitTeam, testedTeam, player)
			end
		end
		
		function TestSyncedVisibility(unitID, unitTeam, testedTeam, player)
			if Spring.ValidUnitID(unitID) then
				local _,_,_,_,_,allyTeamID = Spring.GetTeamInfo(testedTeam)
				local playername = Spring.GetPlayerInfo(player)
				local LOS = tostring(Spring.IsUnitInLos(unitID, allyTeamID))
				local AIRLOS = tostring(Spring.IsUnitInAirLos(unitID, allyTeamID))
				local RADAR = tostring(Spring.IsUnitInRadar(unitID, allyTeamID))
				if LOS == "false" and AIRLOS == "false" and RADAR == "false" then
					SendToWidget(unitID.." from "..unitTeam.." is seen by player "..playername..". Its los state is: "..LOS..", "..AIRLOS..", "..RADAR..".")
				end
			end
		end

		function SendToWidget(msg)
			SendToUnsynced("SendToWG", msg)

		end
			
else
		function gadget:Initialize()
			gadgetHandler:AddSyncAction("VisibilityUnsyncedCheck",VisibilityUnsyncedCheck)
			gadgetHandler:AddSyncAction("CasualFullViewCheck", CasualFullViewCheck)
			gadgetHandler:AddSyncAction("SendToWG", SendToWG)
		end
		
		function gadget:GotChatMsg(msg, player)
			local playername = Spring.GetPlayerInfo(player)
			if not devs[playername] then
				return
			end
			if msg == "echocheatlog 1" then
				echocheatlog = true
			elseif msg == "echocheatlog 0" then
				echocheatlog = false
			end
		end
		
		function SendToWG(_,msg)
			local myplayername = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
			if Script.LuaUI("HackBroadcast") then
				Script.LuaUI.HackBroadcast(msg)
			end
			if echocheatlog == true and devs[myplayername] then
				Spring.Echo(msg)
			end
		end
		
		function CasualFullViewCheck()
			local spec,full, fullselect = Spring.GetSpectatingState()
			if full and not spec then
				Spring.SendCommands("luarules imacheat")
			end
		end
		
		function VisibilityUnsyncedCheck(_, sunitID, sunitTeam)
			if Spring.GetSpectatingState() == true then
			else
				local unitID = tonumber(sunitID)
				local unitTeam = tonumber(sunitTeam)
				if Spring.IsUnitVisible(unitID) == true and not (unitTeam == Spring.GetMyTeamID()) then
					Spring.SendCommands("luarules loshackprevent;"..sunitID..";"..sunitTeam..";"..(tostring(Spring.GetMyTeamID())))
				end
			end
		end					
end