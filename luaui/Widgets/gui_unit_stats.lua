
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Unit Stats",
		desc      = "Shows detailed unit stats",
		author    = "Niobium + Doo",
		date      = "Jan 11, 2009",
		version   = 1.7,
		license   = "GNU GPL, v2 or later",
		layer     = -999990,
		enabled   = true,
	}
end


-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max
local tableInsert = table.insert
local tableSort = table.sort
local tableSortStable = table.sortStable

-- Localized Spring API for performance
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetSpectatingState = Spring.GetSpectatingState

local texts = {}
local damageStats = (VFS.FileExists("LuaUI/Config/BAR_damageStats.lua")) and VFS.Include("LuaUI/Config/BAR_damageStats.lua")
local gameName = Game.gameName

if damageStats and damageStats[gameName] and damageStats[gameName].team then
	local rate = 0
	for k, v in pairs (damageStats[gameName].team) do
		if k ~= "games" and v.cost and v.killed_cost then
			local compRate = v.killed_cost/v.cost
			if compRate > rate then
				highestUnitDef = k
				rate = compRate
			end
		end
	end
	local scndRate = 0
	for k, v in pairs (damageStats[gameName].team) do
		if k ~= "games" and v.cost and v.killed_cost then
			local compRate = v.killed_cost/v.cost
			if compRate > scndRate and k ~= highestUnitDef then
				scndhighestUnitDef = k
				scndRate = compRate
			end
		end
	end
	local thirdRate = 0
	--local thirdhighestUnitDef
	for k, v in pairs (damageStats[gameName].team) do
		if k ~= "games" and v.cost and v.killed_cost then
			local compRate = v.killed_cost/v.cost
			if compRate > thirdRate and k ~= highestUnitDef and k ~= scndhighestUnitDef then
				--thirdhighestUnitDef = k
				thirdRate = compRate
			end
		end
	end
	--spEcho("1st = "..  highestUnitDef .. ", ".. rate)
	--spEcho("2nd = "..  scndhighestUnitDef .. ", ".. scndRate)
	--spEcho("3rd = "..  thirdhighestUnitDef .. ", ".. thirdRate)
end

include("keysym.h.lua")
----v1.7 by Doo changes
-- Reverted "Added beamtime to oRld value to properly count dps of BeamLaser weapons" because reload starts at the beginning of the beamtime
-- Reduced the "minimal" reloadTime to properly calculate dps for low reloadtime weapons
-- Hid range from gui for explosion (death/selfd) as it is irrelevant.

----v1.6 by Doo changes
-- Fixed crashing when hovering some enemy units

----v1.5 by Doo changes
-- Fixed some issues with the add of BeamTime values
-- Added a 1/30 factor to stockpiling weapons (seems like the lua wDef.stockpileTime is in frames while the weaponDefs uses seconds) Probably the 1/30 value in older versions wasnt a "min reloadtime" but the 1/30 factor for stockpile weapons with a typo

----v1.4 by Doo changes
-- Added beamtime to oRld value to properly count dps of BeamLaser weapons

---- v1.3 changes
-- Fix for 87.0
-- Added display of experience effect (when experience >25%)

---- v1.2 changes
-- Fixed drains for burst weapons (Removed 0.125 minimum)
-- Show remaining costs for units under construction

---- v1.1 changes
-- Added extra text to help explain numbers
-- Added grouping of duplicate weapons
-- Added sonar radius
-- Fixed radar/jammer detection
-- Fixed stockpiling unit drains
-- Fixed turnrate/acceleration scale
-- Fixed very low reload times

------------------------------------------------------------------------------------
-- Globals
------------------------------------------------------------------------------------
local useSelection = true

local customFontSize = 14
local fontSize = customFontSize

local cY

local vsx, vsy = gl.GetViewSizes()
local widgetScale = 1
local xOffset = (32 + (fontSize*0.9))*widgetScale
local yOffset = -((32 - (fontSize*0.9))*widgetScale)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)

------------------------------------------------------------------------------------
-- Speedups
------------------------------------------------------------------------------------

local white = '\255\255\255\255'
local grey = '\255\190\190\190'
local green = '\255\1\255\1'
local yellow = '\255\255\255\1'
local orange = '\255\255\128\1'
local blue = '\255\128\128\255'

local metalColor = '\255\196\196\255' -- Light blue
local energyColor = '\255\255\255\128' -- Light yellow
local buildColor = '\255\128\255\128' -- Light green

local simSpeed = Game.gameSpeed
local armorTypes = Game.armorTypes

local max = mathMax
local floor = mathFloor
local ceil = math.ceil
local bit_and = math.bit_and
local format = string.format
local char = string.char

local glColor = gl.Color

local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamInfo = Spring.GetTeamInfo
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamColor = Spring.GetTeamColor
local spIsUserWriting = Spring.IsUserWriting
local spGetModKeyState = Spring.GetModKeyState
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitExperience = Spring.GetUnitExperience
local spGetUnitSensorRadius = Spring.GetUnitSensorRadius
local spGetUnitWeaponState = Spring.GetUnitWeaponState

local uDefs = UnitDefs
local wDefs = WeaponDefs

local font, showUnitID
local RectRound, UiElement, UiUnit, bgpadding, elementCorner

local maxWidth = 0
local textBuffer = {}
local textBufferCount = 0

