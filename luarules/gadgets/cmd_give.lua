local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Give Command",
		desc = "Give units (only availible to a select few playernames in testhost only)",
		author = "Floris",
		date = "June 2017",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

-- usage: /luarules give 1 armcom 0

local cmdname = "give"
local PACKET_HEADER = "$g$"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)

local isSilentUnitGift = {}
for udefID, def in ipairs(UnitDefs) do
	if def.modCategories.object or def.customParams.objectify then
		isSilentUnitGift[udefID] = true
	end
end

local givenSomethingAtFrame = -1 -- used to fix double spawns when multiple authorized users are present

if gadgetHandler:IsSyncedCode() then
	local startPlayers = {}
	local function checkStartPlayers()
		for _, playerID in ipairs(SpringShared.GetPlayerList()) do -- update player infos
			local playername, _, spec = SpringShared.GetPlayerInfo(playerID, false)
			if not spec then
				startPlayers[playername] = true
			end
		end
	end
	function gadget:Initialize()
		checkStartPlayers()
	end
	function gadget:GameStart()
		checkStartPlayers()
	end

	local function giveunits(amount, unitName, teamID, x, z, playerID, xp)
		if not SpringShared.GetTeamInfo(teamID, false) then
			SpringUnsynced.SendMessageToPlayer(playerID, "TeamID '" .. teamID .. "' isn't valid")
			return
		end
		-- give resources
		if unitName == "metal" or unitName == "energy" then
			-- Give resources instead of units
			SpringSynced.AddTeamResource(teamID, unitName, amount)
			SpringUnsynced.SendMessageToTeam(teamID, "You have been given: " .. amount .. " " .. unitName)
			SpringUnsynced.SendMessageToPlayer(playerID, "You have given team " .. teamID .. ": " .. amount .. " " .. unitName)
			return
		end
		-- give units
		local unitDefID
		for udid, unitDef in pairs(UnitDefs) do
			if unitDef.name == unitName then
				unitDefID = udid
				break
			end
		end
		if unitDefID == nil then
			SpringUnsynced.SendMessageToPlayer(playerID, "Unitname '" .. unitName .. "' isnt valid")
			return
		end
		local succesfullyCreated = 0
		for i = 1, amount do
			local unitID = SpringSynced.CreateUnit(unitDefID, x, SpringShared.GetGroundHeight(x, z), z, 0, teamID)
			if unitID ~= nil then
				succesfullyCreated = succesfullyCreated + 1
				if xp and type(xp) == "number" then
					SpringSynced.SetUnitExperience(unitID, xp)
				end
			end
		end
		if succesfullyCreated > 0 then
			if isSilentUnitGift[unitDefID] == nil then
				SpringUnsynced.SendMessageToTeam(teamID, "You have been given: " .. succesfullyCreated .. " " .. unitName)
			end
			SpringUnsynced.SendMessageToPlayer(playerID, "You have given team " .. teamID .. ": " .. succesfullyCreated .. " " .. unitName)
		end
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
			return
		elseif givenSomethingAtFrame == SpringShared.GetGameFrame() then
			return
		end

		local playername, _, spec = SpringShared.GetPlayerInfo(playerID)
		local accountID = Utilities.GetAccountID(playerID)
		local authorized = false
		if _G.permissions.give[accountID] then
			authorized = true
			givenSomethingAtFrame = SpringShared.GetGameFrame()
		end
		if authorized == nil then
			SpringUnsynced.SendMessageToPlayer(playerID, "You are not authorized to give units")
			return
		elseif not spec then
			SpringUnsynced.SendMessageToPlayer(playerID, "You arent allowed to give units when playing")
			return
		elseif startPlayers[playername] ~= nil then
			SpringUnsynced.SendMessageToPlayer(playerID, "You arent allowed to give units when you have been a player")
			return
		end
		local params = string.split(msg, ":")
		giveunits(tonumber(params[2]), params[3], tonumber(params[4]), tonumber(params[5]), tonumber(params[6]), playerID, (params[7] and tonumber(params[7]) or nil))
		return true
	end
else -- UNSYNCED
	local myPlayerID = SpringUnsynced.GetLocalPlayerID()
	local accountID = Utilities.GetAccountID(myPlayerID)
	local authorized = SYNCED.permissions.give[accountID]

	local function RequestGive(cmd, line, words, playerID)
		if authorized and playerID == myPlayerID then
			local mx, my = SpringUnsynced.GetMouseState()
			local targettype, pos = SpringUnsynced.TraceScreenRay(mx, my)
			if targettype == "unit" then
				pos = { SpringShared.GetUnitPosition(pos) }
			elseif targettype == "feature" then
				pos = { SpringShared.GetFeaturePosition(pos) }
			end
			if type(pos) == "table" and pos[1] ~= nil and pos[3] ~= nil and pos[1] > 0 and pos[3] > 0 and words[1] ~= nil and words[2] ~= nil and words[3] ~= nil then
				SpringUnsynced.SendLuaRulesMsg(PACKET_HEADER .. ":" .. words[1] .. ":" .. words[2] .. ":" .. words[3] .. ":" .. pos[1] .. ":" .. pos[3] .. (words[4] ~= nil and ":" .. words[4] or ""))
			else
				SpringUnsynced.SendMessageToPlayer(playerID, "failed to give, check syntax or cursor position")
			end
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction(cmdname, RequestGive)
	end
	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction(cmdname)
	end
end
