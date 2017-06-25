
function gadget:GetInfo()
	return {
		name    = "Give Command",
		desc	= 'Give units (only availible to a select few playernames)',
		author	= 'Floris',
		date	= 'June 2017',
		license	= 'GNU GPL, v2 or later',
		layer	= 1,
		enabled	= true
	}
end

-- usage: /luarules give 1 armcom 0

local cmdname = 'give'


local PACKET_HEADER = "$g$"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)

if gadgetHandler:IsSyncedCode() then

	local authorizedPlayers  = {'[teh]Flow', 'FlowerPower'}

	function explode(div,str) -- credit: http://richard.warburton.it
		if (div=='') then return false end
		local pos,arr = 0,{}
		-- for each divider found
		for st,sp in function() return string.find(str,div,pos,true) end do
			table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
			pos = sp + 1 -- Jump past current divider
		end
		table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
		return arr
	end

	function giveunits(amount, unitName, teamID, x, z, playerID)
		local unitDefID
		for udid, unitDef in pairs(UnitDefs) do
			if unitDef.name == unitName then  unitDefID = udid break end
		end
		if unitDefID == nil then
			if playerID ~= nil then
				Spring.SendMessageToPlayer(playerID, "Unitname '"..unitName.."' isnt valid")
			end
		else
			local succesfullyCreated = 0
			for i=1, amount do
				local unitID = Spring.CreateUnit(unitDefID, x, Spring.GetGroundHeight(x, z), z, 0, teamID)
				if unitID ~= nil then
					succesfullyCreated = succesfullyCreated + 1
				end
			end
			if succesfullyCreated > 0 then
				Spring.SendMessageToTeam(teamID, "You have been given: "..amount.." "..unitName)
			end
		end
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
			return
		end

		local playername, _, spec = Spring.GetPlayerInfo(playerID)
		local authorized = false
		for _,name in ipairs(authorizedPlayers) do
			if playername == name then
				authorized = true
				break
			end
		end
		if authorized == nil or not spec then
			if playername ~= "UnnamedPlayer" then
				Spring.SendMessageToPlayer(playerID, "You are not authorized to give units")
				return
			end
		end
		local params = explode(':', msg)
		giveunits(params[2], params[3], params[4], params[5], params[6], playerID)
		return true
	end

else	-- UNSYNCED


	function gadget:Initialize()
		gadgetHandler:AddChatAction(cmdname, RequestGive)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction(cmdname)
	end

	function RequestGive(cmd, line, words, playerID)
		local mx,my = Spring.GetMouseState()
		local _,pos = Spring.TraceScreenRay(mx,my)

		if type(pos) == 'table' and pos[1] ~= nil and pos[3] ~= nil and pos[1] > 0 and pos[3] > 0 and words[1] ~= nil and words[2] ~= nil and words[3] ~= nil then
			Spring.SendLuaRulesMsg(PACKET_HEADER..':'..words[1]..':'..words[2]..':'..words[3]..':'..pos[1]..':'..pos[3])
		else
			Spring.SendMessageToPlayer(playerID, "failed to give, check syntax or cursor position")
		end
	end
end

