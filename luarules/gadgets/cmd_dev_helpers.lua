--[[
local msg = 'luar_uels ihatelua -100 200'
for word in msg:gmatch("[%-_%w]+") do
  print (word)
end
]]
--

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Dev Helper Cmds",
		desc = "provides various luarules commands to help developers, can only be used after /cheat",
		author = "Bluestone",
		date = "",
		license = "GNU GPL, v2 or later, Horses",
		layer = -1999999999,
		enabled = true,
	}
end

local PACKET_HEADER = "$dev$"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)
local PH_B1 = string.byte(PACKET_HEADER, 1)

if gadgetHandler:IsSyncedCode() then
	startPlayers = {}
end

function isAuthorized(playerID, subPermission)
	if Spring.IsCheatingEnabled() then
		return true
	end
	local playername = Spring.GetPlayerInfo(playerID)
	local accountID = Spring.Utilities.GetAccountID(playerID)
	local hasPermission = false
	-- check catch-all devhelpers permission (by accountID and by name for late joiners)
	if (_G and _G.permissions.devhelpers and (_G.permissions.devhelpers[accountID] or (playername and _G.permissions.devhelpers[playername]))) or (SYNCED and SYNCED.permissions.devhelpers and (SYNCED.permissions.devhelpers[accountID] or (playername and SYNCED.permissions.devhelpers[playername]))) then
		hasPermission = true
	end
	-- check the devhelpers_<name> sub-permission OR a matching top-level permission
	-- of the same name (e.g. modmarker), so roles without the devhelpers catch-all
	-- (moderators/event managers) are authorized too
	if not hasPermission and subPermission then
		for _, permKey in ipairs({ "devhelpers_" .. subPermission, subPermission }) do
			if (_G and _G.permissions[permKey] and (_G.permissions[permKey][accountID] or (playername and _G.permissions[permKey][playername]))) or (SYNCED and SYNCED.permissions[permKey] and (SYNCED.permissions[permKey][accountID] or (playername and SYNCED.permissions[permKey][playername]))) then
				hasPermission = true
				break
			end
		end
	end
	if hasPermission then
		if startPlayers == nil or startPlayers[playername] == nil then
			return true
		end
	end
	return false
end

