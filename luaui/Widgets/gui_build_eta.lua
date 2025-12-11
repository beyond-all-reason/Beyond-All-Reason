local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "BuildETA",
		desc = "Displays estimated time of arrival for builds",
		author = "trepan (modified by jK)",
		date = "2007",
		license = "GNU GPL, v2 or later",
		layer = -9,
		enabled = true
	}
end

local lastGameUpdate = Spring.GetGameSeconds()

local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetGameSeconds = Spring.GetGameSeconds
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetSpectatingState = Spring.GetSpectatingState
local spec, fullview = spGetSpectatingState()
local myAllyTeam = Spring.GetMyAllyTeamID()

local glColor = gl.Color
local glDepthTest = gl.DepthTest
local glDrawFuncAtUnit = gl.DrawFuncAtUnit
local glBillboard = gl.Billboard
local glTranslate = gl.Translate

local font

local etaTable = {}
local etaMaxDist = 750000 -- max dist at which to draw ETA
local blinkTime = 20

local unitHeight = {}
for udid, unitDef in pairs(UnitDefs) do
	unitHeight[udid] = unitDef.height
end


function widget:ViewResize()
	font = WG['fonts'].getFont(nil, 1.2, 0.2, 20)
end

local function makeETA(unitID, unitDefID)
	if unitDefID == nil then
		return nil
	end
	local isBuilding, buildProgress = spGetUnitIsBeingBuilt(unitID)
	if not isBuilding  then
		return nil
	end

	return {
		firstSet = true,
		lastTime = spGetGameSeconds(),
		lastProg = buildProgress,
		rate = nil,
		timeLeft = nil,
		yoffset = unitHeight[unitDefID] + 14
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

	local gs = spGetGameSeconds()
	if gs == lastGameUpdate then
		return
	end
	lastGameUpdate = gs

	local killTable = {}
	local count = 0
	for unitID, bi in pairs(etaTable) do
		local isBuilding, buildProgress = spGetUnitIsBeingBuilt(unitID)
		if not isBuilding then
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

			local rate = dp / dt

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
						local newTime = buildProgress / bi.rate -- use smooth rate
						if bi.timeLeft and bi.timeLeft < 0 then
							bi.timeLeft = newTime -- we don't need to smoothen the time if the rate is smooth
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

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	etaTable[unitID] = nil
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	etaTable[unitID] = nil
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	etaTable[unitID] = nil
end

local function drawEtaText(timeLeft, yoffset)
	local etaText
	local etaPrefix = "\255\255\255\1" .. Spring.I18N('ui.buildEstimate.time') .. "\255\255\255\255 "
	if timeLeft == nil then
		etaText = etaPrefix .. "\255\1\1\255???"
	else
		local canceled = timeLeft<0
		etaPrefix = (not canceled and etaPrefix) or (((spGetGameFrame()%blinkTime>=blinkTime/2) and "\255\255\255\255" or"\255\255\1\1")..Spring.I18N('ui.buildEstimate.cancelled').." ")
		timeLeft = math.abs(timeLeft)
		local minutes = timeLeft / 60
		local seconds = timeLeft % 60
		etaText = etaPrefix .. string.format((not canceled and "\255\1\255\1" or "") .. "%02d:%02d", minutes, seconds)
	end

	glTranslate(0, yoffset, 10)
	glBillboard()
	glTranslate(0, 5, 0)
	font:Begin()
	font:Print(etaText, 0, -10, 6, "co")
	font:End()
end



function widget:DrawWorld()
	if Spring.IsGUIHidden() == false then
		local glStateReady = false
		local cx, cy, cz = Spring.GetCameraPosition()
		for unitID, bi in pairs(etaTable) do
			local ux, uy, uz = spGetUnitViewPosition(unitID)
			if ux ~= nil then
				local dx, dy, dz = ux - cx, uy - cy, uz - cz
				local dist = dx * dx + dy * dy + dz * dz
				if dist < etaMaxDist then
					if not glStateReady then
						glDepthTest(true)
						glColor(1, 1, 1, 0.1)
						glStateReady = true
					end
					glDrawFuncAtUnit(unitID, false, drawEtaText, bi.timeLeft, bi.yoffset)
				end
			end
		end
		if glStateReady then
			glColor(1, 1, 1, 1)
			glDepthTest(false)
		end
	end
end
