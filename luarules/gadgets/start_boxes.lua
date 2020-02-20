if not gadgetHandler:IsSyncedCode() or VFS.FileExists("mission.lua") then return end

function gadget:GetInfo() return {
	name     = "Startbox handler",
	desc     = "Handles startboxes",
	author   = "Sprung",
	date     = "2015-05-19",
	license  = "PD",
	layer    = -math.huge + 10,
	enabled  = true,
} end

local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID(), false))
local shuffleMode = Spring.GetModOptions().shuffle or "auto"
local startboxConfig

local ParseBoxes = VFS.Include ("LuaRules/Gadgets/Include/startbox_utilities.lua")

local function GetAverageStartpoint(boxID)
	local box = startboxConfig[boxID]
	local startpoints = box.startpoints

	local x, z = 0, 0
	for i = 1, #startpoints do
		x = x + startpoints[i][1]
		z = z + startpoints[i][2]
	end
	x = x / #startpoints
	z = z / #startpoints
	
	return x, z
end

local function RegtangularizeTrapezoid(edgeA, edgeB)
	local vector = Spring.Utilities.Vector
	local origin = edgeA[1]
	local unit = vector.Unit(vector.Subtract(edgeA[2], edgeA[1]))

	if (edgeA[1][1] < edgeA[1][2]) ~= (edgeB[1][1] < edgeB[1][2]) then
		-- Swap points if lines are passed backwards
		edgeB[1], edgeB[2] = edgeB[2], edgeB[1]
	end
	
	local distANear, distAFar = 0, vector.AbsVal(vector.Subtract(edgeA[2], edgeA[1]))
	local distBNear, distBFar = vector.Dot(vector.Subtract(edgeB[1], edgeA[1]), unit), vector.Dot(vector.Subtract(edgeB[2], edgeA[1]), unit)
	
	local nearDist, farDist = math.max(distANear, distBNear), math.min(distAFar, distBFar)
	
	edgeA[1] = vector.Add(origin, vector.Mult(nearDist, unit))
	edgeA[2] = vector.Add(origin, vector.Mult(farDist, unit))
	local normal = vector.Normal(vector.Subtract(edgeB[1], edgeA[1]), unit)
	return {edgeA[1], vector.Subtract(edgeA[2], edgeA[1]), normal}
end

local function GetBoxID(allyTeamID)
	local teamID = Spring.GetTeamList(allyTeamID)[1]
	if not teamID then
		return
	end
	local boxID = Spring.GetTeamRulesParam(teamID, "start_box_id")
	return boxID
end

local function GetPlanetwarsBoxes (teamDistance, teamWidth, neutralWidth, edgeDist)
	local attackerBoxID = GetBoxID(0)
	local defenderBoxID = GetBoxID(1)
	if not attackerBoxID or not defenderBoxID then
		return
	end

	local attackerX, attackerZ = GetAverageStartpoint(attackerBoxID)
	local defenderX, defenderZ = GetAverageStartpoint(defenderBoxID)

	local function GetPointOnLine(distance)
		return {
			defenderX + distance * (attackerX - defenderX),
			defenderZ + distance * (attackerZ - defenderZ),
		}
	end

	local defenderBoxStart = GetPointOnLine(teamDistance)
	local attackerBoxStart = GetPointOnLine(1 - teamDistance)
	local middleBoxStart   = GetPointOnLine(0.5 - (neutralWidth / 2))
	
	local defenderBoxEnd = GetPointOnLine(teamDistance + teamWidth)
	local attackerBoxEnd = GetPointOnLine(1 - (teamDistance + teamWidth))
	local middleBoxEnd   = GetPointOnLine(0.5 + (neutralWidth / 2))

	local function GetBasicRectangle(pointA, pointB, isX)
		if isX then
			return {
				{edgeDist, pointA[2]},
				{0, pointB[2] - pointA[2]},
				{Game.mapSizeX - 2*edgeDist, 0},
			}
		else
			return {
				{pointA[1], edgeDist},
				{0, Game.mapSizeZ - 2*edgeDist},
				{pointB[1] - pointA[1], 0},
			}
		end
	end
	
	if math.abs(defenderX - attackerX) < 10 or math.abs(defenderZ - attackerZ) < 10 then
		local isX = math.abs(defenderX - attackerX) < 10
		return {
			attacker = GetBasicRectangle(attackerBoxStart, attackerBoxEnd, isX),
			defender = GetBasicRectangle(defenderBoxStart, defenderBoxEnd, isX),
			neutral = GetBasicRectangle(middleBoxStart, middleBoxEnd, isX),
		}
	end
	
	-- Note that the gradient is perpendicular to the gradient Attacker-Defender line.
	local gradient = (attackerX - defenderX) / (defenderZ - attackerZ)
	
	local function GetEdgePoints(point)
		local offset = point[2] - (gradient * point[1])
		
		local left = {
			edgeDist,
			(gradient * edgeDist) + offset,
		}
		if left[2] < edgeDist then
			left[1] = (edgeDist - offset) / gradient
			left[2] = edgeDist
		elseif left[2] > Game.mapSizeZ - edgeDist then
			left[1] = ((Game.mapSizeZ - edgeDist) - offset) / gradient
			left[2] = Game.mapSizeZ - edgeDist
		end
		
		local right = {
			Game.mapSizeX - edgeDist,
			(gradient * (Game.mapSizeX - edgeDist)) + offset,
		}
		if right[2] < edgeDist then
			right[1] = (edgeDist - offset) / gradient
			right[2] = edgeDist
		elseif right[2] > Game.mapSizeZ - edgeDist then
			right[1] = ((Game.mapSizeZ - edgeDist) - offset) / gradient
			right[2] = Game.mapSizeZ - edgeDist
		end
		
		return {left, right}
	end

	local function GetRectangle(pointA, pointB)
		local edgesA = GetEdgePoints(pointA)
		local edgesB = GetEdgePoints(pointB)
		
		return RegtangularizeTrapezoid(edgesA, edgesB)
	end

	return {
		attacker = GetRectangle(attackerBoxStart, attackerBoxEnd),
		defender = GetRectangle(defenderBoxStart, defenderBoxEnd),
		neutral = GetRectangle(middleBoxStart, middleBoxEnd),
	}
