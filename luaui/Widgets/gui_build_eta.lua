local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "BuildETA",
		desc = "Displays estimated time of arrival for builds",
		author = "trepan (modified by jK)",
		date = "2007",
		license = "GNU GPL, v2 or later",
		layer = -90,
		enabled = true
	}
end

local lastGameUpdate = Spring.GetGameSeconds()

local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetGameSeconds = Spring.GetGameSeconds
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetCameraPosition = Spring.GetCameraPosition
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetViewGeometry = Spring.GetViewGeometry
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetSpectatingState = Spring.GetSpectatingState
local spGetFeatureResources = Spring.GetFeatureResources
local spGetFeatureHealth = Spring.GetFeatureHealth
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeaturePosition = Spring.GetFeaturePosition
local spec, fullview = spGetSpectatingState()
local myAllyTeam = Spring.GetMyAllyTeamID()

local glColor = gl.Color
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale

local font
local vsx, vsy = spGetViewGeometry()

local unitETATable = {}
local featureETATable = {}
-- Distance thresholds in world units (elmos). Camera height is roughly the main dial.
-- At ETA_DIST_FULL the text is fully visible at max font size.
-- Between ETA_DIST_FULL and ETA_DIST_FADE the text fades out linearly.
-- Beyond ETA_DIST_FADE the text is invisible.
local ETA_DIST_FULL = 500   -- fully opaque + largest font below this distance
local ETA_DIST_FADE = 1000   -- completely transparent / hidden beyond this distance
local ETA_FONT_CLOSE = 44   -- font size (px) when closer than ETA_DIST_FULL
local ETA_FONT_FAR   = 11   -- font size (px) when at ETA_DIST_FADE
local ETA_SCREEN_OFFSET_Y = -35 -- pixels below the projected world position (negative = down on screen)
local blinkTime = 20
local minETASecs = 5 -- Don't show ETA if it is less than 5 seconds

-- Pre-cache I18N strings to avoid per-unit per-frame lookups
local i18n_buildTime = "\255\255\255\1" .. Spring.I18N('ui.buildEstimate.time') .. "\255\255\255\255 "
local i18n_cancelled = Spring.I18N('ui.buildEstimate.cancelled') .. " "

local unitHeight = {}
for udid, unitDef in pairs(UnitDefs) do
	unitHeight[udid] = unitDef.height
end
local featureHeight = {}
for featureDefID, featureDef in pairs(FeatureDefs) do
	featureHeight[featureDefID] = featureDef.height
end


function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	font = WG['fonts'].getFont(nil, 1.2, 0.2, 20)
end

local function makeUnitETA(unitID, unitDefID)
	if unitDefID == nil then
		return nil
	end
	local isBuilding, buildProgress = spGetUnitIsBeingBuilt(unitID)
	if not isBuilding  then
		return nil
	end

	local alreadyStarted = buildProgress > 0.001
	return {
		firstSet = not alreadyStarted,
		lastTime = spGetGameSeconds(),
		lastProg = buildProgress,
		rate = nil,
		timeLeft = nil,
		display = alreadyStarted or nil, -- show immediately for existing units (will show ??? until rate is known)
		yoffset = unitHeight[unitDefID] + 14
	}
end

local function makeFeatureETA(featureID, featureDefID)
	if featureDefID == nil then
		return nil
	end
	local progress
	progress = select(5, spGetFeatureResources(featureID))
	if progress == 1 then
		progress = select(3, spGetFeatureHealth(featureID))
	end

	return {
		firstSet = true,
		lastTime = spGetGameSeconds(),
		lastProg = progress,
		rate = nil,
		timeLeft = nil,
		yoffset = featureHeight[featureDefID] + 14
	}
end

local function init()
	unitETATable = {}
	local units = Spring.GetAllUnits()
	for i=1, #units do
		local unitID = units[i]
		if fullview or spGetUnitAllyTeam(unitID) == myAllyTeam then
			unitETATable[unitID] = makeUnitETA(unitID, Spring.GetUnitDefID(unitID))
		end
	end
end
-- step is negative for reclaim, positive for resurrect, zero for stop
-- only called for features that my ally team is reclaiming or resurrecting or all if I am spectator
local function featureReclaimStartedETA(featureID, step)
	if step == 0 then
		featureETATable[featureID] = nil
	else
		featureETATable[featureID] = makeFeatureETA(featureID, spGetFeatureDefID(featureID))
	end
end

function widget:Initialize()
	widget:ViewResize()
	widgetHandler:RegisterGlobal("FeatureReclaimStartedETA", featureReclaimStartedETA)
	init()
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("FeatureReclaimStartedETA")
end

function widget:LanguageChanged()
	i18n_buildTime = "\255\255\255\1" .. Spring.I18N('ui.buildEstimate.time') .. "\255\255\255\255 "
	i18n_cancelled = Spring.I18N('ui.buildEstimate.cancelled') .. " "
end