-- Content caching state
local textDlist = nil
local dlistGuishaderTitle = nil
local dlistGuishaderStats = nil
local cachedDefID, cachedUnitID
local cachedShift = false
local cachedContentBottom = 0
local cachedMaxWidth = 0
local cachedTitleText = ""
local cachedTitleTextWidth = 0
local cachedTitleFontSize = 0
local cachedBuildProg = nil
local cachedExp = nil
local lastComputeFrame = -999
local COMPUTE_INTERVAL = 6

-- Render-to-texture caching
local panelTex = nil
local panelTexW, panelTexH = 0, 0
local panelOffsets = {0, 0, 0, 0} -- left, bottom, right, top offsets from screenX/screenY
local PANEL_REF_X, PANEL_REF_Y = 1000, 2000
local cachedGuishaderX, cachedGuishaderY = nil, nil

local spec = spGetSpectatingState()

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousName = '?????'

local showStats = false

-- TODO: Shield damages are overridden in the shields rework (now in main game)
local shieldsRework = not Spring.GetModOptions().experimentalshields:find("bounce")

-- TODO: Localize, same as armorTypes
-- TODO: Compose this list somewhere and reinclude it here
local targetableTypes = {
	[1] = "nuclear missiles",
}

-- Only groups 0 [always active] and 1 [primary weapon set] are aggregated.
-- Others might be checked for abilities still, e.g. antinuke interceptors.
local weaponGroupNumbers = table.new(#WeaponDefs, 1) -- defID [0] is hashed
for weaponDefID = 0, #WeaponDefs do
	weaponGroupNumbers[weaponDefID] = tonumber(WeaponDefs[weaponDefID].customParams.weapons_group or -1) or -1
end

------------------------------------------------------------------------------------
-- Functions
------------------------------------------------------------------------------------

local function descending(a, b) return a > b end -- table.sort function

local function DrawText(t1, t2)
	textBufferCount = textBufferCount + 1
	textBuffer[textBufferCount] = {t1, t2, bgpadding * 8, cY}
	cY = cY - fontSize
	maxWidth = max(maxWidth, (font:GetTextWidth(t1)*fontSize) + (bgpadding*10), (font:GetTextWidth(t2)*fontSize)+(fontSize*6.5) + (bgpadding*10))
end

local function buildTextDlist()
	if textDlist then gl.DeleteList(textDlist) end
	textDlist = gl.CreateList(function()
		font:Begin()
		font:SetTextColor(1, 1, 1, 1)
		font:SetOutlineColor(0, 0, 0, 1)
		for i = 1, textBufferCount do
			font:Print(textBuffer[i][1], textBuffer[i][3], textBuffer[i][4], fontSize, "o")
			font:Print(textBuffer[i][2], textBuffer[i][3] + (fontSize*6.5), textBuffer[i][4], fontSize, "o")
		end
		font:End()
	end)
end

local function renderPanelToTexture(uDefID, uID)
	local refX, refY = PANEL_REF_X, PANEL_REF_Y
	local titleFontSize = cachedTitleFontSize
	local uiOpacity = WG.FlowUI.clampedOpacity

	-- Title rect at reference coords
	local tLeft = floor(refX - bgpadding)
	local tBottom = ceil(refY - bgpadding)
	local tRight = floor(refX + cachedTitleTextWidth + (titleFontSize * 3.5))
	local tTop = floor(refY + (titleFontSize * 1.8) + bgpadding)

	-- Stats rect at reference coords
	local sLeft = floor(refX - bgpadding)
	local sBottom = ceil(refY + cachedContentBottom + (fontSize / 3) + (bgpadding * 0.3))
	local sRight = ceil(refX + cachedMaxWidth + bgpadding)
	local sTop = ceil(refY - bgpadding)

	-- Panel bounding box
	local panelLeft = math.min(tLeft, sLeft)
	local panelBottom = sBottom
	local panelRight = math.max(tRight, sRight)
	local panelTop = tTop

	local w = panelRight - panelLeft
	local h = panelTop - panelBottom
	if w < 1 or h < 1 then return end

	-- Store offsets from screenX/screenY to panel edges
	panelOffsets[1] = panelLeft - refX
	panelOffsets[2] = panelBottom - refY
	panelOffsets[3] = panelRight - refX
	panelOffsets[4] = panelTop - refY

	-- Create/resize texture
	if panelTex and (w ~= panelTexW or h ~= panelTexH) then
		gl.DeleteTexture(panelTex)
		panelTex = nil
	end
	if not panelTex then
		panelTex = gl.CreateTexture(w, h, {
			target = GL.TEXTURE_2D,
			format = GL.RGBA,
			fbo = true,
		})
		panelTexW = w
		panelTexH = h
	end
	if not panelTex then return end

	-- Override FlowUI screen size so UiElement edge detection treats all edges as interior
	local savedFlowVsx = WG.FlowUI.vsx
	local savedFlowVsy = WG.FlowUI.vsy
	WG.FlowUI.vsx = panelRight + 9999
	WG.FlowUI.vsy = panelTop + 9999

	gl.R2tHelper.RenderInRect(panelTex, panelLeft, panelBottom, panelRight, panelTop, function()
		-- Title background
		UiElement(tLeft, tBottom, tRight, tTop, 1,1,1,0, 1,1,0,1, uiOpacity)

		-- Stats background
		UiElement(sLeft, sBottom, sRight, sTop, 0,1,1,1, 1,1,1,1, uiOpacity)

		-- Icon
		if uID then
			local iconPadding = mathMax(1, mathFloor(bgpadding * 0.8))
			glColor(1,1,1,1)
			UiUnit(
				tLeft + bgpadding + iconPadding, tBottom + iconPadding, tLeft + (tTop - tBottom) - iconPadding, tTop - bgpadding - iconPadding,
				nil,
				1,1,1,1,
				0.13,
				nil, nil,
				'#' .. uDefID
			)
		end

		-- Title text
		glColor(1,1,1,1)
		font:Begin()
		font:Print(cachedTitleText, tLeft + ((tTop - tBottom) * 1.3), tBottom + titleFontSize * 0.7, titleFontSize, "o")
		font:End()

		-- Stats text
		gl.PushMatrix()
		gl.Translate(refX, refY, 0)
		gl.CallList(textDlist)
		gl.PopMatrix()
	end, true)

	WG.FlowUI.vsx = savedFlowVsx
	WG.FlowUI.vsy = savedFlowVsy

	-- Reset guishader position so it gets updated
	cachedGuishaderX = nil
	cachedGuishaderY = nil
end

local function GetTeamColorCode(teamID)
	if not teamID then return "\255\255\255\255" end
	local R, G, B = spGetTeamColor(teamID)
	if not R then return "\255\255\255\255" end
	return Spring.Utilities.ConvertColor(R, G, B)
end

local function GetTeamName(teamID)
	if not teamID then return 'Error:NoTeamID' end

	local _, teamLeader = spGetTeamInfo(teamID,false)
	if not teamLeader then return 'Error:NoLeader' end

	local leaderName = spGetPlayerInfo(teamLeader,false)
	leaderName = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(teamLeader)) or leaderName
    if Spring.GetGameRulesParam('ainame_'..teamID) then
        leaderName = Spring.GetGameRulesParam('ainame_'..teamID)
    end

	if not spec and anonymousMode ~= 'disabled' then
		return anonymousName
	end

	return leaderName or 'Error:NoName'