end

local function CheckStartbox (boxID, x, z)
	if not boxID then
		return true
	end

	local box = startboxConfig[boxID] and startboxConfig[boxID].boxes
	if not box then
		return true
	end

	for i = 1, #box do
		local x1, z1, x2, z2, x3, z3 = unpack(box[i])
		if (math.cross_product(x, z, x1, z1, x2, z2) <= 0
		and math.cross_product(x, z, x2, z2, x3, z3) <= 0
		and math.cross_product(x, z, x3, z3, x1, z1) <= 0
		) then
			return true
		end
	end

	return false
end

-- name, elo, clanShort, clanLong, isAI
local function GetPlayerInfo (teamID)
	local _,playerID,_,isAI = Spring.GetTeamInfo(teamID, false)

	if isAI then
		return select(2, Spring.GetAIInfo(teamID)), -1000, "", "", true
	end

	local name = Spring.GetPlayerInfo(playerID, false) or "?"
	local customKeys = select(10, Spring.GetPlayerInfo(playerID)) or {}
	local clanShort = customKeys.clan     or ""
	local clanLong  = customKeys.clanfull or ""
	local elo       = customKeys.elo      or "0"
	return name, tonumber(elo), clanShort, clanLong, false
end

-- returns full name, short name, clan full name, clan short name
local function GetTeamNames (allyTeamID)
	if allyTeamID == gaiaAllyTeamID then
		return "Neutral", "Neutral" -- more descriptive than "Gaia"
	end

	local pwPlanet = Spring.GetModOptions().planet
	if pwPlanet then
		if allyTeamID == 0 then -- attacker is always 0, and always present
			local shortName = Spring.GetModOptions().attackingfaction
			local longName = Spring.GetModOptions().attackingfactionname
			return longName, shortName
		else
			local defenderShortName = Spring.GetModOptions().defendingfaction
			if not defenderShortName then -- attacking a neutral planet
				local longName = pwPlanet .. " Militia"
				return longName, "Militia"
			else
				local longName = Spring.GetModOptions().defendingfactionname
				return longName, defenderShortName
			end
		end
	end

	local teamList = Spring.GetTeamList(allyTeamID) or {}
	if #teamList == 0 then
		return "Empty", "Empty"
	end

	local clanShortName, clanLongName
	local clanFirst = true
	local leaderName = ""
	local leaderElo = -2000
	local bots = 0
	local humans = 0
	for i = 1, #teamList do
		local name, elo, clanShort, clanLong, isAI = GetPlayerInfo(teamList[i])
		if not isAI then
			if clanFirst then
				clanShortName = clanShort
				clanLongName  = clanLong
				clanFirst = false
			else
				if clanShort ~= clanShortName then
					clanShortName = ""
					clanLongName = ""
				end
			end
		end

		if elo > leaderElo then
			leaderName = name
			leaderElo = elo
		end

		if isAI then
			bots = bots + 1
		else
			humans = humans + 1
		end
	end

	if humans == 1 then
		return leaderName, leaderName
	end

	if humans == 0 then
		return "AI", "AI"
	end

	local boxCount = 0
	for _ in pairs(startboxConfig) do
		boxCount = boxCount + 1
	end

	if ((shuffleMode == "off")
		or (Spring.Utilities.GetTeamCount() == 2 and shuffleMode == "shuffle")
		or (boxCount == 2 and shuffleMode == "allshuffle"))
	then
		local boxID = Spring.GetTeamRulesParam(teamList[1], "start_box_id")
		if boxID then
			local box = startboxConfig[boxID]
			if box.nameLong and box.nameShort then
				return box.nameLong, box.nameShort, clanLongName, clanShortName
			end
		end
	end

	return ("Team " .. leaderName), leaderName, clanLongName, clanShortName