local function updateEta(eta, newProgress, gameSeconds, abs)
	local dp = newProgress - eta.lastProg
	local dt = gameSeconds - eta.lastTime
	if dt > 2 then
		eta.firstSet = true
		eta.rate = nil
		eta.timeLeft = nil
	end

	local rate = dp / dt

	if rate ~= 0 then
		if eta.firstSet then
			if (newProgress > 0.001) then
				eta.firstSet = false
			end
		else
			local rf = 0.5
			if eta.rate == nil then
				eta.rate = rate
			else
				eta.rate = ((1 - rf) * eta.rate) + (rf * rate)
			end

			local tf = 0.1
			if rate > 0 then
				local newTime = (1 - newProgress) / rate
				if eta.timeLeft and eta.timeLeft > 0 then
					eta.timeLeft = ((1 - tf) * eta.timeLeft) + (tf * newTime)
				else
					eta.timeLeft = newTime
				end
			elseif rate < 0 then
				local newTime
				if eta.timeLeft and eta.timeLeft < 0 then
					newTime = newProgress / eta.rate -- use smooth rate. we don't need to smoothen the time if the rate is smooth
				else
					newTime = newProgress / rate
				end
				if abs then newTime = math.abs(newTime) end
				eta.timeLeft = newTime
			end

			if eta.display == nil and eta.timeLeft < minETASecs then
				eta.display = false
			elseif eta.timeLeft >= minETASecs then
				eta.display = true
			end
		end
		eta.lastTime = gameSeconds
		eta.lastProg = newProgress
	end
end

function widget:Update(dt)

	local gs = spGetGameSeconds()
	if gs == lastGameUpdate then
		return
	end
	lastGameUpdate = gs

	for unitID, eta in pairs(unitETATable) do
		local isBuilding, buildProgress = spGetUnitIsBeingBuilt(unitID)
		if not isBuilding then
			unitETATable[unitID] = nil
		else
			updateEta(eta, buildProgress, gs)
		end
	end

	for featureID, eta in pairs(featureETATable) do
		local progress
		progress = select(5, spGetFeatureResources(featureID))
		if progress == 1 then
			progress = select(3, spGetFeatureHealth(featureID))
		end
		updateEta(eta, progress, gs, true)
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
		unitETATable[unitID] = makeUnitETA(unitID, unitDefID)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	unitETATable[unitID] = nil
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	unitETATable[unitID] = nil
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	unitETATable[unitID] = nil
end

function widget:FeatureDestroyed(featureID, allyTeamID)
	featureETATable[featureID] = nil
end

local function drawEtaText(timeLeft, alpha, fontSize)
	local etaText
	local etaPrefix = i18n_buildTime
	if timeLeft == nil then
		etaText = etaPrefix .. "\255\1\1\255???"
	else
		local canceled = timeLeft<0
		etaPrefix = (not canceled and etaPrefix) or (((spGetGameFrame()%blinkTime>=blinkTime/2) and "\255\255\255\255" or"\255\255\1\1")..i18n_cancelled)
		timeLeft = math.abs(timeLeft)
		local minutes = timeLeft / 60
		local seconds = timeLeft % 60
		etaText = etaPrefix .. string.format((not canceled and "\255\1\255\1" or "") .. "%02d:%02d", minutes, seconds)
	end

	glColor(1, 1, 1, alpha)
	font:Begin()
	font:Print(etaText, 0, 0, fontSize, "co")
	font:End()
	glColor(1, 1, 1, 1)
end



function widget:DrawScreenEffects()
	if Spring.IsGUIHidden() then return end

	local cx, cy, cz = spGetCameraPosition()

	for unitID, eta in pairs(unitETATable) do
		if eta.display then
			local ux, uy, uz = spGetUnitViewPosition(unitID)
			if ux ~= nil then
				local dx, dy, dz = ux - cx, uy - cy, uz - cz
				local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
				if dist < ETA_DIST_FADE then
					local alpha, fontSize
					if dist <= ETA_DIST_FULL then
						alpha = 1.0
						fontSize = ETA_FONT_CLOSE
					else
						local t = (dist - ETA_DIST_FULL) / (ETA_DIST_FADE - ETA_DIST_FULL)
						alpha = 1.0 - t
						fontSize = ETA_FONT_CLOSE + t * (ETA_FONT_FAR - ETA_FONT_CLOSE)
					end
					local sx, sy = spWorldToScreenCoords(ux, uy + eta.yoffset, uz)
					if sx and sy and sx > -200 and sx < vsx + 200 and sy > -50 and sy < vsy + 50 then
						glPushMatrix()
						glTranslate(sx, sy + ETA_SCREEN_OFFSET_Y, 0)
						drawEtaText(eta.timeLeft, alpha, fontSize)
						glPopMatrix()
					end
				end
			end
		end
	end

	for featureID, eta in pairs(featureETATable) do
		if eta.display then
			local fx, fy, fz = spGetFeaturePosition(featureID)
			if fx ~= nil then
				local dx, dy, dz = fx - cx, fy - cy, fz - cz
				local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
				if dist < ETA_DIST_FADE then
					local alpha, fontSize
					if dist <= ETA_DIST_FULL then
						alpha = 1.0
						fontSize = ETA_FONT_CLOSE
					else
						local t = (dist - ETA_DIST_FULL) / (ETA_DIST_FADE - ETA_DIST_FULL)
						alpha = 1.0 - t
						fontSize = ETA_FONT_CLOSE + t * (ETA_FONT_FAR - ETA_FONT_CLOSE)
					end
					local sx, sy = spWorldToScreenCoords(fx, fy + eta.yoffset, fz)
					if sx and sy and sx > -200 and sx < vsx + 200 and sy > -50 and sy < vsy + 50 then
						glPushMatrix()
						glTranslate(sx, sy + ETA_SCREEN_OFFSET_Y, 0)
						drawEtaText(eta.timeLeft, alpha, fontSize)
						glPopMatrix()
					end
				end
			end
		end
	end
end