end

local guishaderEnabled = false	-- not a config var
function RemoveGuishader()
	if guishaderEnabled and WG['guishader'] then
		WG['guishader'].DeleteScreenDlist('unit_stats_title')
		WG['guishader'].DeleteScreenDlist('unit_stats_data')
		guishaderEnabled = false
	end
	if dlistGuishaderTitle then
		gl.DeleteList(dlistGuishaderTitle)
		dlistGuishaderTitle = nil
	end
	if dlistGuishaderStats then
		gl.DeleteList(dlistGuishaderStats)
		dlistGuishaderStats = nil
	end
end

local function invalidateContent()
	cachedDefID = nil
	cachedUnitID = nil
	cachedGuishaderX = nil
	cachedGuishaderY = nil
	if textDlist then
		gl.DeleteList(textDlist)
		textDlist = nil
	end
	if panelTex then
		gl.DeleteTexture(panelTex)
		panelTex = nil
	end
end

------------------------------------------------------------------------------------
-- Code
------------------------------------------------------------------------------------

local function enableStats()
	showStats = true
end

local function disableStats()
	showStats = false
end

function widget:Initialize()
	texts = Spring.I18N('ui.unitstats')

	widget:ViewResize(vsx,vsy)

	WG['unitstats'] = {}
	WG['unitstats'].showUnit = function(unitID)
    		showUnitID = unitID
	end
	WG['unitstats'].isShowing = function()
		return showStats
	end

	widgetHandler:AddAction("unit_stats", enableStats, nil, "p")
	widgetHandler:AddAction("unit_stats", disableStats, nil, "r")

	spTraceScreenRay = Spring.TraceScreenRay -- fix for monkey-patching
end

function widget:Shutdown()
	WG['unitstats'] = nil
	RemoveGuishader()
	invalidateContent()
end

function widget:PlayerChanged()
	spec = spGetSpectatingState()
end

function init()
	vsx, vsy = gl.GetViewSizes()
	widgetScale = (1+((vsy-850)/900)) * (0.95+(ui_scale-1)/2.5)
	fontSize = customFontSize * widgetScale

	xOffset = (32 + bgpadding)*widgetScale
	yOffset = -((32 + bgpadding)*widgetScale)
end

function widget:ViewResize(n_vsx,n_vsy)
	vsx,vsy = Spring.GetViewGeometry()
	widgetScale = (1+((vsy-850)/1800)) * (0.95+(ui_scale-1)/2.5)

	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiUnit = WG.FlowUI.Draw.Unit

	font = WG['fonts'].getFont()

	init()
	invalidateContent()
end

local selectedUnits = spGetSelectedUnits()
local selectedUnitsCount = spGetSelectedUnitsCount()
if useSelection then
	function widget:SelectionChanged(sel)
		selectedUnits = sel
		selectedUnitsCount = spGetSelectedUnitsCount()
	end
end