end

function gadget:Initialize()
	if shuffleMode == "auto" then
		if Spring.Utilities.GetTeamCount() > 2 then
			shuffleMode = "shuffle"
		elseif Spring.Utilities.GetTeamCount() == 2 then
			shuffleMode = "allshuffle"
		else
			-- 1 team: chickens
			shuffleMode = "off"
		end
	end
	Spring.SetGameRulesParam("shuffleMode", shuffleMode)

	startboxConfig = ParseBoxes()

	GG.startBoxConfig = startboxConfig
	GG.GetPlanetwarsBoxes = GetPlanetwarsBoxes
	GG.CheckStartbox = CheckStartbox

	Spring.SetGameRulesParam("startbox_max_n", #startboxConfig)
	Spring.SetGameRulesParam("startbox_recommended_startpos", 1)

	for box_id, rawbox in pairs(startboxConfig) do
		local polygons = rawbox.boxes
		Spring.SetGameRulesParam("startbox_n_" .. box_id, #polygons)
		for i = 1, #polygons do
			local polygon = polygons[i]
			Spring.SetGameRulesParam("startbox_polygon_" .. box_id .. "_" .. i, #polygons[i])
			for j = 1, #polygons[i] do
				Spring.SetGameRulesParam("startbox_polygon_x_" .. box_id .. "_" .. i .. "_" .. j, polygons[i][j][1])
				Spring.SetGameRulesParam("startbox_polygon_z_" .. box_id .. "_" .. i .. "_" .. j, polygons[i][j][2])
			end
		end

		local startposes = rawbox.startpoints
		Spring.SetGameRulesParam("startpos_n_" .. box_id, #startposes)
		for i = 1, #startposes do
			Spring.SetGameRulesParam("startpos_x_" .. box_id .. "_" .. i, startposes[i][1])
			Spring.SetGameRulesParam("startpos_z_" .. box_id .. "_" .. i, startposes[i][2])
		end
	end

	for id, rawbox in pairs(startboxConfig) do
		rawbox.boxes = math.triangulate(rawbox.boxes)
	end

	-- filter out fake teams (empty or Gaia)
	local allyTeamList = Spring.GetAllyTeamList()
	local actualAllyTeamList = {}
	for i = 1, #allyTeamList do
		local teamList = Spring.GetTeamList(allyTeamList[i]) or {}
		if ((#teamList > 0) and (allyTeamList[i] ~= gaiaAllyTeamID)) then
			actualAllyTeamList[#actualAllyTeamList+1] = {allyTeamList[i], math.random()}
		end
	end

	if (shuffleMode == "off") or (shuffleMode == "disable") then

		for i = 1, #allyTeamList do
			local allyTeamID = allyTeamList[i]
			local boxID = allyTeamList[i]
			if startboxConfig[boxID] then
				local teamList = Spring.GetTeamList(allyTeamID) or {}
				for j = 1, #teamList do
					Spring.SetTeamRulesParam(teamList[j], "start_box_id", boxID)
				end
			end
		end

	elseif (shuffleMode == "shuffle") then

		local randomizedSequence = {}
		for i = 1, #actualAllyTeamList do
			randomizedSequence[#randomizedSequence + 1] = {actualAllyTeamList[i][1], math.random()}
		end
		table.sort(randomizedSequence, function(a, b) return (a[2] < b[2]) end)

		for i = 1, #actualAllyTeamList do
			local allyTeamID = actualAllyTeamList[i][1]
			local boxID = randomizedSequence[i][1]
			if startboxConfig[boxID] then
				local teamList = Spring.GetTeamList(allyTeamID) or {}
				for j = 1, #teamList do
					Spring.SetTeamRulesParam(teamList[j], "start_box_id", boxID)
				end
			end
		end

	elseif (shuffleMode == "allshuffle") then

		local randomizedSequence = {}
		for id in pairs(startboxConfig) do
			randomizedSequence[#randomizedSequence + 1] = {id, math.random()}
		end
		table.sort(randomizedSequence, function(a, b) return (a[2] < b[2]) end)
		table.sort(actualAllyTeamList, function(a, b) return (a[2] < b[2]) end)

		for i = 1, #actualAllyTeamList do
			local allyTeamID = actualAllyTeamList[i][1]
			local boxID = randomizedSequence[i] and randomizedSequence[i][1]
			if boxID and startboxConfig[boxID] then
				local teamList = Spring.GetTeamList(allyTeamID) or {}
				for j = 1, #teamList do
					Spring.SetTeamRulesParam(teamList[j], "start_box_id", boxID)
				end
			end
		end
	end

	local clans = {}
	for i = 1, #allyTeamList do
		local allyTeamID = allyTeamList[i]
		local longName, shortName, clanLong, clanShort = GetTeamNames(allyTeamID)
		Spring.SetGameRulesParam("allyteam_short_name_" .. allyTeamID, shortName)
		Spring.SetGameRulesParam("allyteam_long_name_"  .. allyTeamID, longName)
		if clanLong and clanLong ~= "" then
			clans[clanLong] = clans[clanLong] or {0, clanShort, allyTeamID}
			clans[clanLong][1] = clans[clanLong][1] + 1
		end
	end

	for clanName, clan in pairs(clans) do
		if (clan[1] == 1) and (clanName ~= "") then
			Spring.SetGameRulesParam("allyteam_short_name_" .. clan[3], clan[2])
			Spring.SetGameRulesParam("allyteam_long_name_"  .. clan[3], clanName)
		end
	end
end

function gadget:AllowStartPosition(playerID, teamID, readyState, x, y, z, rx, ry, rz)
	if (x == 0 and z == 0) then
		-- engine default startpos
		return false
	end

	if (playerID == 255) then
		return true -- custom AI, can't know which team it is on so allow it to place anywhere for now and filter invalid positions later
	end

	local teamID = select(4, Spring.GetPlayerInfo(playerID, false))

	if (shuffleMode == "disable") then
		-- note this is after the AI check; toasters still have to obey
		Spring.SetTeamRulesParam (teamID, "valid_startpos", 1)
		return true
	end

	local boxID = Spring.GetTeamRulesParam(teamID, "start_box_id")

	if (not boxID) or CheckStartbox(boxID, x, z) then
		Spring.SetTeamRulesParam (teamID, "valid_startpos", 1)
		return true
	else
		return false
	end
end

function gadget:RecvSkirmishAIMessage(teamID, dataStr)
	local command = "ai_is_valid_startpos:"
	local command2 = "ai_is_valid_enemy_startpos:"
	if not dataStr:find(command,1,true) and not dataStr:find(command2,1,true) then return end
	
	if dataStr:find(command2,1,true) then
		command = command2
	end

	local boxID = Spring.GetTeamRulesParam(teamID, "start_box_id")

	local xz = dataStr:sub(command:len()+1)
	local slash = xz:find("/",1,true)
	if not slash then return end

	local x = tonumber(xz:sub(1, slash-1))
	local z = tonumber(xz:sub(slash+1))
	if not x or not z then return end

	if not dataStr:find(command2,1,true) then
		-- for checking own startpos
		if (not boxID) or CheckStartbox(boxID, x, z) then
			return "1"
		else
			return "0"
		end
	else
		-- for checking enemy startpos
		local enemyboxes = {}
		local _,_,_,_,_,allyteamid = Spring.GetTeamInfo(teamID, false)
		local allyteams = Spring.GetAllyTeamList()
		
		if shuffleMode == "allshuffle" then
			for id,_ in pairs(startboxConfig) do
				if id ~= boxID then
					enemyboxes[id] = true
				end
			end
		else
			for _,value in pairs(allyteams) do
				if value ~= allyteamid then
					local enemyteams = Spring.GetTeamList(value)
					local _,value1 = next(enemyteams)
					if value1 then
						local enemybox = Spring.GetTeamRulesParam(value1, "start_box_id")
						if (enemybox) then
							enemyboxes[enemybox] = true
						end
					end
				end
			end
		end
		
		for bid,_ in pairs(enemyboxes) do
			if CheckStartbox(bid, x, z) then
				return "1"
			end
		end
		return "0"
	end
end