if gadgetHandler:IsSyncedCode() then
	function checkStartPlayers()
		for _, playerID in ipairs(Spring.GetPlayerList()) do
			-- update player infos
			local playername, _, spec = Spring.GetPlayerInfo(playerID, false)
			if not spec then
				startPlayers[playername] = true
			end
		end
	end

	function gadget:GameStart()
		checkStartPlayers()
	end

	function LoadMissiles()
		if not Spring.IsCheatingEnabled() then
			return
		end

		for _, unitID in pairs(Spring.GetAllUnits()) do
			Spring.SetUnitStockpile(unitID, math.max(5, select(2, Spring.GetUnitStockpile(unitID)))) --no effect if the unit can't stockpile
		end
	end

	function HalfHealth(words)
		if not Spring.IsCheatingEnabled() then
			return
		end

		if #words > 1 then
			for n = 2, #words do
				local unitID = tonumber(words[n])
				if unitID and Spring.ValidUnitID(unitID) then
					local health = Spring.GetUnitHealth(unitID)
					if health then
						Spring.SetUnitHealth(unitID, health / 2)
					end
				end
			end
			return
		end

		-- No selected units were passed, so keep original behavior.
		for _, unitID in pairs(Spring.GetAllUnits()) do
			local health = Spring.GetUnitHealth(unitID)
			if health then
				Spring.SetUnitHealth(unitID, health / 2)
			end
		end
	end

	local terrainTerraformers = {
		-- invertmap, flips the heightmap, where the height defined is the lowest point, invalid is autotuned to turn land new lowest point at height 0
		invertmap = function(value)
			local minHeight
			if value[1] and value[1] == "wet" then
				minHeight = 0
			else
				minHeight = tonumber(value[1])
				if not minHeight then
					_, minHeight = Spring.GetGroundExtremes()
				end
			end
			Spring.SetHeightMapFunc(function()
				for z = 0, Game.mapSizeZ, Game.squareSize do
					for x = 0, Game.mapSizeX, Game.squareSize do
						Spring.SetHeightMap(x, z, (minHeight - Spring.GetGroundHeight(x, z)))
					end
				end
			end)
		end,
		minheight = function(value)
			local height = tonumber(value[1])
			if height == nil then
				return
			end
			Spring.SetHeightMapFunc(function()
				for z = 0, Game.mapSizeZ, Game.squareSize do
					for x = 0, Game.mapSizeX, Game.squareSize do
						Spring.SetHeightMap(x, z, (math.abs(Spring.GetGroundHeight(x, z) - height) + height))
					end
				end
			end)
		end,
		maxheight = function(value)
			local height = tonumber(value[1])
			if height == nil then
				return
			end
			Spring.SetHeightMapFunc(function()
				for z = 0, Game.mapSizeZ, Game.squareSize do
					for x = 0, Game.mapSizeX, Game.squareSize do
						Spring.SetHeightMap(x, z, -(math.abs(-Spring.GetGroundHeight(x, z) + height) - height))
					end
				end
			end)
		end,
		-- extreme - multipliy the heightmap
		extreme = function(value)
			local multiplier = math.clamp(tonumber(value[1]) or 2, -10, 10)
			Spring.SetHeightMapFunc(function()
				for z = 0, Game.mapSizeZ, Game.squareSize do
					for x = 0, Game.mapSizeX, Game.squareSize do
						Spring.SetHeightMap(x, z, Spring.GetGroundHeight(x, z) * multiplier)
					end
				end
			end)
		end,
		extremeabove = function(value)
			local multiplier = math.clamp(tonumber(value[2]) or 2, -10, 10)
			local height = tonumber(value[1])
			if height == nil then
				return
			end
			Spring.SetHeightMapFunc(function()
				for z = 0, Game.mapSizeZ, Game.squareSize do
					for x = 0, Game.mapSizeX, Game.squareSize do
						local tmp = Spring.GetGroundHeight(x, z)
						if tmp > height then
							Spring.SetHeightMap(x, z, (tmp - height) * multiplier + height)
						end
					end
				end
			end)
		end,
		extremebelow = function(value)
			local multiplier = math.clamp(tonumber(value[2]) or 2, -10, 10)
			local height = tonumber(value[1])
			if height == nil then
				return
			end
			Spring.SetHeightMapFunc(function()
				for z = 0, Game.mapSizeZ, Game.squareSize do
					for x = 0, Game.mapSizeX, Game.squareSize do
						local tmp = Spring.GetGroundHeight(x, z)
						if tmp < height then
							Spring.SetHeightMap(x, z, (tmp - height) * multiplier + height)
						end
					end
				end
			end)
		end,
		-- flatten anything above/bellow these extremes
		flatten = function(value)
			local height = tonumber(value[1])
			if height == nil then
				return
			end
			Spring.SetHeightMapFunc(function()
				for z = 0, Game.mapSizeZ, Game.squareSize do
					for x = 0, Game.mapSizeX, Game.squareSize do
						Spring.SetHeightMap(x, z, math.min(Spring.GetGroundHeight(x, z), height))
					end
				end
			end)
		end,
		floor = function(value)
			local height = tonumber(value[1])
			if height == nil then
				return
			end
			Spring.SetHeightMapFunc(function()
				for z = 0, Game.mapSizeZ, Game.squareSize do
					for x = 0, Game.mapSizeX, Game.squareSize do
						Spring.SetHeightMap(x, z, math.max(Spring.GetGroundHeight(x, z), height))
					end
				end
			end)
		end,
		-- move the water level to designated position, or to the lowest point
		zero = function(value)
			local height = Spring.GetGroundExtremes() + (tonumber(value[1]) or 0)
			Spring.AdjustHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, -height)
		end,
		waterlevel = function(value)
			local height = tonumber(value[1])
			if height then
				Spring.AdjustHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, -height)
			end
		end,
	}

	local function isTerrainMod(debugString)
		for trigger, _ in pairs(terrainTerraformers) do
			if string.find(string.lower(debugString), trigger) then
				return true
			end
		end
		return false
	end
	-- terrain deformer <br>
	-- all deformers are performed independantly, rather than merged into a more efficent single caculation, to let the user stack them multiple times in whatever order
	-- expected format, where each command must be seperated by a comma, space sensetive:
	--		command <required> [optional], command [optional] [optional], command mode + <height>, etc
	-- commands:
	-- 		invertmap [height] or ["wet"]			inverts the height map around the specified point, or "wet" water level aka zero, if unspecified highest ends at zero
	-- 		minheight [height]						inverts the height below the specified point
	-- 		maxheight [height]						inverts the height above the specified point
	-- 		extreme [multiplier]					increases the height intensity
	-- 		extremeabove <height> [multiplier]		increases the height intensity above specified point
	-- 		extremebelow <height> [multiplier]		increases the height intensity below specified point
	-- 		flatten <height>						lowers anything above to it
	-- 		floor <height>							raises anything bellow to it
	-- 		zero [height (not mode compatible)]		sets water level to lowest point or specified height to the roughly best of its ability
	--		waterlevel <height>							move everything up or down
	-- extra:
	--		triangular brackets reffer to required <>
	--		square brackets reffer to optional []
	--		[height]/<height> can be replaced with "mode [int] [+/- <number>]", otpional offset requires a space before and after the + or -
	--		when entering single value there can not be a space after the minus, except for mode offset
	--		e.g. maxheight mode, minheight mode 2, extremeabove mode 1 + 15 2, zero -20

	local function terrainMods(debugString)
		local commands = string.split(debugString, ",")

		-- do we need a list of most common heights? and if so sample it once for all functions
		-- mode, math mode as in mean, median, and mode, where mode is the most commonly occuring value
		-- height gets rounded into stepsize of MODESTEPSIZE variable, counted, and sorted based on that count, using the flatest surface found within that step as the representitive height
		local modeArray = { [1] = 0 }
		if string.find(debugString, "mode") then
			-- count the most common heights, in height groups step sized MODESTEPSIZE variable
			local normal, height, smallestStepHeight = 0, 0, 0
			local tempModeArray = {}
			local MODESTEPSIZE = 16
			for z = 0, Game.mapSizeZ, Game.squareSize do
				for x = 0, Game.mapSizeX, Game.squareSize do
					height = Spring.GetGroundHeight(x, z) or 0
					_, normal, _ = Spring.GetGroundNormal(x, z)
					smallestStepHeight = math.floor(height / MODESTEPSIZE)
					if tempModeArray[smallestStepHeight] then
						tempModeArray[smallestStepHeight][1] = tempModeArray[smallestStepHeight][1] + 1
						if tempModeArray[smallestStepHeight][2] < normal then
							tempModeArray[smallestStepHeight][2] = normal
							tempModeArray[smallestStepHeight][3] = height
						end
					else
						tempModeArray[smallestStepHeight] = { 1, normal, height }
					end
				end
			end

			-- drop the step and sort the heights
			modeArray = {}
			for _, val in pairs(tempModeArray) do
				table.insert(modeArray, { val[1], val[3] })
			end
			tempModeArray = {}
			table.sort(modeArray, function(a, b)
				return a[1] > b[1]
			end)

			-- log the table of mode heights, might be useful for users who wish to fish them out
			Spring.Echo("cmd_dev_helpers, terrainMods; generating table format mode height sampling")
			Spring.Echo("where id is sorted by most common map height for this map")
			Spring.Echo("id: | height: |\tid: | height: |\tid: | height:")
			local tableDebth = math.floor(#modeArray / 3)
			for j = 1, tableDebth do
				Spring.Echo(j .. "\t" .. modeArray[j][2] .. "\t\t\t" .. j + tableDebth .. "\t" .. modeArray[j + tableDebth][2] .. "\t\t\t" .. j + tableDebth + tableDebth .. "\t" .. modeArray[j + tableDebth + tableDebth][2])
			end
			Spring.Echo("cmd_dev_helpers, terrainMods, end of table")
		end

		-- used for reading mode position within the array's constraints or 0
		local function sampleMode(pos)
			if pos == nil then
				return modeArray[1][2]
			end
			if pos == -1 then
				return modeArray[#modeArray][2]
			end
			return modeArray[math.clamp(pos, 1, #modeArray)][2] or 0
		end
		-- end of mode height related sampling

		-- go thourgh the commands
		local command
		local commandProc
		for i = 1, #commands do
			command = string.split(commands[i], " ")
			local func = terrainTerraformers[command[1]]
			if func then
				-- process the commands, convert anything that needs converting
				do
					local j = 2
					commandProc = {}
					for k = 1, #command do
						-- if mode is used, it requests most common height, substitue it
						if command[j] == "mode" then
							-- find which mode value to use, and if we're offsetting it
							local offset = 0.0
							local modePtr = 1
							if command[j + 1] == "+" then
								offset = tonumber(command[j + 2])
								j = j + 2
							elseif command[j + 1] == "-" then
								offset = -tonumber(command[j + 2])
								j = j + 2
							else
								modePtr = tonumber(command[j + 1], 10)
								if modePtr then
									if command[j + 2] == "+" then
										offset = tonumber(command[j + 3])
										j = j + 2
									elseif command[j + 2] == "-" then
										offset = -tonumber(command[j + 3])
										j = j + 2
									end
									j = j + 1
								else
									modePtr = 1
								end
							end
							offset = offset or 0

							commandProc[k] = sampleMode(modePtr) + offset
						else
							commandProc[k] = command[j]
						end
						j = j + 1
					end
				end

				-- call the retrived function with partially processed params
				func(commandProc)
			end
		end

		-- finishing touches
		do
			-- Edge patchwork, something is not right with map edges, i don't know if its the above functions that fail, or if it is during map making
			Spring.SetHeightMapFunc(function()
				for x = 0, Game.mapSizeX, Game.squareSize do
					Spring.SetHeightMap(x, Game.mapSizeZ, (Spring.GetGroundHeight(x, Game.mapSizeZ - Game.squareSize)))
				end
				for z = 0, Game.mapSizeZ, Game.squareSize do
					Spring.SetHeightMap(Game.mapSizeX, z, (Spring.GetGroundHeight(Game.mapSizeX - Game.squareSize, z)))
				end
			end)

			-- orginal height map so that restore ground command doesn't dig trenches or construct mountains
			Spring.SetOriginalHeightMapFunc(function()
				for z = 0, Game.mapSizeZ, Game.squareSize do
					for x = 0, Game.mapSizeX, Game.squareSize do
						Spring.SetOriginalHeightMap(x, z, Spring.GetGroundHeight(x, z))
					end
				end
			end)

			-- temporary smooth mesh, as on some maps it can take up to a minute and a half for it to be created
			Spring.SetSmoothMeshFunc(function()
				for z = 0, Game.mapSizeZ, Game.squareSize do
					for x = 0, Game.mapSizeX, Game.squareSize do
						Spring.SetSmoothMesh(x, z, 50 + Spring.GetGroundHeight(x, z))
					end
				end
			end)
		end
	end

	local debugcommands = nil
	function gadget:Initialize()
		if Spring.GetModOptions() and Spring.GetModOptions().debugcommands then
			local debugString = Spring.GetModOptions().debugcommands

			-- "for fun" terrain moddifiers
			-- they block any accompanying actual debug comands from running
			-- see variable terrainTriggers for list of moddifiers
			-- some odd behavior with start box highlighting
			if isTerrainMod(debugString) then
				terrainMods(string.lower(debugString))
				-- we only need to find 1 command to pass over, cancel actual debug commands
				return
			end

			debugcommands = {}
			local commands = string.split(Spring.GetModOptions().debugcommands, "|")
			for i, command in ipairs(commands) do
				local cmdsplit = string.split(command, ":")
				if cmdsplit[1] and cmdsplit[2] and tonumber(cmdsplit[1]) then
					if not string.find(string.lower(cmdsplit[2]), "execute", nil, true) then
						debugcommands[tonumber(cmdsplit[1])] = cmdsplit[2]
						Spring.Echo("Adding debug command", cmdsplit[1], cmdsplit[2])
					end
				end
			end
		end
		checkStartPlayers()
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if #msg < PACKET_HEADER_LENGTH or string.byte(msg, 1) ~= PH_B1 or string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
			return
		end

		msg = string.sub(msg, PACKET_HEADER_LENGTH)

		local words = {}
		for word in msg:gmatch("[%-_%w]+") do
			table.insert(words, word)
		end

		-- determine required sub-permission for the command
		local cmd = words[1]
		local subPermission
		if cmd == "desync" then
			subPermission = "test"
		elseif cmd == "givecat" or cmd == "loadmissiles" or cmd == "xpunits" or cmd == "destroyunits" or cmd == "removeunits" or cmd == "removenearbyunits" or cmd == "reclaimunits" or cmd == "transferunits" or cmd == "select" or cmd == "unselect" or cmd == "neutralize" or cmd == "maxhealth" or cmd == "setsensors" or cmd == "setblocking" or cmd == "relocate" or cmd == "setradius" or cmd == "setheight" or cmd == "wreckunits" or cmd == "halfhealth" or cmd == "sethealth" or cmd == "spawnceg" or cmd == "spawnunitexplosion" or cmd == "removeunitdef" or cmd == "removeobjects" then
			subPermission = "units"
		elseif cmd == "playertoteam" or cmd == "killteam" then
			subPermission = "teams"
		elseif cmd == "godmode" or cmd == "godmodeally" then
			subPermission = "teams"
		elseif cmd == "globallos" or cmd == "clearwrecks" or cmd == "reducewrecks" then
			subPermission = "terrain"
		elseif cmd == "modmarker" then
			subPermission = "modmarker"
		end

		local bypassSyncedAuthorization = cmd == "godmode" or cmd == "godmodeally"
		if not bypassSyncedAuthorization and not isAuthorized(playerID, subPermission) then
			return
		end

		if cmd == "desync" then
			Spring.Echo("Synced: Attempting to trigger a /desync")
			Spring.SendCommands("desync")
		end

		if cmd == "givecat" then
			GiveCat(words)
		elseif cmd == "loadmissiles" then
			LoadMissiles()
		elseif cmd == "xpunits" then
			local parts = string.split(msg, ":")
			local words = {}
			msg = parts[1] .. ":" .. parts[2]
			for word in msg:gmatch("[%-_%w]+") do
				table.insert(words, word)
			end
			ExecuteSelUnits(words, playerID, "xp", parts[3])
		elseif cmd == "destroyunits" then
			ExecuteSelUnits(words, playerID)
		elseif cmd == "removeunits" then
			ExecuteSelUnits(words, playerID, "remove")
		elseif cmd == "removenearbyunits" then
			ExecuteSelUnits(words, playerID, "removenearbyunits")
		elseif cmd == "reclaimunits" then
			ExecuteSelUnits(words, playerID, "reclaim")
		elseif cmd == "transferunits" then
			local parts = string.split(msg, ":")
			local words = {}
			msg = parts[1] .. ":" .. parts[2]
			for word in msg:gmatch("[%-_%w]+") do
				table.insert(words, word)
			end
			ExecuteSelUnits(words, playerID, "transfer", parts[3])
		elseif cmd == "neutralize" then
			local parts = string.split(msg, ":")
			local words = {}
			msg = parts[1] .. ":" .. parts[2]
			for word in msg:gmatch("[%-_%w]+") do
				table.insert(words, word)
			end
			ExecuteSelUnits(words, playerID, "neutralize", parts[3])
		elseif cmd == "maxhealth" then
			local parts = string.split(msg, ":")
			local words = {}
			msg = parts[1] .. ":" .. parts[2]
			for word in msg:gmatch("[%-_%w]+") do
				table.insert(words, word)
			end
			ExecuteSelUnits(words, playerID, "maxhealth", parts[3])
		elseif cmd == "setsensors" then
			local parts = string.split(msg, ":")
			local words = {}
			msg = parts[1] .. ":" .. parts[2]
			for word in msg:gmatch("[%-_%w]+") do
				table.insert(words, word)
			end
			ExecuteSelUnits(words, playerID, "setsensors", parts[3])
		elseif cmd == "setblocking" then
			local parts = string.split(msg, ":")
			local words = {}
			msg = parts[1] .. ":" .. parts[2]
			for word in msg:gmatch("[%-_%w]+") do
				table.insert(words, word)
			end
			ExecuteSelUnits(words, playerID, "setblocking", parts[3])
		elseif cmd == "relocate" then
			RelocateUnits(words)
		elseif cmd == "setradius" then
			local parts = string.split(msg, ":")
			local words = {}
			msg = parts[1] .. ":" .. parts[2]
			for word in msg:gmatch("[%-_%w]+") do
				table.insert(words, word)
			end
			ExecuteSelUnits(words, playerID, "setradius", parts[3])
		elseif cmd == "setheight" then
			local parts = string.split(msg, ":")
			local words = {}
			msg = parts[1] .. ":" .. parts[2]
			for word in msg:gmatch("[%-_%w]+") do
				table.insert(words, word)
			end
			ExecuteSelUnits(words, playerID, "setheight", parts[3])
		elseif cmd == "select" then
			local requestID = words[2]
			local foundUnits = false
			for n = 3, #words do
				local unitID = tonumber(words[n])
				if unitID and Spring.ValidUnitID(unitID) then
					Spring.SetUnitNoSelect(unitID, false)
					foundUnits = true
				end
			end
			if foundUnits and requestID then
				SendToUnsynced("devhelper_selectunits", playerID, requestID)
			end
		elseif cmd == "unselect" then
			for n = 2, #words do
				local unitID = tonumber(words[n])
				if unitID and Spring.ValidUnitID(unitID) then
					Spring.SetUnitNoSelect(unitID, true)
				end
			end
		elseif cmd == "wreckunits" then
			ExecuteSelUnits(words, playerID, "wreck")
		elseif cmd == "halfhealth" then
			HalfHealth(words)
		elseif cmd == "sethealth" then
			local parts = string.split(msg, ":")
			local words = {}
			msg = parts[1] .. ":" .. parts[2]
			for word in msg:gmatch("[%-_%w]+") do
				table.insert(words, word)
			end
			ExecuteSelUnits(words, playerID, "sethealth", parts[3])
		elseif cmd == "spawnceg" then
			spawnceg(words)
		elseif cmd == "spawnunitexplosion" then
			spawnunitexplosion(words, playerID)
		elseif cmd == "removeunitdef" then
			ExecuteRemoveUnitDefName(words[2])
		elseif cmd == "removeobjects" then
			RemoveObjects()
		elseif cmd == "clearwrecks" then
			ClearWrecks()
		elseif cmd == "reducewrecks" then
			ReduceWrecksAndHeaps()
		elseif cmd == "globallos" then
			globallos(words)
		elseif cmd == "godmode" then
			godmode(words)
		elseif cmd == "godmodeally" then
			godmodeally(words)
		elseif cmd == "playertoteam" then
			playertoteam(words)
		elseif cmd == "killteam" then
			killteam(words)
		elseif cmd == "modmarker" then
			-- split on ':' so a multi-word label ("Rule Violation") keeps its spaces;
			-- the gmatch words[] above would truncate it to the first token. After the
			-- header strip msg is "$:modmarker:x:y:z:label", so parts =
			-- {"$","modmarker",x,y,z,label}.
			local parts = string.split(msg, ":")
			local x = tonumber(parts[3])
			local y = tonumber(parts[4])
			local z = tonumber(parts[5])
			local label = parts[6] or ""
			if x and y and z then
				SendToUnsynced("modmarker", x, y, z, label)
			end
		end
	end

	function gadget:Shutdown() end
	function globallos(words)
		local allyteams = Spring.GetAllyTeamList()
		for i = 1, #allyteams do
			local allyTeamID = allyteams[i]
			if not words[3] or allyTeamID == tonumber(words[3]) then
				Spring.SetGlobalLos(allyTeamID, words[2] == "1")
			end
		end
	end

	function godmode(words)
		local wasCheatingEnabled = Spring.IsCheatingEnabled()
		if not wasCheatingEnabled then
			Spring.SetCheatingEnabled(true)
		end
		Spring.SetGodMode(nil, words[2] == "1")
		if not wasCheatingEnabled then
			Spring.SetCheatingEnabled(false)
		end
	end

	function godmodeally(words)
		local wasCheatingEnabled = Spring.IsCheatingEnabled()
		if not wasCheatingEnabled then
			Spring.SetCheatingEnabled(true)
		end
		Spring.SetGodMode(words[2] == "1", nil)
		if not wasCheatingEnabled then
			Spring.SetCheatingEnabled(false)
		end
	end

	function playertoteam(words)
		Spring.AssignPlayerToTeam(tonumber(words[2]), tonumber(words[3]))
	end

	function killteam(words)
		Spring.KillTeam(tonumber(words[2]))
	end
	local function adjustFeatureHeight()
		local featuretable = Spring.GetAllFeatures()
		local x, y, z
		for i = 1, #featuretable do
			x, y, z = Spring.GetFeaturePosition(featuretable[i])
			Spring.SetFeaturePosition(featuretable[i], x, Spring.GetGroundHeight(x, z), z, true) -- snaptoground = true
		end
	end

	function gadget:GameFrame(n)
		if n == 1 and isTerrainMod(Spring.GetModOptions().debugcommands) then
			adjustFeatureHeight()
		end
		if debugcommands then
			if debugcommands[n] then
				Spring.Echo("Executing debugcommand", debugcommands[n])
				Spring.SendCommands(debugcommands[n])
				debugcommands[n] = nil
			end
		end
	end

	function GiveCat(words)
		if #words < 5 then
			return
		end
		local ox = tonumber(words[2])
		local oz = tonumber(words[3])
		local teamID = tonumber(words[4])
		local giveUnits = {}
		for n = 5, #words do
			giveUnits[#giveUnits + 1] = tonumber(words[n])
		end

		local arrayWidth = math.ceil(math.sqrt(#giveUnits))
		local spacing = 140
		local n = 0
		local x, z = ox, oz
		for _, uDID in ipairs(giveUnits) do
			local y = Spring.GetGroundHeight(x, z)
			Spring.CreateUnit(uDID, x, y, z, "n", teamID)
			n = n + 1
			if n % arrayWidth == 0 then
				x = ox
				z = z + spacing
			else
				x = x + spacing
			end
		end
	end

	function ExecuteSelUnits(words, playerID, action, params)
		if #words < 2 then
			return
		end
		for n = 2, #words do
			local unitID = tonumber(words[n])
			if unitID and Spring.ValidUnitID(unitID) then
				local h, mh = Spring.GetUnitHealth(unitID)
				if not action then
					Spring.DestroyUnit(unitID, false, false, unitID)
				elseif action == "xp" and params then
					--Spring.SetUnitExperience(unitID, select(1, Spring.GetUnitExperience(unitID)) + tonumber(params))
					if type(tonumber(params)) == "number" then
						Spring.SetUnitExperience(unitID, tonumber(params))
					end
				elseif action == "remove" then
					Spring.SetUnitRulesParam(unitID, "remove_decorations", 1)
					Spring.DestroyUnit(unitID, false, true)
				elseif action == "removenearbyunits" then
					Spring.DestroyUnit(unitID, false, true)
				elseif action == "transfer" then
					if type(tonumber(params)) == "number" then
						Spring.TransferUnit(unitID, tonumber(params), true)
					end
				elseif action == "neutralize" then
					Spring.SetUnitNeutral(unitID, params ~= "0")
				elseif action == "maxhealth" and params then
					local newMaxHealth = tonumber(params)
					if newMaxHealth and newMaxHealth > 0 then
						local health, maxHealth = Spring.GetUnitHealth(unitID)
						Spring.SetUnitMaxHealth(unitID, newMaxHealth)
						if maxHealth and maxHealth > 0 then
							local healthPercent = (health or maxHealth) / maxHealth
							Spring.SetUnitHealth(unitID, newMaxHealth * healthPercent)
						else
							Spring.SetUnitHealth(unitID, newMaxHealth)
						end
					end
				elseif action == "setsensors" then
					if params == "0" then
						Spring.SetUnitSensorRadius(unitID, "los", 0)
						Spring.SetUnitSensorRadius(unitID, "airLos", 0)
						Spring.SetUnitSensorRadius(unitID, "radar", 0)
						Spring.SetUnitSensorRadius(unitID, "sonar", 0)
						Spring.SetUnitSensorRadius(unitID, "seismic", 0)
						Spring.SetUnitSensorRadius(unitID, "radarJammer", 0)
						Spring.SetUnitSensorRadius(unitID, "sonarJammer", 0)
					else
						local unitDefID = Spring.GetUnitDefID(unitID)
						local ud = unitDefID and UnitDefs[unitDefID]
						if ud then
							Spring.SetUnitSensorRadius(unitID, "los", ud.losRadius or 0)
							Spring.SetUnitSensorRadius(unitID, "airLos", ud.airLosRadius or ud.losRadius or 0)
							Spring.SetUnitSensorRadius(unitID, "radar", ud.radarDistance or 0)
							Spring.SetUnitSensorRadius(unitID, "sonar", ud.sonarDistance or 0)
							Spring.SetUnitSensorRadius(unitID, "seismic", ud.seismicDistance or ud.seismicdistance or 0)
							Spring.SetUnitSensorRadius(unitID, "radarJammer", ud.radarDistanceJam or 0)
							Spring.SetUnitSensorRadius(unitID, "sonarJammer", ud.sonarDistanceJam or 0)
						end
					end
				elseif action == "setblocking" then
					Spring.SetUnitBlocking(unitID, params ~= "0")
				elseif action == "setradius" and params then
					local delta = tonumber(params)
					if delta then
						local currentRadius = Spring.GetUnitRadius(unitID) or 0
						local currentHeight = Spring.GetUnitHeight(unitID) or 0
						local newRadius = math.max(1, currentRadius + delta)
						Spring.SetUnitRadiusAndHeight(unitID, newRadius, currentHeight)
						Spring.Echo(string.format("unit %d radius: %.2f", unitID, newRadius))
					end
				elseif action == "setheight" and params then
					local delta = tonumber(params)
					if delta then
						local currentRadius = Spring.GetUnitRadius(unitID) or 0
						local currentHeight = Spring.GetUnitHeight(unitID) or 0
						local newHeight = math.max(1, currentHeight + delta)
						Spring.SetUnitRadiusAndHeight(unitID, currentRadius, newHeight)
						Spring.Echo(string.format("unit %d height: %.2f", unitID, newHeight))
					end
				elseif action == "sethealth" and params then
					if type(tonumber(params)) == "number" then
						local healthPercent = math.max(0, math.min(100, tonumber(params)))
						if mh then
							Spring.SetUnitHealth(unitID, mh * healthPercent * 0.01)
						end
					end
				elseif action == "reclaim" then
					local teamID = Spring.GetUnitTeam(unitID)
					local unitDefID = Spring.GetUnitDefID(unitID)
					Spring.DestroyUnit(unitID, false, true) -- this doesnt give back resources in itself
					Spring.AddTeamResource(teamID, "metal", UnitDefs[unitDefID].metalCost)
					Spring.AddTeamResource(teamID, "energy", UnitDefs[unitDefID].energyCost)
				elseif action == "wreck" then
					local unitDefID = Spring.GetUnitDefID(unitID)
					local x, y, z = Spring.GetUnitPosition(unitID)
					local heading = Spring.GetUnitHeading(unitID)
					local unitTeam = Spring.GetUnitTeam(unitID)
					Spring.DestroyUnit(unitID, false, true)
					if UnitDefs[unitDefID] and UnitDefs[unitDefID].corpse and FeatureDefNames[UnitDefs[unitDefID].corpse] then
						local fDefID = FeatureDefNames[UnitDefs[unitDefID].corpse].id
						local fID = Spring.CreateFeature(fDefID, x, y, z, heading, unitTeam)
						if fID then
							Spring.SetFeatureResurrect(fID, unitDefID, heading)
						end
					end
				end
			end
		end
	end

	function RelocateUnits(words)
		if #words < 5 then
			return
		end

		local targetX = tonumber(words[2])
		local targetZ = tonumber(words[3])
		if not targetX or not targetZ then
			return
		end

		local unitData = {}
		local sumX, sumZ = 0, 0
		for n = 4, #words do
			local unitID = tonumber(words[n])
			if unitID and Spring.ValidUnitID(unitID) then
				local x, _, z = Spring.GetUnitPosition(unitID)
				if x and z then
					sumX = sumX + x
					sumZ = sumZ + z
					unitData[#unitData + 1] = { id = unitID, x = x, z = z }
				end
			end
		end

		local count = #unitData
		if count == 0 then
			return
		end

		local centerX = sumX / count
		local centerZ = sumZ / count
		for i = 1, count do
			local u = unitData[i]
			local newX = targetX + (u.x - centerX)
			local newZ = targetZ + (u.z - centerZ)
			local newY = Spring.GetGroundHeight(newX, newZ)
			Spring.SetUnitPosition(u.id, newX, newY, newZ)
		end
	end

	function spawnceg(words)
		Spring.Echo("SYNCED spawnceg", words[1], words[2], words[3], words[4], words[5])
		Spring.SpawnCEG(
			words[2], --cegname
			tonumber(words[3]),
			tonumber(words[4]),
			tonumber(words[5]), --pos
			0,
			0,
			0, --dir
			0 --radius
		)
	end

	function spawnunitexplosion(words, playerID)
		Spring.Echo("SYNCED spawnunitexplosion", words[1], words[2], words[3], words[4], words[5], words[6])
		Spring.SpawnCEG(
			words[2], --cegname
			tonumber(words[3]),
			tonumber(words[4]),
			tonumber(words[5]), --pos
			0,
			0,
			0, --dir
			0 --radius
		)
		local unitDefID = UnitDefNames[words[2]] and UnitDefNames[words[2]].id or false
		if unitDefID then
			local _, _, _, teamID = Spring.GetPlayerInfo(playerID, false)
			local unitID = Spring.CreateUnit(unitDefID, tonumber(words[3]), tonumber(words[4]), tonumber(words[5]), "n", teamID)
			if unitID then
				Spring.DestroyUnit(unitID, words[6] == "1" and true or false, false)

				--if words[6] ~= '1' then
				-- this wont clear up the wreck of the above destroyed unit, but its maybe even bettter this way :)
				local featuresInRange = Spring.GetFeaturesInSphere(tonumber(words[3]), tonumber(words[4]), tonumber(words[5]), 220)
				for j = 1, #featuresInRange do
					Spring.DestroyFeature(featuresInRange[j])
				end
				--end
			end
		end
	end

	function ExecuteRemoveUnitDefName(unitdefname)
		local unitDefID = UnitDefNames[unitdefname].id
		if unitDefID then
			if FeatureDefNames[unitdefname .. "_dead"] then
				wreckFeatureDefID = FeatureDefNames[unitdefname .. "_dead"].id
			end
			if FeatureDefNames[unitdefname .. "_heap"] then
				heapFeatureDefID = FeatureDefNames[unitdefname .. "_heap"].id
			end
			local allunits = Spring.GetAllUnits()
			local removedunits = 0
			local removedwrecks = 0
			local removedheaps = 0
			for i, unitID in ipairs(allunits) do
				if unitDefID == Spring.GetUnitDefID(unitID) then
					Spring.DestroyUnit(unitID, false, true)
					removedunits = removedunits + 1
				end
			end
			local allfeatures = Spring.GetAllFeatures()
			for i, featureID in ipairs(allfeatures) do
				local featureDefID = Spring.GetFeatureDefID(featureID)
				if featureDefID == wreckFeatureDefID then
					Spring.DestroyFeature(featureID)
					removedwrecks = removedwrecks + 1
				end
				if featureDefID == heapFeatureDefID then
					Spring.DestroyFeature(featureID)
					removedheaps = removedheaps + 1
				end
			end

			Spring.Echo(string.format("Removed %i units, %i wrecks, %i heaps for unitDefName %s", removedunits, removedwrecks, removedheaps, unitdefname))
		else
			Spring.Echo("Removeunitdef:", unitdefname, "is not a valid UnitDefName")
		end
	end

	function RemoveObjects()
		local allUnits = Spring.GetAllUnits()
		local removed = 0
		for i = 1, #allUnits do
			local unitID = allUnits[i]
			local unitDefID = Spring.GetUnitDefID(unitID)
			local ud = UnitDefs[unitDefID]
			if ud then
				local cp = ud.customParams
				if (ud.modCategories and ud.modCategories["object"]) or (cp and cp.objectify) then
					Spring.DestroyUnit(unitID, false, true)
					removed = removed + 1
				end
			end
		end
		Spring.Echo(string.format("Removed %i object units", removed))
	end

	function ClearWrecks()
		local allfeatures = Spring.GetAllFeatures()
		local removedwrecks = 0
		for i, featureID in pairs(allfeatures) do
			local featureDef = FeatureDefs[Spring.GetFeatureDefID(featureID)]
			local category = featureDef.customParams.category
			if category == "corpses" or category == "heaps" then
				Spring.DestroyFeature(featureID)
				removedwrecks = removedwrecks + 1
			end
		end
		Spring.Echo(string.format("Removed %i wrecks and heaps", removedwrecks))
	end

	function ReduceWrecksAndHeaps()
		local allfeatures = Spring.GetAllFeatures()
		local removedwrecks, removedheaps = 0, 0
		for i, featureID in pairs(allfeatures) do
			local featureDef = FeatureDefs[Spring.GetFeatureDefID(featureID)]
			local category = featureDef.customParams.category
			if category == "corpses" then
				Spring.AddFeatureDamage(featureID, (Spring.GetFeatureHealth(featureID)))
				removedwrecks = removedwrecks + 1
			elseif category == "heaps" then
				Spring.AddFeatureDamage(featureID, (Spring.GetFeatureHealth(featureID)))
				removedheaps = removedheaps + 1
			end
		end
		Spring.Echo(string.format("Removed %i wrecks and %i heaps", removedwrecks, removedheaps))
	end
else -- UNSYNCED
	local pendingSelectRequests = {}
	local selectRequestSeq = 0
	local lastSelectionBoxX1, lastSelectionBoxY1, lastSelectionBoxX2, lastSelectionBoxY2
	local lastSelectionBoxFrame = -1
	local HOVER_PICK_SCREEN_RADIUS = 18
	local HOVER_PICK_WORLD_RADIUS = 120
	local godModeControlAllies, godModeControlEnemies

	local function initializeGodModeState()
		if godModeControlAllies == nil or godModeControlEnemies == nil then
			local enabled = Spring.IsGodModeEnabled()
			godModeControlAllies = enabled
			godModeControlEnemies = enabled
		end
	end

	function gadget:Initialize()
		local myPlayerID = Spring.GetLocalPlayerID()
		local function addAuthorizedChatAction(permission, action, handler)
			if isAuthorized(myPlayerID, permission) then
				gadgetHandler:AddChatAction(action, handler)
			end
		end

		addAuthorizedChatAction("units", "loadmissiles", loadMissiles)
		addAuthorizedChatAction("units", "givecat", GiveCat)
		addAuthorizedChatAction("units", "destroyunits", destroyUnits)
		addAuthorizedChatAction("units", "wreckunits", wreckUnits)
		addAuthorizedChatAction("units", "reclaimunits", reclaimUnits)
		addAuthorizedChatAction("units", "removeunits", removeUnits)
		addAuthorizedChatAction("units", "removenearbyunits", removeNearbyUnits)
		addAuthorizedChatAction("units", "transferunits", transferUnits)
		addAuthorizedChatAction("units", "neutralize", neutralizeUnits)
		addAuthorizedChatAction("units", "maxhealth", maxHealthUnits)
		addAuthorizedChatAction("units", "setsensors", setSensors)
		addAuthorizedChatAction("units", "setblocking", setBlocking)
		addAuthorizedChatAction("units", "relocate", relocateUnits)
		addAuthorizedChatAction("units", "setradius", setRadiusUnits)
		addAuthorizedChatAction("units", "setheight", setHeightUnits)
		addAuthorizedChatAction("units", "select", selectHoveredUnit)
		addAuthorizedChatAction("units", "unselect", unselectHoveredUnit)
		addAuthorizedChatAction("units", "halfhealth", halfHealth)
		addAuthorizedChatAction("units", "sethealth", setHealth)
		addAuthorizedChatAction("units", "xp", xpUnits)
		addAuthorizedChatAction("units", "spawnceg", spawnceg)
		addAuthorizedChatAction("units", "spawnunitexplosion", spawnunitexplosion)
		addAuthorizedChatAction("units", "dumpunits", dumpUnits)
		addAuthorizedChatAction("units", "dumpfeatures", dumpFeatures)
		addAuthorizedChatAction("units", "dumploadout", dumpLoadout)
		addAuthorizedChatAction("units", "removeunitdef", removeUnitDef)
		addAuthorizedChatAction("units", "removeobjects", removeObjects)

		addAuthorizedChatAction("terrain", "clearwrecks", clearWrecks)
		addAuthorizedChatAction("terrain", "reducewrecks", reduceWrecks)
		addAuthorizedChatAction("terrain", "globallos", globallos)

		addAuthorizedChatAction("teams", "playertoteam", playertoteam)
		addAuthorizedChatAction("teams", "killteam", killteam)
		addAuthorizedChatAction("teams", "godmode", godmode)
		addAuthorizedChatAction("teams", "godmodeally", godmodeally)

		addAuthorizedChatAction("test", "desync", desync)
		addAuthorizedChatAction("modmarker", "modmarker", modmarker)
		-- Moderator broadcast ping: the synced modmarker handler relays here, and
		-- every client draws it locally (localOnly=true) so ALL players see it.
		gadgetHandler:AddSyncAction("modmarker", function(_, x, y, z, label)
			Spring.MarkerAddPoint(x, y, z, label or "", true)
		end)
		gadgetHandler:AddSyncAction("devhelper_selectunits", function(_, requestPlayerID, requestID)
			if requestPlayerID ~= Spring.GetLocalPlayerID() then
				return
			end
			local requestKey = tostring(requestID)
			local units = pendingSelectRequests[requestKey]
			if units and #units > 0 then
				Spring.SelectUnitArray(units, false)
			end
			pendingSelectRequests[requestKey] = nil
		end)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("loadmissiles")
		gadgetHandler:RemoveChatAction("givecat")
		gadgetHandler:RemoveChatAction("destroyunits")
		gadgetHandler:RemoveChatAction("reclaimunits")
		gadgetHandler:RemoveChatAction("removeunits")
		gadgetHandler:RemoveChatAction("removenearbyunits")
		gadgetHandler:RemoveChatAction("transferunits")
		gadgetHandler:RemoveChatAction("neutralize")
		gadgetHandler:RemoveChatAction("maxhealth")
		gadgetHandler:RemoveChatAction("setsensors")
		gadgetHandler:RemoveChatAction("setblocking")
		gadgetHandler:RemoveChatAction("relocate")
		gadgetHandler:RemoveChatAction("setradius")
		gadgetHandler:RemoveChatAction("setheight")
		gadgetHandler:RemoveChatAction("select")
		gadgetHandler:RemoveChatAction("unselect")
		gadgetHandler:RemoveChatAction("halfhealth")
		gadgetHandler:RemoveChatAction("sethealth")
		gadgetHandler:RemoveChatAction("xp")
		gadgetHandler:RemoveChatAction("spawnceg")
		gadgetHandler:RemoveChatAction("spawnunitexplosion")

		gadgetHandler:RemoveChatAction("dumpunits")
		gadgetHandler:RemoveChatAction("dumpfeatures")
		gadgetHandler:RemoveChatAction("removeunitdefs")
		gadgetHandler:RemoveChatAction("removeobjects")
		gadgetHandler:RemoveChatAction("clearwrecks")
		gadgetHandler:RemoveChatAction("reducewrecks")
		gadgetHandler:RemoveChatAction("globallos")
		gadgetHandler:RemoveChatAction("playertoteam")
		gadgetHandler:RemoveChatAction("killteam")
		gadgetHandler:RemoveChatAction("godmode")
		gadgetHandler:RemoveChatAction("godmodeally")
		gadgetHandler:RemoveChatAction("desync")
		gadgetHandler:RemoveChatAction("modmarker")
		gadgetHandler:RemoveSyncAction("modmarker")
		gadgetHandler:RemoveSyncAction("devhelper_selectunits")
	end
	function loadMissiles(_, line, words, playerID)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "units") then
			return
		end
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ":loadmissiles")
	end

	function xpUnits(_, line, words, playerID)
		processUnits(_, line, words, playerID, "xpunits")
	end
	function destroyUnits(_, line, words, playerID)
		processUnits(_, line, words, playerID, "destroyunits")
	end
	function wreckUnits(_, line, words, playerID)
		processUnits(_, line, words, playerID, "wreckunits")
	end
	function reclaimUnits(_, line, words, playerID)
		processUnits(_, line, words, playerID, "reclaimunits")
	end
	function removeUnits(_, line, words, playerID)
		processUnits(_, line, words, playerID, "removeunits")
	end
	function removeNearbyUnits(_, line, words, playerID)
		processUnits(_, line, words, playerID, "removenearbyunits")
	end
	function transferUnits(_, line, words, playerID)
		processUnits(_, line, words, playerID, "transferunits")
	end
	function neutralizeUnits(_, line, words, playerID)
		if words[1] and words[1] ~= "0" and words[1] ~= "1" then
			Spring.Echo("Usage: /luarules neutralize [1|0]")
			return
		end
		processUnits(_, line, words, playerID, "neutralize")
	end
	function maxHealthUnits(_, line, words, playerID)
		if not words[1] or type(tonumber(words[1])) ~= "number" or tonumber(words[1]) <= 0 then
			Spring.Echo("Usage: /luarules maxhealth [number > 0]")
			return
		end
		processUnits(_, line, words, playerID, "maxhealth")
	end
	function setSensors(_, line, words, playerID)
		if words[1] and words[1] ~= "0" and words[1] ~= "1" then
			Spring.Echo("Usage: /luarules setsensors [0|1]")
			return
		end
		processUnits(_, line, words, playerID, "setsensors")
	end
	function setBlocking(_, line, words, playerID)
		if words[1] and words[1] ~= "0" and words[1] ~= "1" then
			Spring.Echo("Usage: /luarules setblocking [1|0]")
			return
		end
		processUnits(_, line, words, playerID, "setblocking")
	end
	function relocateUnits(_, line, words, playerID)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "units") then
			return
		end

		local units = Spring.GetSelectedUnits()
		if not units or #units == 0 then
			return
		end

		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if type(pos) ~= "table" then
			return
		end

		local msg = string.format("relocate %d %d", math.floor(pos[1]), math.floor(pos[3]))
		for i = 1, #units do
			msg = msg .. " " .. units[i]
		end
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ":" .. msg)
	end
	function setRadiusUnits(_, line, words, playerID)
		if not words[1] or type(tonumber(words[1])) ~= "number" then
			Spring.Echo("Usage: /luarules setradius [value]")
			return
		end
		processUnits(_, line, words, playerID, "setradius")
	end
	function setHeightUnits(_, line, words, playerID)
		if not words[1] or type(tonumber(words[1])) ~= "number" then
			Spring.Echo("Usage: /luarules setheight [value]")
			return
		end
		processUnits(_, line, words, playerID, "setheight")
	end
	function selectHoveredUnit(_, line, words, playerID, action)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "units") then
			return
		end

		action = action or "select"

		local targetUnits = {}
		local boxX1, boxY1, boxX2, boxY2 = Spring.GetSelectionBox()
		if not boxX1 and lastSelectionBoxFrame >= 0 and (Spring.GetGameFrame() - lastSelectionBoxFrame) <= 16 then
			boxX1, boxY1, boxX2, boxY2 = lastSelectionBoxX1, lastSelectionBoxY1, lastSelectionBoxX2, lastSelectionBoxY2
		end

		if boxX1 then
			targetUnits = Spring.GetUnitsInScreenRectangle(boxX1, boxY1, boxX2, boxY2) or {}
		else
			local selectedUnits = Spring.GetSelectedUnits()
			if selectedUnits and #selectedUnits > 0 then
				local minX, minZ, maxX, maxZ
				for i = 1, #selectedUnits do
					local sx, _, sz = Spring.GetUnitPosition(selectedUnits[i])
					if sx and sz then
						if not minX then
							minX, minZ, maxX, maxZ = sx, sz, sx, sz
						else
							if sx < minX then
								minX = sx
							end
							if sx > maxX then
								maxX = sx
							end
							if sz < minZ then
								minZ = sz
							end
							if sz > maxZ then
								maxZ = sz
							end
						end
					end
				end
				if minX then
					targetUnits = Spring.GetUnitsInRectangle(minX, minZ, maxX, maxZ) or {}
				end
			else
				local mx, my = Spring.GetMouseState()
				Script.LuaUI.RestoreSelectionVolume() -- keep raycast behavior consistent with existing gadget usage
				local targetType, unitID = Spring.TraceScreenRay(mx, my)
				Script.LuaUI.RemoveSelectionVolume()
				if targetType == "unit" and unitID and Spring.ValidUnitID(unitID) then
					targetUnits[1] = unitID
				else
					targetUnits = Spring.GetUnitsInScreenRectangle(mx - HOVER_PICK_SCREEN_RADIUS, my - HOVER_PICK_SCREEN_RADIUS, mx + HOVER_PICK_SCREEN_RADIUS, my + HOVER_PICK_SCREEN_RADIUS) or {}
					if #targetUnits == 0 then
						local _, pos = Spring.TraceScreenRay(mx, my, true)
						if type(pos) == "table" then
							local nearbyUnits = Spring.GetUnitsInSphere(pos[1], pos[2], pos[3], HOVER_PICK_WORLD_RADIUS) or {}
							local bestUnitID, bestDistSq
							for i = 1, #nearbyUnits do
								local candidateID = nearbyUnits[i]
								if candidateID and Spring.ValidUnitID(candidateID) then
									local ux, _, uz = Spring.GetUnitPosition(candidateID)
									if ux and uz then
										local dx = ux - pos[1]
										local dz = uz - pos[3]
										local distSq = dx * dx + dz * dz
										if not bestDistSq or distSq < bestDistSq then
											bestDistSq = distSq
											bestUnitID = candidateID
										end
									end
								end
							end
							if bestUnitID then
								targetUnits[1] = bestUnitID
							end
						end
					end
				end
			end
		end

		if #targetUnits == 0 then
			return
		end

		local uniqueUnits = {}
		local uniqueCount = 0
		local seen = {}
		for i = 1, #targetUnits do
			local unitID = targetUnits[i]
			if unitID and Spring.ValidUnitID(unitID) and not seen[unitID] then
				seen[unitID] = true
				uniqueCount = uniqueCount + 1
				uniqueUnits[uniqueCount] = unitID
			end
		end

		if uniqueCount == 0 then
			return
		end

		local msg
		if action == "select" then
			selectRequestSeq = selectRequestSeq + 1
			local requestID = tostring(selectRequestSeq)
			pendingSelectRequests[requestID] = uniqueUnits
			msg = PACKET_HEADER .. ":select:" .. requestID
		else
			msg = PACKET_HEADER .. ":unselect"
		end
		for i = 1, uniqueCount do
			msg = msg .. ":" .. uniqueUnits[i]
		end
		Spring.SendLuaRulesMsg(msg)
	end

	function unselectHoveredUnit(_, line, words, playerID)
		selectHoveredUnit(_, line, words, playerID, "unselect")
	end
	function halfHealth(_, line, words, playerID)
		processUnits(_, line, words, playerID, "halfhealth")
	end
	function setHealth(_, line, words, playerID)
		if not words[1] or type(tonumber(words[1])) ~= "number" then
			Spring.Echo("Usage: /luarules sethealth [0-100]")
			return
		end
		processUnits(_, line, words, playerID, "sethealth")
	end

	function removeUnitDef(_, line, words, playerID)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "units") then
			return
		end
		-- Spring.Echo(line)
		-- Spring.Echo(words[1])
		-- Spring.Echo(words[2])
		-- Spring.Echo(words[3])
		if words[1] and UnitDefNames[words[1]] then
			Spring.SendLuaRulesMsg(PACKET_HEADER .. ":removeunitdef " .. words[1])
		end
	end

	function removeObjects(_, line, words, playerID)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "units") then
			return
		end
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ":removeobjects")
	end

	function clearWrecks(_, line, words, playerID)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "terrain") then
			return
		end
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ":clearwrecks")
	end

	function reduceWrecks(_, line, words, playerID)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "terrain") then
			return
		end
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ":reducewrecks")
	end

	function processUnits(_, line, words, playerID, action)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "units") then
			return
		end
		local msg = ""
		local units = {}
		if action == "removenearbyunits" then
			local mx, my = Spring.GetMouseState()
			local targetType, pos = Spring.TraceScreenRay(mx, my, true)
			if type(pos) == "table" then
				units = Spring.GetUnitsInSphere(pos[1], pos[2], pos[3], words[1] and words[1] or 24, words[2] and words[2] or nil)
			end
		else
			if not words[1] and action == "transferunits" then
				local mx, my = Spring.GetMouseState()
				Script.LuaUI.RestoreSelectionVolume() -- Fence calls to TraceScreenRay without onlyCoords == true.
				local targetType, unitID = Spring.TraceScreenRay(mx, my)
				Script.LuaUI.RemoveSelectionVolume()
				if targetType == "unit" then
					words[1] = Spring.GetUnitTeam(unitID)
				end
			end
			units = Spring.GetSelectedUnits()
		end
		for _, unitID in ipairs(units) do
			msg = msg .. " " .. tostring(unitID)
		end
		if words[1] then
			msg = msg .. ":" .. words[1]
		end
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ":" .. action .. msg)
	end

	function dumpFeatures(_, line, words, playerID)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "units") then
			return
		end
		local features = Spring.GetAllFeatures()
		Spring.Echo("Dumping all features")
		for k, featureID in pairs(features) do
			local featureName = (FeatureDefs[Spring.GetFeatureDefID(featureID)].name or "nil")
			local x, y, z = Spring.GetFeaturePosition(featureID)
			local r = Spring.GetFeatureHeading(featureID)
			local resurrectas = Spring.GetFeatureResurrect(featureID)
			if resurrectas then
				resurrectas = '"' .. resurrectas .. '"'
			else
				resurrectas = "nil"
			end
			Spring.Echo(string.format("{name = '%s', x = %d, y = %d, z = %d, rot = %d , scale = 1.0, resurrectas = %s},\n", featureName, x, y, z, r, resurrectas)) --{ name = 'ad0_aleppo_2', x = 2900, z = 52, rot = "-1" },
		end
	end

	function dumpUnits(_, line, words, playerID)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "units") then
			return
		end
		Spring.Echo("Dumping all units")
		local units = Spring.GetAllUnits()
		for k, unitID in pairs(units) do
			local unitname = (UnitDefs[Spring.GetUnitDefID(unitID)].name or "nil")
			local x, y, z = Spring.GetUnitPosition(unitID)
			local r = Spring.GetUnitHeading(unitID)
			local tid = Spring.GetUnitTeam(unitID)
			local isneutral = tostring(Spring.GetUnitNeutral(unitID))
			Spring.Echo(string.format("{name = '%s', x = %d, y = %d, z = %d, rot = %d , team = %d, neutral = %s},\n", unitname, x, y, z, r, tid, isneutral)) --{ name = 'ad0_aleppo_2', x = 2900, z = 52, rot = "-1" },
		end
	end

	--- Dumps all units and features in the loadout.lua format used by UnitLoadout / FeatureLoadout in missions.
	--- Usage: /luarules dumploadout
	function dumpLoadout(_, line, words, playerID)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "units") then
			return
		end

		local headingToFacing = Spring.Utilities.HeadingToFacing

		Spring.Echo("local unitLoadout = {")
		for _, unitID in pairs(Spring.GetAllUnits()) do
			local unitDefName = UnitDefs[Spring.GetUnitDefID(unitID)].name or "nil"
			local x, y, z = Spring.GetUnitPosition(unitID)
			local facing = headingToFacing(Spring.GetUnitHeading(unitID))
			local team = Spring.GetUnitTeam(unitID)
			local isBeingBuilt = Spring.GetUnitIsBeingBuilt(unitID)
			local isNeutral = Spring.GetUnitNeutral(unitID)
			local extras = ""
			if isBeingBuilt then
				extras = extras .. ", construction = true"
			end
			if isNeutral then
				extras = extras .. ", neutral = true"
			end
			Spring.Echo(string.format("\t{ unitDefName = '%s', x = %d, z = %d, facing = '%s', team = %d%s },", unitDefName, math.floor(x), math.floor(z), facing, team, extras))
		end
		Spring.Echo("}")

		Spring.Echo("local featureLoadout = {")
		for _, featureID in pairs(Spring.GetAllFeatures()) do
			local featureDefName = (FeatureDefs[Spring.GetFeatureDefID(featureID)].name or "nil")
			local x, y, z = Spring.GetFeaturePosition(featureID)
			local facing = headingToFacing(Spring.GetFeatureHeading(featureID))
			Spring.Echo(string.format("\t{ featureDefName = '%s', x = %d, z = %d, facing = '%s' },", featureDefName, math.floor(x), math.floor(z), facing))
		end
		Spring.Echo("}")
	end

	local function centerCamera()
		local camState = Spring.GetCameraState()
		if camState then
			local mapcx = Game.mapSizeX / 2
			local mapcz = Game.mapSizeZ / 2
			local mapcy = Spring.GetGroundHeight(mapcx, mapcz)

			camState["px"] = mapcx
			camState["py"] = mapcy
			camState["pz"] = mapcz
			camState["dy"] = -1
			camState["dz"] = -1
			camState["dx"] = 0
			camState["rx"] = 2.75
			camState["height"] = mapcy + 2000
			camState["dist"] = mapcy + 2000
			camState["name"] = "spring"

			Spring.SetCameraState(camState, 0.75)
		end
	end

	local fightertestactive = false
	local fighterteststats

	-- An Update is always done before a Draw Frame
	-- An Update always Start with Gadget:Update
	-- A draw frame actually spans from DrawGenesis to DrawScreenPost!
	-- The timer of every sim frame ends with a lastFrameTime
	-- A Sim frame starts at gadget:GameFrame.
	-- The end of a Sim Frame is unknown

	-- A

	-- Spring.DiffTimers(Spring.GetTimerMicros(),tus)

	local lastDrawTimerUS = Spring.GetTimerMicros()
	local lastSimTimerUS = Spring.GetTimerMicros()
	local lastUpdateTimerUs = Spring.GetTimerMicros()
	local lastFrameType = "draw" -- can be draw, sim, update
	local simTime = 0
	local drawTime = 0
	local updateTime = 0
	local isBenchMark = false
	local benchMarkFrames = 0

	local ss = 0
	local sd = 0
	local su = 0
	local alpha = 0.98

	function gadget:ViewResize()
		vsx, vsy = Spring.GetViewGeometry()
		uiScale = vsy / 1080
	end

	function gadget:Update() -- START OF UPDATE
		local sx1, sy1, sx2, sy2 = Spring.GetSelectionBox()
		if sx1 then
			lastSelectionBoxX1, lastSelectionBoxY1, lastSelectionBoxX2, lastSelectionBoxY2 = sx1, sy1, sx2, sy2
			lastSelectionBoxFrame = Spring.GetGameFrame()
		end

		if fightertestactive then
			local now = Spring.GetTimerMicros()
			if lastFrameType == "draw" then
				-- We are doing a double draw
			else
				-- We are ending a sim frame, so better push the sim frame time number
				simTime = Spring.DiffTimers(now, lastSimTimerUS)
				fighterteststats.simFrameTimes[#fighterteststats.simFrameTimes + 1] = simTime
				ss = alpha * ss + (1 - alpha) * simTime
			end
			lastUpdateTimerUs = Spring.GetTimerMicros()
		end
	end

	function gadget:GameFrame(n) -- START OF SIM FRAME
		if fightertestactive then
			local now = Spring.GetTimerMicros()
			if lastFrameType == "sim" then
				-- We are doing double sim, push a sim frame time number
				simTime = Spring.DiffTimers(now, lastSimTimerUS)
				fighterteststats.simFrameTimes[#fighterteststats.simFrameTimes + 1] = simTime
				ss = alpha * ss + (1 - alpha) * simTime
			else -- we are coming off a draw frame
			end
			lastSimTimerUS = now
			lastFrameType = "sim"
		end
	end

	function gadget:DrawGenesis() -- START OF DRAW
		if fightertestactive then
			local now = Spring.GetTimerMicros()
			updateTime = Spring.DiffTimers(now, lastUpdateTimerUs)
			fighterteststats.updateFrameTimes[#fighterteststats.updateFrameTimes + 1] = updateTime
			su = alpha * su + (1 - alpha) * updateTime
			lastDrawTimerUS = now
		end
	end

	function gadget:DrawScreenPost() -- END OF DRAW
		if fightertestactive then
			drawTime = Spring.DiffTimers(Spring.GetTimerMicros(), lastDrawTimerUS)
			fighterteststats.drawFrameTimes[#fighterteststats.drawFrameTimes + 1] = drawTime
			sd = alpha * sd + (1 - alpha) * drawTime

			lastFrameType = "draw"
			dt = drawTime
		end
	end

	function gadget:DrawScreen()
		if fightertestactive or isBenchMark then
			local s = ""
			if isBenchMark then
				s = s .. string.format("Benchmark Frame %d/%d\n", #fighterteststats.simFrameTimes, benchMarkFrames)
			end
			s = s .. string.format("Sim = ~%3.2fms  (%3.2fms)\nUpdate = ~%3.2fms (%3.2fms)\nDraw = ~%3.2fms (%3.2fms)", ss, simTime, su, updateTime, sd, drawTime)
			gl.Text(s, 600 * uiScale, 600 * uiScale, 16 * uiScale)
		end
	end

	function gadget:UnitCreated()
		if fightertestactive then
			fighterteststats.numunitscreated = fighterteststats.numunitscreated + 1
		end
	end

	function gadget:UnitDestroyed()
		if fightertestactive then
			fighterteststats.numunitsdestroyed = fighterteststats.numunitsdestroyed + 1
		end
	end

	function fightertest(_, line, words, playerID, action)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		Spring.Echo("Fightertest", line, words, playerID, action)
		if not isAuthorized(playerID, "terrain") then
			return
		end
		if fightertestactive then
			-- We need to dump the stats
			local s1 = string.format("Fightertest complete, #created = %d, #destroyed = %d", fighterteststats.numunitscreated, fighterteststats.numunitsdestroyed)
			Spring.Echo(s1)
			local res = {}
			local stats = {}
			for n, t in pairs({ Sim = fighterteststats.simFrameTimes, Draw = fighterteststats.drawFrameTimes, Update = fighterteststats.updateFrameTimes }) do
				local ms = {
					count = 0,
					total = 0,
					mean = 0,
					spread = 0,
					percentiles = {},
				} --mystats
				-- Discard first 10%
				local ct = {} -- cleantable
				local oldtotal = #t
				for i, v in ipairs(t) do
					if i > (oldtotal * 0.1) then
						ms.count = ms.count + 1
						ct[ms.count] = v
						ms.total = ms.total + v
					end
				end

				ms.mean = ms.total / ms.count
				table.sort(ct)

				for i, v in ipairs(ct) do
					ms.spread = ms.spread + math.abs(v - ms.mean)
				end
				ms.spread = ms.spread / ms.count

				for _, i in ipairs({ 0, 1, 2, 5, 10, 20, 35, 50, 65, 80, 90, 95, 98, 99, 100 }) do
					ms.percentiles[i] = ct[math.min(#ct, 1 + math.floor(i * 0.01 * #ct))]
				end

				stats[n] = ms

				local total = 0
				for i, v in ipairs(t) do
					total = total + v
				end

				local s2 = string.format("%s %d frames, %3.2fms per frame, %4.2fs total", n, ms.count, ms.mean, ms.total)
				res[#res + 1] = s2
				Spring.Echo(s2)
			end

			if isBenchMark then
				--stats.scenariooptions = Spring.GetModOptions().scenariooptions -- pass it back so we know difficulty
				stats.benchmarkcommand = isBenchMark
				stats.mapName = Game.mapName
				stats.gameName = Game.gameName .. " " .. Game.gameVersion
				stats.engineVersion = Engine.versionFull
				stats.gpu = Platform.gpu
				stats.cpu = Platform.hwConfig
				stats.display = tostring(vsx) .. "x" .. tostring(vsy)

				Spring.Echo("Benchmark Results")
				Spring.Echo(stats)

				if Spring.GetMenuName then
					local message = Json.encode(stats)
					--Spring.Echo("Sending Message", message)
					Spring.SendLuaMenuMsg("ScenarioGameEnd " .. message)
				end
			end

			-- clean up
			--fighterteststats = {}
		else
			Spring.Echo("Starting Fightertest")
			if Spring.GetModOptions().scenariooptions then
				--Spring.Echo("Scenario: Spawning on frame", Spring.GetGameFrame())
				local scenariooptions = string.base64Decode(Spring.GetModOptions().scenariooptions)
				Spring.Echo(scenariooptions)
				scenariooptions = Json.decode(scenariooptions)
				if scenariooptions and scenariooptions.benchmarkcommand then
					--This is where the magic happens!
					isBenchMark = scenariooptions.benchmarkcommand
					benchMarkFrames = scenariooptions.benchmarkframes
				end
			end
			-- initialize stats table
			fighterteststats = {
				fightertestcommand = line,
				simFrameTimes = {},
				drawFrameTimes = {},
				updateFrameTimes = {},
				numunitscreated = 0,
				numunitsdestroyed = 0,
			}
			lastDrawTimerUS = Spring.GetTimerMicros()
			lastSimTimerUS = Spring.GetTimerMicros()
			lastUpdateTimerUs = Spring.GetTimerMicros()
		end
		fightertestactive = not fightertestactive
		local msg = PACKET_HEADER .. ":fightertest"
		for i = 1, 5 do
			if words[i] then
				msg = msg .. " " .. tostring(words[i])
			end
		end
		centerCamera()
		Spring.SendLuaRulesMsg(msg)
	end

	function globallos(_, line, words, playerID, action)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "terrain") then
			return
		end
		if words[2] then
		end
		local globallos = (not words[1] or words[1] ~= "0") or false
		Spring.Echo("Globallos: " .. (globallos and "enabled" or "disabled"))
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ":globallos:" .. (globallos and " 1" or " 0") .. (words[2] and ":" .. words[2] or ""))
	end

	function godmode(_, line, words, playerID)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "teams") then
			return
		end
		initializeGodModeState()
		godModeControlEnemies = not godModeControlEnemies
		Spring.Echo("Enemy godmode: " .. (godModeControlEnemies and "enabled" or "disabled"))
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ":godmode:" .. (godModeControlEnemies and "1" or "0"))
	end

	function godmodeally(_, line, words, playerID)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "teams") then
			return
		end
		initializeGodModeState()
		godModeControlAllies = not godModeControlAllies
		Spring.Echo("Ally godmode: " .. (godModeControlAllies and "enabled" or "disabled"))
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ":godmodeally:" .. (godModeControlAllies and "1" or "0"))
	end

	function playertoteam(_, line, words, playerID, action)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "teams") then
			return
		end
		if not words[1] then
			units = Spring.GetSelectedUnits()
			if #units > 0 then
				words[1] = Spring.GetUnitTeam(units[1])
			else
				local mx, my = Spring.GetMouseState()
				local targetType, unitID = Spring.TraceScreenRay(mx, my)
				if targetType == "unit" then
					words[1] = Spring.GetUnitTeam(unitID)
				end
			end
		end
		if not words[2] then
			words[2] = words[1]
			words[1] = Spring.GetLocalPlayerID()
		end
		if tonumber(words[2]) < (#Spring.GetTeamList()) - 1 then
			Spring.SendLuaRulesMsg(PACKET_HEADER .. ":playertoteam:" .. words[1] .. ":" .. words[2])
		end
	end

	function killteam(_, line, words, playerID, action)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "teams") then
			return
		end
		if not words[1] then
			return
		end
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ":killteam:" .. words[1])
	end

	function desync(_, line, words, playerID)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "test") then
			return
		end
		Spring.Echo("Unsynced: Attempting to trigger a /desync")
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ":desync")
	end

	function spawnceg(_, line, words, playerID)
		--spawnceg usage:
		--/luarules spawnceg newnuke --spawns at cursor
		--/luarules spawnceg newnuke [int] -- spawns at cursor at height
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "units") then
			return
		end
		local height = 32
		if words[2] and tonumber(words[2]) then
			height = tonumber(words[2])
		end
		local mx, my = Spring.GetMouseState()
		local t, pos = Spring.TraceScreenRay(mx, my, true)
		if type(pos) == "table" then
			local n = 0
			local ox, oy, oz = math.floor(pos[1]), math.floor(pos[2] + height), math.floor(pos[3])
			local x, y, z = ox, oy, oz
			local msg = "spawnceg " .. tostring(words[1]) .. " " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z)

			Spring.Echo("Spawning CEG:", line, playerID, msg)
			Spring.SendLuaRulesMsg(PACKET_HEADER .. ":" .. msg)
		end
	end

	function modmarker(_, line, words, playerID)
		-- /luarules modmarker          -- places broadcast marker at cursor with no label
		-- /luarules modmarker My text  -- places broadcast marker at cursor with label
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "modmarker") then
			return
		end
		local mx, my = Spring.GetMouseState()
		local t, pos = Spring.TraceScreenRay(mx, my, true)
		if type(pos) == "table" then
			local x = math.floor(pos[1])
			local y = math.floor(pos[2])
			local z = math.floor(pos[3])
			local label = words[1] and table.concat(words, " ", 1) or ""
			Spring.SendLuaRulesMsg(PACKET_HEADER .. ":modmarker:" .. x .. ":" .. y .. ":" .. z .. ":" .. label)
		end
	end

	function spawnunitexplosion(_, line, words, playerID)
		--/luarules spawnunitexplosion armbull --spawns at cursor
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "units") then
			return
		end
		local mx, my = Spring.GetMouseState()
		local t, pos = Spring.TraceScreenRay(mx, my, true)
		local ox, oy, oz = math.floor(pos[1]), math.floor(pos[2]), math.floor(pos[3])
		local x, y, z = ox, oy, oz
		local msg = "spawnunitexplosion " .. tostring(words[1]) .. " " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. ((words[2] and words[2] == "1") and " 1" or " 0")

		--Spring.Echo('Spawning unit explosion:', line, playerID, msg)
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ":" .. msg)
	end

	function GiveCat(_, line, words, playerID)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		if not isAuthorized(playerID, "units") then
			return
		end

		-- "tree" mode: /luarules givecat unitname [teamid]
		-- If first word is a known unitdef name, give it + all recursive buildoptions
		if words[1] and UnitDefNames[words[1]] then
			local unitName = words[1]
			local rootDef = UnitDefNames[unitName]
			local collected = {}
			local result = {}
			local function collectBuildOptions(uDefID, depth)
				if depth > 15 or collected[uDefID] then
					return
				end
				collected[uDefID] = true
				result[#result + 1] = uDefID
				local ud = UnitDefs[uDefID]
				if ud and ud.buildOptions then
					for _, boDefID in ipairs(ud.buildOptions) do
						collectBuildOptions(boDefID, depth + 1)
					end
				end
			end
			collectBuildOptions(rootDef.id, 0)
			Spring.Echo("givecat: giving " .. #result .. " unique units from '" .. unitName .. "'")
			if #result == 0 then
				return
			end
			local _, _, _, teamID = Spring.GetPlayerInfo(Spring.GetLocalPlayerID(), false)
			if words[2] and tonumber(words[2]) then
				teamID = tonumber(words[2])
			end
			local mx, my = Spring.GetMouseState()
			local t, pos = Spring.TraceScreenRay(mx, my, true)
			if type(pos) == "table" then
				local x, z = math.floor(pos[1]), math.floor(pos[3])
				local msg = "givecat " .. x .. " " .. z .. " " .. teamID
				for _, uDID in ipairs(result) do
					msg = msg .. " " .. uDID
				end
				Spring.SendLuaRulesMsg(PACKET_HEADER .. ":" .. msg)
			end
			return
		end

		local unitTypes = {}
		local techLevels = {}

		local facSuffix = { --ignore t3
			["veh"] = "vp",
			["bot"] = "lab",
			["ship"] = "sy",
			["hover"] = "hp", --hover are special case, no t2 fac
		}
		local techSuffix = {
			["t1"] = "",
			["t2"] = "a", --t3 added later
		}
		for t, suffix in pairs(facSuffix) do
			local acceptableUDIDs = {}
			for _, uDID in ipairs(UnitDefNames["cor" .. suffix].buildOptions) do
				acceptableUDIDs[uDID] = true
			end
			for _, uDID in ipairs(UnitDefNames["arm" .. suffix].buildOptions) do
				acceptableUDIDs[uDID] = true
			end
			if t ~= "hover" then
				for _, uDID in ipairs(UnitDefNames["arma" .. suffix].buildOptions) do
					acceptableUDIDs[uDID] = true
				end
				for _, uDID in ipairs(UnitDefNames["cora" .. suffix].buildOptions) do
					acceptableUDIDs[uDID] = true
				end
			end
			unitTypes[t] = acceptableUDIDs
		end

		for t, techSuffix in pairs(techSuffix) do
			local acceptableUDIDs = {}
			for t2, facSuffix in pairs(facSuffix) do
				if not (t == "t2" and t2 == "hover") then
					for _, uDID in ipairs(UnitDefNames["cor" .. techSuffix .. facSuffix].buildOptions) do
						acceptableUDIDs[uDID] = true
					end
					for _, uDID in ipairs(UnitDefNames["arm" .. techSuffix .. facSuffix].buildOptions) do
						acceptableUDIDs[uDID] = true
					end
				end
			end
			techLevels[t] = acceptableUDIDs
		end
		local t3Units = {}
		for _, uDID in ipairs(UnitDefNames["corgant"].buildOptions) do
			t3Units[uDID] = true
		end
		for _, uDID in ipairs(UnitDefNames["armshltx"].buildOptions) do
			t3Units[uDID] = true
		end
		techLevels["t3"] = t3Units
		techSuffix["t3"] = "t3"

		local Accept = {} -- table of conditions that must be satisfied for the unitDef to be given

		local function unitHasWeaponMatching(ud, predicate)
			if not ud.weapons then
				return false
			end
			for i = 1, #ud.weapons do
				local weapon = ud.weapons[i]
				local wDef = weapon and WeaponDefs[weapon.weaponDef]
				if wDef and predicate(wDef, weapon) then
					return true
				end
			end
			return false
		end

		local function unitHasWeaponType(ud, wantedType)
			return unitHasWeaponMatching(ud, function(wDef)
				return wDef.type == wantedType
			end)
		end

		local function isDepthchargeWeapon(wDef)
			if not wDef or wDef.type ~= "TorpedoLauncher" then
				return false
			end
			local weaponName = string.lower(wDef.name or "")
			local description = string.lower(wDef.description or "")
			local modelName = string.lower((wDef.visuals and wDef.visuals.modelName) or "")
			return string.find(weaponName, "depth", 1, true) or string.find(description, "depth", 1, true) or string.find(modelName, "depth", 1, true)
		end

		local function isTorpedoWeapon(wDef)
			return wDef and wDef.type == "TorpedoLauncher" and not isDepthchargeWeapon(wDef)
		end

		local function hasRoleTag(ud, role)
			local cp = ud.customParams
			if not cp then
				return false
			end
			local unitgroup = cp.unitgroup and string.lower(cp.unitgroup) or ""
			local unittype = cp.unittype and string.lower(cp.unittype) or ""
			local subfolder = cp.subfolder and string.lower(cp.subfolder) or ""
			return unitgroup == role or unittype == role or string.find(subfolder, role, 1, true)
		end

		local function isNavalUnit(ud)
			if ud.canFly or ud.isBuilding then
				return false
			end
			local cp = ud.customParams
			local subfolder = cp and cp.subfolder and string.lower(cp.subfolder) or ""
			return ud.floatOnWater or (ud.minWaterDepth and ud.minWaterDepth > 0) or string.find(subfolder, "ships", 1, true)
		end

		local function isSubmarineUnit(ud)
			if not isNavalUnit(ud) then
				return false
			end
			return ud.canSubmerge or ud.sonarStealth or string.find(ud.name, "sub", 1, true) or hasRoleTag(ud, "sub")
		end

		local function hasWeaponRangeAtLeast(ud, minRange)
			return unitHasWeaponMatching(ud, function(wDef, weapon)
				if (wDef.range or 0) < minRange then
					return false
				end
				if weapon.onlyTargets and weapon.onlyTargets.vtol and not weapon.onlyTargets.ground then
					return false
				end
				return true
			end)
		end

		local filterWords = {}
		for i = 1, #words do
			if words[i] then
				filterWords[string.lower(words[i])] = true
			end
		end

		local includeUnitDefIDs = {}
		local excludeUnitDefIDs = {}
		for i = 1, #words do
			local token = words[i] and string.lower(words[i])
			if token == "unitdef" or token == "nounitdef" then
				local nextToken = words[i + 1]
				if nextToken then
					local parsed = tonumber((string.gsub(nextToken, "^#", "")))
					if parsed and UnitDefs[parsed] then
						if token == "unitdef" then
							includeUnitDefIDs[parsed] = true
						else
							excludeUnitDefIDs[parsed] = true
						end
					end
				end
			end
		end

		local function addFilter(tokens, condition)
			if type(tokens) == "string" then
				tokens = { tokens }
			end

			local include = false
			local exclude = false
			for i = 1, #tokens do
				local token = tokens[i]
				if filterWords[token] then
					include = true
				end
				if filterWords["no" .. token] then
					exclude = true
				end
			end

			if include then
				Accept[#Accept + 1] = condition
			end
			if exclude then
				Accept[#Accept + 1] = function(ud)
					return not condition(ud)
				end
			end
		end

		-- factions
		addFilter("arm", function(ud)
			return ud.name:sub(1, 3) == "arm" and not string.find(ud.name, "_scav")
		end)
		addFilter("cor", function(ud)
			return ud.name:sub(1, 3) == "cor" and not string.find(ud.name, "_scav")
		end)
		addFilter("leg", function(ud)
			return ud.name:sub(1, 3) == "leg" and not string.find(ud.name, "_scav")
		end)
		addFilter("scav", function(ud)
			return string.find(ud.name, "_scav")
		end)
		addFilter("raptor", function(ud)
			return string.find(ud.name, "raptor")
		end)

		-- unit types
		for t, _ in pairs(facSuffix) do
			local tKey = t
			addFilter(tKey, function(ud)
				return unitTypes[tKey][ud.id]
			end)
		end

		-- tech levels
		for t, _ in pairs(techSuffix) do
			local tKey = t
			addFilter(tKey, function(ud)
				return techLevels[tKey][ud.id]
			end)
		end

		-- other cats
		addFilter({ "con", "builder" }, function(ud)
			return ud.isBuilder
		end)
		addFilter("mex", function(ud)
			return ud.isExtractor
		end)
		addFilter({ "trans", "transport" }, function(ud)
			return ud.isTransport
		end)
		addFilter("fac", function(ud)
			return ud.isFactory
		end)
		addFilter("building", function(ud)
			return ud.isBuilding
		end)
		addFilter("air", function(ud)
			return ud.canFly
		end)
		addFilter("gunship", function(ud)
			return ud.canFly and ud.hoverAttack
		end)
		addFilter("airtransport", function(ud)
			return ud.canFly and ud.isTransport
		end)
		addFilter("amphib", function(ud)
			if ud.canFly or ud.isBuilding or isNavalUnit(ud) then
				return false
			end
			return (ud.maxWaterDepth or 0) > 0 or hasRoleTag(ud, "amph")
		end)
		addFilter("submarine", function(ud)
			return isSubmarineUnit(ud)
		end)
		addFilter("watersurface", function(ud)
			return isNavalUnit(ud) and not isSubmarineUnit(ud)
		end)
		addFilter("water", function(ud)
			return isNavalUnit(ud)
		end)
		addFilter("mobile", function(ud)
			return not ud.isBuilding
		end)
		addFilter("scout", function(ud)
			return hasRoleTag(ud, "scout") or (not ud.isBuilding and ((ud.losRadius or 0) >= 700 or (ud.radarDistance or 0) >= 1800))
		end)
		addFilter({ "artillery", "arty" }, function(ud)
			-- Strategic nukes are handled by the dedicated nuke filter, not artillery.
			if unitHasWeaponMatching(ud, function(wDef)
				return wDef.targetable == 1
			end) then
				return false
			end

			-- Exclude bomber-class aircraft from artillery.
			if ud.canFly and not ud.hoverAttack and unitHasWeaponMatching(ud, function(wDef)
				return wDef.type == "AircraftBomb" or wDef.type == "TorpedoLauncher"
			end) then
				return false
			end

			-- Exclude drone carriers and units that spawn carried drones.
			local cp = ud.customParams
			if (cp and cp.flyingcarrier) or string.find(ud.name, "dronecarry", 1, true) then
				return false
			end
			if unitHasWeaponMatching(ud, function(wDef)
				local wcp = wDef.customParams
				return wcp and wcp.carried_unit
			end) then
				return false
			end

			return hasRoleTag(ud, "arty") or hasRoleTag(ud, "artillery") or hasWeaponRangeAtLeast(ud, 900)
		end)
		addFilter("riot", function(ud)
			if hasRoleTag(ud, "riot") then
				return true
			end
			if ud.isBuilding or ud.isBuilder then
				return false
			end
			return unitHasWeaponMatching(ud, function(wDef, weapon)
				if weapon.onlyTargets and weapon.onlyTargets.vtol and not weapon.onlyTargets.ground then
					return false
				end
				if (wDef.range or 0) > 520 then
					return false
				end
				return (wDef.damageAreaOfEffect or 0) >= 72
			end)
		end)
		addFilter("skirmish", function(ud)
			return hasRoleTag(ud, "skirm") or hasRoleTag(ud, "skirmish")
		end)
		addFilter("assault", function(ud)
			if hasRoleTag(ud, "assault") then
				return not ud.isBuilder
			end
			return not ud.isBuilding and not ud.canFly and not ud.isBuilder and (ud.health or 0) >= 2500
		end)
		addFilter("weapon", function(ud)
			return unitHasWeaponMatching(ud, function()
				return true
			end)
		end)
		addFilter("laser", function(ud)
			return unitHasWeaponType(ud, "LaserCannon") or unitHasWeaponType(ud, "BeamLaser")
		end)
		addFilter("plasma", function(ud)
			return unitHasWeaponType(ud, "Cannon")
		end)
		addFilter("missile", function(ud)
			return unitHasWeaponType(ud, "MissileLauncher")
		end)
		addFilter("depthcharge", function(ud)
			return unitHasWeaponMatching(ud, function(wDef)
				return isDepthchargeWeapon(wDef)
			end)
		end)
		addFilter("torpedo", function(ud)
			return unitHasWeaponMatching(ud, function(wDef)
				return isTorpedoWeapon(wDef)
			end)
		end)
		addFilter("starburst", function(ud)
			return unitHasWeaponType(ud, "StarburstLauncher")
		end)
		addFilter("flame", function(ud)
			return unitHasWeaponType(ud, "Flame")
		end)
		addFilter("lightning", function(ud)
			return unitHasWeaponType(ud, "LightningCannon")
		end)
		addFilter("paralyzer", function(ud)
			return unitHasWeaponMatching(ud, function(wDef)
				return wDef.paralyzer
			end)
		end)
		addFilter("emp", function(ud)
			return unitHasWeaponMatching(ud, function(wDef)
				return wDef.paralyzer
			end)
		end)
		addFilter("interceptor", function(ud)
			return unitHasWeaponMatching(ud, function(wDef)
				return wDef.interceptor and wDef.interceptor > 0
			end)
		end)
		addFilter("shield", function(ud)
			return unitHasWeaponMatching(ud, function(wDef)
				return wDef.isShield or (wDef.shieldRadius and wDef.shieldRadius > 0)
			end)
		end)
		addFilter("antinuke", function(ud)
			return unitHasWeaponMatching(ud, function(wDef)
				return wDef.interceptor == 1
			end)
		end)
		addFilter("nuke", function(ud)
			return unitHasWeaponMatching(ud, function(wDef)
				return wDef.targetable == 1
			end)
		end)
		addFilter("aa", function(ud)
			local cp = ud.customParams
			return cp and cp.unitgroup == "aa"
		end)
		addFilter("aa-all", function(ud)
			return unitHasWeaponMatching(ud, function(_, weapon)
				return weapon.onlyTargets and weapon.onlyTargets.vtol
			end)
		end)
		addFilter("bomber", function(ud)
			if not ud.canFly or ud.hoverAttack then
				return false
			end
			return unitHasWeaponMatching(ud, function(wDef)
				return wDef.type == "AircraftBomb" or wDef.type == "TorpedoLauncher"
			end)
		end)
		addFilter("fighter", function(ud)
			if not ud.canFly or ud.hoverAttack or ud.isTransport or ud.isBuilder then
				return false
			end
			if unitHasWeaponMatching(ud, function(wDef)
				return wDef.type == "AircraftBomb" or wDef.type == "TorpedoLauncher"
			end) then
				return false
			end
			return unitHasWeaponMatching(ud, function(_, weapon)
				return weapon.onlyTargets and weapon.onlyTargets.vtol
			end)
		end)
		addFilter("cloak", function(ud)
			return ud.canCloak
		end)
		addFilter("hoverattack", function(ud)
			return ud.hoverAttack
		end)
		addFilter("stealth", function(ud)
			return ud.stealth or ud.sonarStealth
		end)
		addFilter("commander", function(ud)
			local cp = ud.customParams
			return cp and (cp.iscommander or cp.isscavcommander)
		end)
		addFilter("decoy", function(ud)
			local cp = ud.customParams
			return cp and (cp.decoyfor or cp.isdecoycommander)
		end)
		addFilter("resurrect", function(ud)
			return ud.canResurrect
		end)
		addFilter("object", function(ud)
			local cp = ud.customParams
			local isObjectCategory = ud.modCategories and ud.modCategories["object"]
			return isObjectCategory or (cp and cp.objectify)
		end)
		addFilter("objectify", function(ud)
			local cp = ud.customParams
			return cp and cp.objectify
		end)
		addFilter("collide", function(ud)
			return ud.collide ~= false
		end)
		addFilter("utility", function(ud)
			local cp = ud.customParams
			return cp and cp.unitgroup == "util"
		end)
		addFilter("startunit", function(ud)
			if ud.name == "armcom" or ud.name == "corcom" or ud.name == "legcom" then
				return true
			end
			return false
		end)
		addFilter("capture", function(ud)
			return ud.canCapture
		end)
		addFilter("seismic", function(ud)
			return (ud.seismicDistance or ud.seismicdistance or 0) > 0
		end)
		addFilter("seismicsignature", function(ud)
			return (ud.seismicSignature or ud.seismicsignature or 0) > 0
		end)
		addFilter("radar", function(ud)
			return (ud.radarDistance or ud.radarradius or 0) > 1400
		end)
		addFilter("jammer", function(ud)
			return (ud.radarDistanceJam or ud.jammerRadius or ud.jammerradius or 0) > 1
		end)
		addFilter("sonar", function(ud)
			return (ud.sonarDistance or ud.sonarRadius or ud.sonarradius or 0) > 700
		end)
		addFilter("onoffable", function(ud)
			return ud.onOffable
		end)
		addFilter("stockpile", function(ud)
			return ud.canStockpile
		end)
		addFilter("energy", function(ud)
			local cp = ud.customParams
			local name = string.lower(ud.name or "")
			return (ud.energyMake or 0) > 0 or (ud.windGenerator or 0) > 0 or (ud.tidalGenerator or 0) > 0 or (cp and cp.unitgroup == "energy") or string.find(name, "solar", 1, true) or string.find(name, "wind", 1, true) or string.find(name, "fusion", 1, true) or string.find(name, "geo", 1, true)
		end)
		addFilter("energyconvert", function(ud)
			local cp = ud.customParams
			return cp and (tonumber(cp.energyconv_capacity) or 0) > 0 and (tonumber(cp.energyconv_efficiency) or 0) > 0
		end)
		addFilter("metal", function(ud)
			local cp = ud.customParams
			return ud.isExtractor or (ud.extractsMetal or 0) > 0 or (ud.metalMake or 0) > 0 or (cp and cp.unitgroup == "metal")
		end)
		addFilter("all", function()
			return true
		end)

		if next(includeUnitDefIDs) then
			Accept[#Accept + 1] = function(ud)
				return includeUnitDefIDs[ud.id]
			end
		end
		if next(excludeUnitDefIDs) then
			Accept[#Accept + 1] = function(ud)
				return not excludeUnitDefIDs[ud.id]
			end
		end

		if #Accept == 0 then
			Spring.Echo("givecat: no valid filters given")
			return
		end

		-- team
		local _, _, _, teamID = Spring.GetPlayerInfo(Spring.GetLocalPlayerID(), false)
		if string.match(line, " ([0-9].*)") then
			teamID = string.match(line, " ([0-9].*)")
		end

		-- give units
		local exlusions = { meteor = true, raptor_hive = true, nuketest = true, nuketestcor = true, nuketestcororg = true, nuketestorg = true, scavtacnukespawner = true, scavempspawner = true }
		local newExlusions = {}
		for k, v in pairs(exlusions) do
			newExlusions[k] = true
			newExlusions[k .. "_scav"] = true
		end
		exlusions = newExlusions
		newExlusions = nil
		local giveUnits = {}
		for _, ud in pairs(UnitDefs) do
			local give = true
			for _, Condition in ipairs(Accept) do
				if not Condition(ud) or exlusions[ud.name] then
					give = false
					break
				end
			end
			if give then
				giveUnits[#giveUnits + 1] = ud.id
			end
		end

		Spring.Echo("givecat found " .. #giveUnits .. " units")
		if #giveUnits == 0 then
			return
		end

		local mx, my = Spring.GetMouseState()
		local t, pos = Spring.TraceScreenRay(mx, my, true)
		if type(pos) == "table" then
			local n = 0
			local ox, oz = math.floor(pos[1]), math.floor(pos[3])
			local x, z = ox, oz

			local msg = "givecat " .. x .. " " .. z .. " " .. teamID
			for _, uDID in ipairs(giveUnits) do
				msg = msg .. " " .. uDID
			end

			Spring.SendLuaRulesMsg(PACKET_HEADER .. ":" .. msg)
		end
	end
end