local function computeContent(uDefID, uID, shiftBool)
	local shift = shiftBool

	local uDef = uDefs[uDefID]
	local maxHP = uDef.health
	local uTeam = Spring.GetMyTeamID()
	local losRadius = uDef.sightDistance
	local airLosRadius = uDef.airSightDistance
	local radarRadius = uDef.radarDistance
	local sonarRadius = uDef.sonarDistance
	local jammingRadius = uDef.radarDistanceJam
	local sonarJammingRadius = uDef.sonarDistanceJam
	local seismicRadius = uDef.seismicDistance
	local armoredMultiple = uDef.armoredMultiple
	local paralyzeMult = 1
	if uDef.customParams.paralyzemultiplier then
		paralyzeMult = tonumber(uDef.customParams.paralyzemultiplier)
	end
	local transportable = not (uDef.cantBeTransported and uDef.cantBeTransported or false)
	local mass = uDef.mass and uDef.mass or 0
	local size = uDef.xsize and uDef.xsize / 2 or 0
	local isBuilding, buildProg, uExp

	if uID then
		isBuilding, buildProg = Spring.GetUnitIsBeingBuilt(uID)
		maxHP = select(2,Spring.GetUnitHealth(uID))
		uTeam = spGetUnitTeam(uID)
		losRadius = spGetUnitSensorRadius(uID, 'los') or 0
		airLosRadius = spGetUnitSensorRadius(uID, 'airLos') or 0
		radarRadius = spGetUnitSensorRadius(uID, 'radar') or 0
		sonarRadius = spGetUnitSensorRadius(uID, 'sonar') or 0
		jammingRadius = spGetUnitSensorRadius(uID, 'radarJammer') or 0
		sonarJammingRadius = spGetUnitSensorRadius(uID, 'sonarJammer') or 0
		seismicRadius = spGetUnitSensorRadius(uID, 'seismic') or 0
		uExp = spGetUnitExperience(uID)
		armoredMultiple = select(2,Spring.GetUnitArmored(uID))
	end

	maxWidth = 0

	cY = 0

	cY = cY - (bgpadding/2)

	local titleFontSize = fontSize*1.07
	cY = cY - 2 * titleFontSize
	textBuffer = {}
	textBufferCount = 0

	------------------------------------------------------------------------------------
	-- Units under construction
	------------------------------------------------------------------------------------
	if isBuilding then

		local myTeamID = spGetMyTeamID()
		local mCur, mStor, mPull, mInc, mExp, mShare, mSent, mRec = spGetTeamResources(myTeamID, 'metal')
		local eCur, eStor, ePull, eInc, eExp, eShare, eSent, eRec = spGetTeamResources(myTeamID, 'energy')

		local mTotal = uDef.metalCost
		local eTotal = uDef.energyCost
		local buildRem = 1 - buildProg
		local mRem = mathFloor(mTotal * buildRem)
		local eRem = mathFloor(eTotal * buildRem)
		local mIncome = mInc + mRec
		local eIncome = eInc + eRec
		local mEta = mIncome > 0 and (mRem - mCur) / mIncome or 0
		local eEta = eIncome > 0 and (eRem - eCur) / eIncome or 0

		DrawText(texts.prog..":", format("%d%%", 100 * buildProg))

		if mEta >= 0 then
			DrawText(texts.metal..":", format("%d / %d (" .. yellow .. "%d" .. white .. ", %ds)", mTotal * buildProg, mTotal, mRem, mEta))
		else
			DrawText(texts.metal..":", format("%d / %d (" .. yellow .. "%d" .. white .. ")", mTotal * buildProg, mTotal, mRem))
		end

		if eEta >= 0 then
			DrawText(texts.energy..":", format("%d / %d (" .. yellow .. "%d" .. white .. ", %ds)", eTotal * buildProg, eTotal, eRem, eEta))
		else
			DrawText(texts.energy..":", format("%d / %d (" .. yellow .. "%d" .. white .. ")", eTotal * buildProg, eTotal, eRem))
		end

			--DrawText("MaxBP:", format(white .. '%d', buildRem * uDef.buildTime / mathMax(mEta, eEta)))
		cY = cY - fontSize
	end

	------------------------------------------------------------------------------------
	-- Generic information, cost, move, class
	------------------------------------------------------------------------------------

	--DrawText('Height:', uDefs[spGetUnitDefID(uID)].height)

	DrawText(texts.cost..":", format(metalColor .. '%d' .. white .. ' / ' ..
		energyColor .. '%d' .. white .. ' / ' ..
		buildColor .. '%d', uDef.metalCost, uDef.energyCost, uDef.buildTime)
	)

	if not (uDef.isBuilding or uDef.isFactory) then
		if not uID or not Spring.GetUnitMoveTypeData(uID) then
			DrawText(texts.move..":", format("%.1f / %.1f / %.0f ("..texts.speedaccelturn..")", uDef.speed, 900 * uDef.maxAcc, simSpeed * uDef.turnRate * (180 / 32767)))
		else
			local mData = Spring.GetUnitMoveTypeData(uID)
			local mSpeed = mData.maxSpeed or uDef.speed
			local mAccel = mData.accRate or uDef.maxAcc
			local mTurnRate = mData.baseTurnRate or uDef.turnRate
			DrawText(texts.move..":", format("%.1f / %.1f / %.0f ("..texts.speedaccelturn..")", mSpeed, 900 * mAccel, simSpeed * mTurnRate * (180 / 32767)))
		end
	end

	if uDef.buildSpeed > 0 then
		DrawText(texts.build..':', yellow .. uDef.buildSpeed)
	end

	cY = cY - fontSize

	------------------------------------------------------------------------------------
	-- Sensors and Jamming
	------------------------------------------------------------------------------------

	DrawText(texts.los..':', losRadius .. (airLosRadius > losRadius and format(' ('..texts.airlos..': %d)', airLosRadius) or ''))

	if radarRadius   > 0 then DrawText(texts.radar..':', '\255\77\255\77' .. radarRadius) end
	if sonarRadius   > 0 then DrawText(texts.sonar..':', '\255\128\128\255' .. sonarRadius) end
	if jammingRadius > 0 then DrawText(texts.jammer..':'  , '\255\255\77\77' .. jammingRadius) end
	if sonarJammingRadius > 0 then DrawText(texts.sonarjam..':', '\255\255\77\77' .. sonarJammingRadius) end
	if seismicRadius > 0 then DrawText(texts.seis..':' , '\255\255\26\255' .. seismicRadius) end

	if uDef.stealth then DrawText(texts.other1..":", texts.stealth) end

	cY = cY - fontSize

	------------------------------------------------------------------------------------
	-- Armor
	------------------------------------------------------------------------------------

	DrawText(texts.armor..":", texts.class .. armorTypes[uDef.armorType or 0] or '???')

	if uID and uExp ~= 0 then
		if maxHP then
			DrawText(texts.exp..":", format("+%d%% "..texts.health, (maxHP/uDef.health-1)*100))
		else
			--DrawText("Exp:                 unknown",'\255\255\77\77')
		end
	end
	if paralyzeMult < 1 then
		if paralyzeMult == 0 then
			DrawText(texts.emp..':', blue .. texts.immune)
		else
			local resist = 100 - (paralyzeMult * 100)
			DrawText(texts.emp..':', blue .. mathFloor(resist) .. "% " .. white .. texts.resist)
		end
	end
	if maxHP then
		DrawText(texts.open..":", format("%s: %d", texts.maxhp, maxHP))

		if armoredMultiple and armoredMultiple ~= 1 then
			local message = format("%s: %d (+%d%%)", texts.maxhp, maxHP / armoredMultiple, 100 * (1 / armoredMultiple - 1))
			if uDef.customParams.reactive_armor_health then
				message = message .. (", %d to break, %d%s to restore"):format(
					uDef.customParams.reactive_armor_health / armoredMultiple,
					uDef.customParams.reactive_armor_restore,
					texts.s
				)
			end
			DrawText(texts.closed..":", message)
		end
	end

	cY = cY - fontSize


	------------------------------------------------------------------------------------
	-- Transportable
	------------------------------------------------------------------------------------

		if transportable and mass > 0 and size > 0 then
			if mass < 751 and size < 4 then -- 3 is t1 transport max size
				DrawText(texts.transportable..':', blue .. texts.transportable_light)
			elseif mass < 100000 and size < 5 then
				DrawText(texts.transportable..':', yellow .. texts.transportable_heavy)
			end
		end

	cY = cY - fontSize

	------------------------------------------------------------------------------------
	-- SPECIAL ABILITIES
	------------------------------------------------------------------------------------
	---- Build Related
	local specabs = ''
	specabs = specabs..((uDef.canBuild and texts.build..", ") or "")
	specabs = specabs..((uDef.canAssist and texts.assist..", ") or "")
	specabs = specabs..((uDef.canRepair and texts.repair..", ") or "")
	specabs = specabs..((uDef.canReclaim and texts.reclaim..", ") or "")
	specabs = specabs..((uDef.canResurrect and texts.resurrect..", ") or "")
	specabs = specabs..((uDef.canCapture and texts.capture..", ") or "")
	---- Radar/Sonar states
	specabs = specabs..((uDef.canCloak and texts.cloak..", ") or "")
	specabs = specabs..((uDef.stealth and texts.stealth..",  ") or "")

	---- Attack Related
	specabs = specabs..((uDef.canAttackWater and texts.waterweapon..", ") or "")
	specabs = specabs..((uDef.canManualFire and texts.manuelfire..", ") or "")
	specabs = specabs..((uDef.canStockpile and texts.stockpile..", ") or "")
	specabs = specabs..((uDef.canParalyze  and texts.paralyzer..", ") or "")
	specabs = specabs..((uDef.canKamikaze  and texts.kamikaze..", ") or "")
	if (string.len(specabs) > 11) then
		DrawText(texts.abilities..":", string.sub(specabs, 1, string.len(specabs)-2))
		cY = cY - fontSize
	end

	------------------------------------------------------------------------------------
	-- Weapons
	------------------------------------------------------------------------------------
	local uWeps = uDef.weapons
	local wepCounts = {} -- wepCounts[wepDefID] = #
	local wepsCompact = {} -- uWepsCompact[1..n] = wepDefID
	local weaponNums = {}
	for i = 1, #uWeps do
		local wDefID = uWeps[i].weaponDef
		if weaponGroupNumbers[wDefID] >= 0 then
			local wCount = wepCounts[wDefID]
			if wCount then
				wepCounts[wDefID] = wCount + 1
			else
				wepCounts[wDefID] = 1
				wepsCompact[#wepsCompact + 1] = wDefID
				weaponNums[#wepsCompact] = i
			end
		end
	end
	tableSortStable(wepsCompact, function(a, b) return weaponGroupNumbers[a] < weaponGroupNumbers[b] end)

	local selfDWeaponID = WeaponDefNames[uDef.selfDExplosion].id
	local deathWeaponID = WeaponDefNames[uDef.deathExplosion].id
	local selfDWeaponIndex
	local deathWeaponIndex

	if shift then
		wepCounts = {}
		wepsCompact = {}
		wepCounts[selfDWeaponID] = 1
		wepCounts[deathWeaponID] = 1
		deathWeaponIndex = #wepsCompact+1
		wepsCompact[deathWeaponIndex] = deathWeaponID
		selfDWeaponIndex = #wepsCompact+1
		wepsCompact[selfDWeaponIndex] = selfDWeaponID
	end

	local groupLast = wepsCompact[1] and weaponGroupNumbers[wepsCompact[1]]
	local totaldps = 0
	local totalbDamages = 0
	local useExp = true
	for i = 1, #wepsCompact do

		local wDefId = wepsCompact[i]
		local uWep = wDefs[wDefId]

		-- Handle projectiles that spawn additional projectiles.
		-- Many properties (might) have nothing to do with the spawned projectile:
		local burst = uWep.salvoSize * uWep.projectiles
		local range = uWep.range
		local reload = uWep.reload
		local accuracy = uWep.accuracy
		local moveError = uWep.targetMoveError

		local damages = uWep.damages
		local defaultArmorIndex = armorTypes.default
		local defaultArmorDamage = damages[defaultArmorIndex]
		local baseArmorIndex = defaultArmorDamage >= damages[armorTypes.vtol] and defaultArmorIndex or armorTypes.vtol
		local baseArmorDamage = damages[baseArmorIndex]

		local custom = uWep.customParams

		if custom.spark_basedamage then
			local spDamage = custom.spark_basedamage * custom.spark_forkdamage
			local spCount = custom.spark_maxunits
			baseArmorDamage = baseArmorDamage + spDamage * spCount

		elseif custom.speceffect == "split" then
			burst = burst * (custom.number or 1)
			uWep = WeaponDefNames[custom.speceffect_def] or uWep
			baseArmorDamage = damages[defaultArmorIndex]

		elseif custom.cluster then
			local munition = uDef.name .. '_' .. custom.cluster_def
			local cmNumber = custom.cluster_number
			local cmDamage = WeaponDefNames[munition].damages[defaultArmorIndex]
			baseArmorDamage = baseArmorDamage + cmDamage * cmNumber
		end

		if range > 0 and uWep.customParams.bogus ~= "1" then
			local oRld = max(0.00000000001, uWep.stockpile == true and uWep.stockpileTime/30 or uWep.reload)
			if uID and useExp and not ((uWep.stockpile and uWep.stockpileTime)) then
				oRld = spGetUnitWeaponState(uID, weaponNums[i] or -1, "reloadTimeXP") or
				       spGetUnitWeaponState(uID, weaponNums[i] or -1, "reloadTime")   or oRld
			end

			local wpnName = uWep.description
			local wepCount = wepCounts[wDefId]
			if i == deathWeaponIndex then
				wpnName = texts.deathexplosion
				oRld = 1
			elseif i == selfDWeaponIndex then
				wpnName = texts.selfdestruct
				oRld = uDef.selfDestructCountdown
			end
			if wepCount > 1 then
				DrawText(texts.weap..":", format(yellow .. "%dx" .. white .. " %s", wepCount, wpnName))
			else
				DrawText(texts.weap..":", wpnName)
			end

			if uExp ~= 0 then
				local rangeBonus = range ~= 0 and (range/uWep.range-1) or 0
				local reloadBonus = reload ~= 0 and (uWep.reload/reload-1) or 0
				local accuracyBonus = accuracy ~= 0 and (uWep.accuracy/accuracy-1) or 0
				local moveErrorBonus = moveError ~= 0 and (uWep.targetMoveError/moveError-1) or 0
				DrawText(texts.exp..":", format("+%d%% "..texts.accuracy..", +%d%% "..texts.aim..", +%d%% "..texts.firerate..", +%d%% "..texts.range, accuracyBonus*100, moveErrorBonus*100, reloadBonus*100, rangeBonus*100 ))
			end

			local infoText = ""
			if string.find(uWep.name, "disintegrator") then
				infoText = format("%.2f", (useExp and reload or uWep.reload)).."s "..texts.reload..", "..format("%d "..texts.range, useExp and range or uWep.range)
			elseif uWep.interceptor ~= 0 and uWep.coverageRange > 0 then
				local stockpile, coverage = uWep.stockpileTime / simSpeed, uWep.coverageRange
				infoText = format("%.2f%s %s (%d%s %s), %d %s", useExp and reload or uWep.reload, texts.s, texts.reload, stockpile, texts.s, texts.stockpile:lower(), coverage, texts.coverage)
			else
				if wpnName == texts.deathexplosion or wpnName == texts.selfdestruct then
					infoText = format("%d "..texts.aoe..", %d%% "..texts.edge, uWep.damageAreaOfEffect, 100 * uWep.edgeEffectiveness)
				else
					infoText = format("%.2f", (useExp and reload or uWep.reload))..texts.s.." "..texts.reload..", "..format("%d "..texts.range..", %d "..texts.aoe..", %d%% "..texts.edge, useExp and range or uWep.range, uWep.damageAreaOfEffect, 100 * uWep.edgeEffectiveness)
				end
				if damages.paralyzeDamageTime > 0 then
					infoText = format("%s, %ds "..texts.paralyze, infoText, damages.paralyzeDamageTime)
				end
				if damages.impulseFactor > 0.123 then
					infoText = format("%s, %d "..texts.impulse, infoText, damages.impulseFactor*100)
				end
				if damages.craterBoost > 0 then
					infoText = format("%s, %d "..texts.crater, infoText, damages.craterBoost*100)
				end
			end
			DrawText(texts.info..":", infoText)

			-- Draw the damage and damage modifiers strings.
			if string.find(uWep.name, "disintegrator") then
				DrawText(texts.dmg..": ", texts.infinite)
			elseif uWep.interceptor ~= 0 then
				DrawText(texts.dmg..": ", texts.burst.." = "..yellow..format("%d", defaultArmorDamage * burst))
				local interceptor = uWep.interceptor
				local intercepts = {}
				for mask, targetType in pairs(targetableTypes) do
					if bit_and(interceptor, mask) ~= 0 then
						intercepts[#intercepts+1] = targetType
					end
				end
				DrawText(texts.intercepts..":", table.concat(intercepts, "; ")..white..".")
			elseif baseArmorDamage > 0 then
				local damageString = ""
				local burstDamage = baseArmorDamage * burst
				if wpnName == texts.deathexplosion or wpnName == texts.selfdestruct then
					damageString = texts.burst.." = "..(format(yellow .. "%d", burstDamage))..white.."."
				else
					local dps = burstDamage / (useExp and reload or uWep.reload)
					if custom.area_onhit_damage and custom.area_onhit_time then
						local areaDps = custom.area_onhit_damage * burst
						local duration = custom.area_onhit_time
						dps = max(dps + areaDps, areaDps * duration / (useExp and reload or uWep.reload))
					end
					totaldps = totaldps + wepCount*dps
					totalbDamages = totalbDamages + wepCount* burstDamage
					damageString = texts.dps.." = "..(format(yellow .. "%d", dps))..white.."; "..texts.burst.." = "..(format(yellow .. "%d", burstDamage)) .. white .. (wepCount > 1 and (" ("..texts.each..").") or ("."))
				end
				DrawText(texts.dmg..":", damageString)

				local modifiers = { [defaultArmorDamage] = { armorTypes[defaultArmorIndex] } } -- [damage] = { armorClass1, armorClass2, ... }

				local indestructibleArmorIndex = armorTypes.indestructable
				local shieldsArmorIndex = shieldsRework and armorTypes.shields -- TODO: shield damage display is bugged since incorporating the shieldsrework

				for index = 0, #armorTypes do
					if index ~= indestructibleArmorIndex and index ~= shieldsArmorIndex then
						local armorName = armorTypes[index]
						local armorDamage = damages[index]
						if not modifiers[armorDamage] then
							modifiers[armorDamage] = { armorName }
						elseif armorDamage ~= defaultArmorDamage then
							tableInsert(modifiers[armorDamage], armorName)
						end
					end
				end

				local sorted = {}
				for k in pairs(modifiers) do
					if k ~= defaultArmorDamage then
						tableInsert(sorted, k)
					end
				end
				tableSort(sorted, descending)

				local modifierText = { ("default = %s%d%%"):format(yellow, floor(100 * damages[defaultArmorIndex] / baseArmorDamage)) }
				for _, armorDamage in ipairs(sorted) do
					tableInsert(modifierText, ("%s = %s%d%%"):format(table.concat(modifiers[armorDamage], ", "), yellow, floor(100 * armorDamage / baseArmorDamage)))
				end
				DrawText(texts.modifiers..":", table.concat(modifierText, white.."; ") .. white .. ".")
			end

			if uWep.metalCost > 0 or uWep.energyCost > 0 then
				DrawText(texts.cost..':', format(metalColor .. '%d' .. white .. ', ' ..
					energyColor .. '%d' .. white .. ' = ' ..
					metalColor .. '-%d' .. white .. ', ' ..
					energyColor .. '-%d' .. white .. ' '..texts.persecond,
					uWep.metalCost,
					uWep.energyCost,
					uWep.metalCost / oRld,
					uWep.energyCost / oRld))
			end


			cY = cY - fontSize

			local wDefIdNext = wepsCompact[i + 1]
			local groupNext = wDefIdNext and weaponGroupNumbers[wDefIdNext] -- nil for death explosions

			if groupLast ~= groupNext and not (groupLast == 0 and groupNext == 1) then
				groupLast = groupNext
				if totaldps > 0 then
					DrawText(texts.totaldmg..':', texts.dps.." = "..(format(yellow .. "%d", totaldps))..white..'; '..texts.burst.." = "..(format(yellow .. "%d", totalbDamages))..white..".")
				end
				totaldps = 0
				totalbDamages = 0
				cY = cY - fontSize
			end
		end
	end

	-- Cache computation results
	cachedContentBottom = cY
	cachedMaxWidth = maxWidth
	cachedTitleFontSize = fontSize * 1.07

	-- Compute title text
	local effectivenessRate = ''
	if damageStats and damageStats[gameName] and damageStats[gameName]["team"] and damageStats[gameName]["team"][uDef.name] and damageStats[gameName]["team"][uDef.name].cost and damageStats[gameName]["team"][uDef.name].killed_cost then
		effectivenessRate = "   "..damageStats[gameName]["team"][uDef.name].killed_cost / damageStats[gameName]["team"][uDef.name].cost
	end
	cachedTitleText = "\255\190\255\190" .. UnitDefs[uDefID].translatedHumanName
	if uID then
		cachedTitleText = cachedTitleText .. "   " ..  grey ..  uDef.name .. "   #" .. uID .. "   ".. GetTeamColorCode(uTeam) .. GetTeamName(uTeam) .. grey .. effectivenessRate
	end
	cachedTitleTextWidth = font:GetTextWidth(cachedTitleText) * cachedTitleFontSize

	-- Cache dynamic data for future dirty checks
	if uID then
		cachedBuildProg = select(2, Spring.GetUnitIsBeingBuilt(uID))
		cachedExp = spGetUnitExperience(uID)
	else
		cachedBuildProg = nil
		cachedExp = nil
	end

	-- Build text display list at local coordinates
	buildTextDlist()

	-- Render entire panel to texture for cheap per-frame blitting
	renderPanelToTexture(uDefID, uID)
end

local function drawStats(uDefID, uID)
	local mx, my = spGetMouseState()
	local alt, ctrl, meta, shift = spGetModKeyState()
	if WG['chat'] and WG['chat'].isInputActive then
		if WG['chat'].isInputActive() then
			showStats = false
		end
	end

	-- Dirty check for content caching
	local gameFrame = Spring.GetGameFrame()
	local shiftBool = (shift ~= false)
	local contentDirty = (uDefID ~= cachedDefID) or (uID ~= cachedUnitID) or (shiftBool ~= cachedShift)

	if not contentDirty and uID and (gameFrame - lastComputeFrame >= COMPUTE_INTERVAL) then
		local _, bp = Spring.GetUnitIsBeingBuilt(uID)
		if bp ~= cachedBuildProg then
			contentDirty = true
		elseif spGetUnitExperience(uID) ~= cachedExp then
			contentDirty = true
		end
	end

	if contentDirty then
		cachedDefID = uDefID
		cachedUnitID = uID
		cachedShift = shiftBool
		lastComputeFrame = gameFrame
		computeContent(uDefID, uID, shiftBool)
	end

	if not panelTex then return end

	-- === Rendering (every frame) ===

	-- Screen position
	local screenX = mx + xOffset
	local screenY = my + yOffset

	-- Screen-bound correction (bottom)
	local bottomEdge = screenY + panelOffsets[2]
	if bottomEdge < 0 then
		screenY = screenY - bottomEdge
	end
	-- Screen-bound correction (right)
	if screenX + panelOffsets[3] > vsx then
		screenX = vsx - panelOffsets[3]
	end

	-- Blit cached panel texture
	gl.R2tHelper.BlendTexRect(panelTex,
		screenX + panelOffsets[1], screenY + panelOffsets[2],
		screenX + panelOffsets[3], screenY + panelOffsets[4],
		true)

	-- Update guishader only when position changed
	if WG['guishader'] then
		if cachedGuishaderX ~= screenX or cachedGuishaderY ~= screenY then
			guishaderEnabled = true
			cachedGuishaderX = screenX
			cachedGuishaderY = screenY

			local titleFontSize = cachedTitleFontSize
			local tLeft = floor(screenX - bgpadding)
			local tBottom = ceil(screenY - bgpadding)
			local tRight = floor(screenX + cachedTitleTextWidth + (titleFontSize * 3.5))
			local tTop = floor(screenY + (titleFontSize * 1.8) + bgpadding)

			if dlistGuishaderTitle then gl.DeleteList(dlistGuishaderTitle) end
			dlistGuishaderTitle = gl.CreateList(function()
				RectRound(tLeft, tBottom, tRight, tTop, elementCorner, 1,1,1,0)
			end)
			WG['guishader'].InsertScreenDlist(dlistGuishaderTitle, 'unit_stats_title')

			local sLeft = floor(screenX - bgpadding)
			local sBottom = ceil(screenY + cachedContentBottom + (fontSize / 3) + (bgpadding * 0.3))
			local sRight = ceil(screenX + cachedMaxWidth + bgpadding)
			local sTop = ceil(screenY - bgpadding)

			if dlistGuishaderStats then gl.DeleteList(dlistGuishaderStats) end
			dlistGuishaderStats = gl.CreateList(function()
				RectRound(sLeft, sBottom, sRight, sTop, elementCorner, 0,1,1,1)
			end)
			WG['guishader'].InsertScreenDlist(dlistGuishaderStats, 'unit_stats_data')
		end
	end
end

function widget:DrawScreen()
	if WG['topbar'] and WG['topbar'].showingQuit() then
		return
	end

	if WG['chat'] and WG['chat'].isInputActive then
		if WG['chat'].isInputActive() then
			showStats = false
		end
	end
	if (not showStats and not showUnitID) or spIsUserWriting() then
		RemoveGuishader()
		return
	end
	local mx, my = spGetMouseState()
	local uID
	local rType, unitID = spTraceScreenRay(mx, my)
	if rType == 'unit' then
		uID = unitID
	end
	if useSelection then
		if selectedUnitsCount >= 1 then
			uID = selectedUnits[1]
		end
	end
	if showUnitID then
		uID = showUnitID
		showUnitID = nil
	end
	local useHoverID = false
	local _, activeID = Spring.GetActiveCommand()
	if not activeID then activeID = 0 end
	if not uID and (WG['buildmenu'] and not WG['buildmenu'].hoverID) and not (activeID < 0) then
		RemoveGuishader() return
	elseif WG['buildmenu'] and WG['buildmenu'].hoverID and not (activeID < 0) then
		uID = nil
		useHoverID = true
	elseif activeID < 0 then
		uID = nil
		useHoverID = false
	end
	if uID and not Spring.ValidUnitID(uID) then
		RemoveGuishader()
		return
	end
	local uDefID = (uID and spGetUnitDefID(uID)) or (useHoverID and WG['buildmenu'] and WG['buildmenu'].hoverID) or (UnitDefs[-activeID] and -activeID)

	if not uDefID then
		RemoveGuishader()
		return
	end

	drawStats(uDefID, uID)
end
