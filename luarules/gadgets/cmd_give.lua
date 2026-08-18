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
--        /luarules give 1 Armada Commander 0

local cmdname = "give"
local PACKET_HEADER = "$g$"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)
local PH_B1 = string.byte(PACKET_HEADER, 1)

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
		for _, playerID in ipairs(Spring.GetPlayerList()) do -- update player infos
			local playername, _, spec = Spring.GetPlayerInfo(playerID, false)
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
		if not Spring.GetTeamInfo(teamID, false) then
			Spring.SendMessageToPlayer(playerID, "TeamID '" .. teamID .. "' isn't valid")
			return
		end
		-- give resources
		if unitName == "metal" or unitName == "energy" then
			-- Give resources instead of units
			Spring.AddTeamResource(teamID, unitName, amount)
			Spring.SendMessageToTeam(teamID, "You have been given: " .. amount .. " " .. unitName)
			Spring.SendMessageToPlayer(playerID, "You have given team " .. teamID .. ": " .. amount .. " " .. unitName)
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
			Spring.SendMessageToPlayer(playerID, "Unitname '" .. unitName .. "' isnt valid")
			return
		end
		local succesfullyCreated = 0
		for i = 1, amount do
			local unitID = Spring.CreateUnit(unitDefID, x, Spring.GetGroundHeight(x, z), z, 0, teamID)
			if unitID ~= nil then
				succesfullyCreated = succesfullyCreated + 1
				if xp and type(xp) == "number" then
					Spring.SetUnitExperience(unitID, xp)
				end
			end
		end
		if succesfullyCreated > 0 then
			if isSilentUnitGift[unitDefID] == nil then
				Spring.SendMessageToTeam(teamID, "You have been given: " .. succesfullyCreated .. " " .. unitName)
			end
			Spring.SendMessageToPlayer(
				playerID,
				"You have given team " .. teamID .. ": " .. succesfullyCreated .. " " .. unitName
			)
		end
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if
			#msg < PACKET_HEADER_LENGTH
			or string.byte(msg, 1) ~= PH_B1
			or string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER
		then
			return
		elseif givenSomethingAtFrame == Spring.GetGameFrame() then
			return
		end

		local playername, _, spec = Spring.GetPlayerInfo(playerID)
		local accountID = BAR.Utilities.GetAccountID(playerID)
		local authorized = false
		if _G.permissions.give[accountID] then
			authorized = true
			givenSomethingAtFrame = Spring.GetGameFrame()
		end
		if not authorized then
			Spring.SendMessageToPlayer(playerID, "You are not authorized to give units")
			return
		elseif not spec then
			Spring.SendMessageToPlayer(playerID, "You arent allowed to give units when playing")
			return
		elseif startPlayers[playername] ~= nil then
			Spring.SendMessageToPlayer(playerID, "You arent allowed to give units when you have been a player")
			return
		end
		local params = string.split(msg, ":")
		giveunits(
			tonumber(params[2]),
			params[3],
			tonumber(params[4]),
			tonumber(params[5]),
			tonumber(params[6]),
			playerID,
			(params[7] and tonumber(params[7]) or nil)
		)
		return true
	end
else -- UNSYNCED
	local myPlayerID = Spring.GetLocalPlayerID()
	local myPlayerName = Spring.GetPlayerInfo(myPlayerID)
	local function isAuthorized()
		local acID = BAR.Utilities.GetAccountID(myPlayerID)
		local perms = SYNCED.permissions.give
		return perms and (perms[acID] or (myPlayerName and perms[myPlayerName]))
	end

	local isResourceName = { metal = true, energy = true }

	-- unitdefs carry no humanName, so proper names live only in the i18n data.
	-- They are per-language, which is why this resolves here and sends the unitdef
	-- name onwards, instead of letting synced code do it and disagree per client.
	local unitDefNameByProperName = {}
	do
		local unitNames = Json.decode(VFS.LoadFile("language/en/units.json")).units.names
		for unitDefName, properName in pairs(unitNames) do
			if UnitDefNames[unitDefName] then
				local key = string.lower(properName)
				local claimed = unitDefNameByProperName[key]
				if claimed == nil then
					unitDefNameByProperName[key] = unitDefName
				elseif type(claimed) == "string" then
					unitDefNameByProperName[key] = { claimed, unitDefName }
				else
					claimed[#claimed + 1] = unitDefName
				end
			end
		end
	end

	-- returns the unitdef name, or nil plus every unitdef sharing that proper name
	local function resolveUnitName(name)
		if UnitDefNames[name] then
			return name
		end
		local claimed = unitDefNameByProperName[string.lower(name)]
		if type(claimed) == "string" then
			return claimed
		end
		return nil, claimed
	end

	-- A proper name can hold spaces, and "Armada Commander Level 2" even ends in a
	-- digit, so the name cannot be found by counting trailing numbers. It ends one
	-- or two words from the end; only one of those splits resolves to a unit.
	local function parseGive(words)
		if tonumber(words[1]) == nil then
			return nil
		end
		for last = #words - 1, math.max(#words - 2, 2), -1 do
			local teamID = tonumber(words[last + 1])
			local xp = words[last + 2] and tonumber(words[last + 2])
			if teamID and (words[last + 2] == nil or xp) then
				local name = table.concat(words, " ", 2, last)
				if isResourceName[string.lower(name)] then
					return string.lower(name), teamID, xp
				end
				local unitDefName, sharedBy = resolveUnitName(name)
				if unitDefName then
					return unitDefName, teamID, xp
				elseif sharedBy then
					return nil, nil, nil, name, sharedBy
				end
			end
		end
		return nil
	end

	local function RequestGive(cmd, line, words, playerID)
		if isAuthorized() and playerID == myPlayerID then
			local mx, my = Spring.GetMouseState()
			local targettype, pos = Spring.TraceScreenRay(mx, my)
			if targettype == "unit" then
				pos = { Spring.GetUnitPosition(pos) }
			elseif targettype == "feature" then
				pos = { Spring.GetFeaturePosition(pos) }
			end
			local unitDefName, teamID, xp, sharedName, sharedBy = parseGive(words)
			if sharedName then
				Spring.SendMessageToPlayer(
					playerID,
					"'" .. sharedName .. "' is the name of " .. #sharedBy .. " units, give one of: " .. table.concat(
						sharedBy,
						", "
					)
				)
			elseif
				type(pos) == "table"
				and pos[1] ~= nil
				and pos[3] ~= nil
				and pos[1] > 0
				and pos[3] > 0
				and unitDefName ~= nil
			then
				Spring.SendLuaRulesMsg(
					PACKET_HEADER
						.. ":"
						.. words[1]
						.. ":"
						.. unitDefName
						.. ":"
						.. teamID
						.. ":"
						.. pos[1]
						.. ":"
						.. pos[3]
						.. (xp ~= nil and ":" .. xp or "")
				)
			else
				Spring.SendMessageToPlayer(playerID, "failed to give, check syntax or cursor position")
			end
		end
	end

	function gadget:Initialize()
		if isAuthorized() then
			gadgetHandler:AddChatAction(cmdname, RequestGive)
		end
	end
	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction(cmdname)
	end
end
