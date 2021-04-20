function widget:GetInfo()
	return {
		name = "BuildETA",
		desc = "Displays estimated time of arrival for builds",
		author = "trepan (modified by jK)",
		date = "2007",
		license = "GNU GPL, v2 or later",
		layer = -9,
		enabled = true  --  loaded by default?
	}
end

local lastGameUpdate = Spring.GetGameSeconds()

local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetGameSeconds = Spring.GetGameSeconds
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetSpectatingState = Spring.GetSpectatingState
local spec, fullview = spGetSpectatingState()

local myAllyTeam = Spring.GetMyAllyTeamID()

local gl = gl  --  use a local copy for faster access
local Spring = Spring

local font, chobbyInterface

local etaTable = {}
local etaMaxDist = 750000 -- max dist at which to draw ETA

function widget:ViewResize()
	font = WG['fonts'].getFont(nil, 1, 0.2, 1.3)
end

local function makeETA(unitID, unitDefID)
	if unitDefID == nil then
		return nil
	end
	local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
	if buildProgress == nil then
		return nil
	end

	return {
		firstSet = true,
		lastTime = spGetGameSeconds(),
		lastProg = buildProgress,
		rate = nil,
		timeLeft = nil,
		yoffset = UnitDefs[unitDefID].height + 14
	}
end

local function init()
	etaTable = {}
	local units = Spring.GetAllUnits()
	for i=1, #units do
		local unitID = units[i]

		if fullview or spGetUnitAllyTeam(unitID) == myAllyTeam then
			etaTable[unitID] = makeETA(unitID, Spring.GetUnitDefID(unitID))
		end
	end
end

function widget:Initialize()
	widget:ViewResize()
	init()
end

function widget:Update(dt)
	if chobbyInterface then
		return
	end

	local userSpeed, _, pause = Spring.GetGameSpeed()
	if pause then
		return
	end

	local gs = spGetGameSeconds()
	if gs == lastGameUpdate then
		return
	end
	lastGameUpdate = gs

	local killTable = {}
	local count = 0
	for unitID, bi in pairs(etaTable) do
		local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
		if not buildProgress or buildProgress >= 1.0 then
			count = count + 1
			killTable[count] = unitID
		else
			local dp = buildProgress - bi.lastProg
			local dt = gs - bi.lastTime
			if dt > 2 then
				bi.firstSet = true
				bi.rate = nil
				bi.timeLeft = nil
			end

			local rate = (dp / dt) * userSpeed

			if rate ~= 0 then
				if bi.firstSet then
					if (buildProgress > 0.001) then
						bi.firstSet = false
					end
				else
					local rf = 0.5
					if bi.rate == nil then
						bi.rate = rate
					else
						bi.rate = ((1 - rf) * bi.rate) + (rf * rate)
					end

					local tf = 0.1
					if rate > 0 then
						local newTime = (1 - buildProgress) / rate
						if bi.timeLeft and bi.timeLeft > 0 then
							bi.timeLeft = ((1 - tf) * bi.timeLeft) + (tf * newTime)
						else
							bi.timeLeft = (1 - buildProgress) / rate
						end
					elseif rate < 0 then
						local newTime = buildProgress / rate
						if bi.timeLeft and bi.timeLeft < 0 then
							bi.timeLeft = ((1 - tf) * bi.timeLeft) + (tf * newTime)
						else
							bi.timeLeft = buildProgress / rate
						end
					end
				end
				bi.lastTime = gs
				bi.lastProg = buildProgress
			end
		end
	end

	for _, unitID in pairs(killTable) do
		etaTable[unitID] = nil
	end
end

function widget:PlayerChanged()
	if myAllyTeam ~= Spring.GetMyAllyTeamID() or fullview ~= select(2, spGetSpectatingState()) then
		myAllyTeam = Spring.GetMyAllyTeamID()
		spec, fullview = spGetSpectatingState()
		init()
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if fullview or spGetUnitAllyTeam(unitID) == myAllyTeam then
		etaTable[unitID] = makeETA(unitID, unitDefID)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	etaTable[unitID] = nil
end

function widgetHandler:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	etaTable[unitID] = nil
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	etaTable[unitID] = nil
end

local function drawEtaText(timeLeft, yoffset)
	local etaText
	local etaPrefix = "\255\255\255\1" .. Spring.I18N('ui.buildEstimate.time') .. "\255\255\255\255:"
	if timeLeft == nil then
		etaText = etaPrefix .. "\255\1\1\255???"
	else
		local minutes = timeLeft / 60
		local seconds = timeLeft % 60
		etaText = etaPrefix .. string.format("\255\1\255\1%02d:%02d", minutes, seconds)
	end

	gl.Translate(0, yoffset, 10)
	gl.Billboard()
	gl.Translate(0, 5, 0)
	font:Begin()
	font:Print(etaText, 0, 0, 5.75, "co")
	font:End()
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorld()
	if chobbyInterface then
		return
	end
	if Spring.IsGUIHidden() == false then
		gl.DepthTest(true)

		gl.Color(1, 1, 1, 0.1)
		local cx, cy, cz = Spring.GetCameraPosition()
		for unitID, bi in pairs(etaTable) do
			local ux, uy, uz = spGetUnitViewPosition(unitID)
			if ux ~= nil then
				local dx, dy, dz = ux - cx, uy - cy, uz - cz
				local dist = dx * dx + dy * dy + dz * dz
				if dist < etaMaxDist then
					gl.DrawFuncAtUnit(unitID, false, drawEtaText, bi.timeLeft, bi.yoffset)
				end
			end
		end

		gl.Color(1, 1, 1, 1)
		gl.DepthTest(false)
	end
end
