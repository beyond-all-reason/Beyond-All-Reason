
function widget:GetInfo()
	return {
		name      = "Unit Stats",
		desc      = "Shows detailed unit stats",
		author    = "Niobium",
		date      = "Jan 11, 2009",
		version   = 1.1,
		license   = "GNU GPL, v2 or later",
		layer     = 6,
		enabled   = true,  --  loaded by default?
		handler   = true
	}
end

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

local bgcornerSize			= 8
local bgpadding				= 15

local fontSize = 18
local xOffset = 50 + bgpadding
local yOffset = 10 + bgpadding


local cX, cY, cYstart

--local DAMAGE_PERIOD ,weaponInfo = VFS.Include('LuaRules/Configs/area_damage_defs.lua', nil, VFS.RAW_FIRST)
local DAMAGE_PERIOD ,weaponInfo = 0 , {}

local pplants = {
	["aafus"] = true,
	["afusionplant"] = true,
	["amgeo"] = true,
	["armadvsol"] = true,
	["armckfus"] = true,
	["armfor"] = true,
	["armfus"] = true,
	["armgeo"] = true,
	["armgmm"] = true,
	["armsolar"] = true,
	["armtide"] = true,
	["armuwfus"] = true,
	["armuwfus1"] = true,
	["armwin"] = true,
	["cafus"] = true,
	["cfusionplant"] = true,
	["cmgeo"] = true,
	["coradvsol"] = true,
	["corbhmth"] = true,
	["corbhmth1"] = true,
	["corfus"] = true,
	["corgeo"] = true,
	["corsfus"] = true,
	["corsolar"] = true,
	["cortide"] = true,
	["coruwfus"] = true,
	["corwin"] = true,
	["crnns"] = true,
	["tlladvsolar"] = true,
	["tllatidal"] = true,
	["tllcoldfus"] = true,
	["tllgeo"] = true,
	["tllmedfusion"] = true,
	["tllmegacoldfus"] = true,
	["tllmohogeo"] = true,
	["tllsolar"] = true,
	["tllsolarns"] = true,
	["tlltide"] = true,
	["tlluwfusion"] = true,
	["tllwindtrap"] = true,
	["corawin"] = true,
	["armawin"] = true,
	["coratidal"] = true,
	["armatidal"] = true,
	["armlightfus"] = true,
	["armuwlightfus"] = true,
	["corlightfus"] = true,
	["coruwlightfus"] = true,
	["armgen"] = true,
	["corgen"] = true,
}

local negsolar = {
	["armsolar"] =true,
	["corsolar"] =true,
	["crnns"] =true,
	["tllsolar"] =true,
	["tllsolarns"] =true,
	["tlladvsolar"] =true,
}

------------------------------------------------------------------------------------
-- Speedups
------------------------------------------------------------------------------------

local bgcorner				= ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"

local white = '\255\255\255\255'
local green = "\255\001\255\001"
local red = '\255\255\001\001'
local yellow = '\255\255\255\1'
local orange = '\255\255\128\1'
local blue = '\255\128\128\255'

local metalColor = '\255\48\48\128'
local energyColor = '\255\255\255\128' -- Light yellow
local buildColor = '\255\128\255\128' -- Light green

local max = math.max
local floor = math.floor
local format = string.format
local char = string.char

local glColor = gl.Color
local glText = gl.Text
local glRect = gl.Rect

local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamInfo = Spring.GetTeamInfo
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamColor = Spring.GetTeamColor

local spGetModKeyState = Spring.GetModKeyState
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitExp = Spring.GetUnitExperience
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitTeam = Spring.GetUnitTeam

local spGetUnitExperience = Spring.GetUnitExperience
local spGetUnitSensorRadius = Spring.GetUnitSensorRadius
local tidalStrength = Game.tidal
local windMin = Game.windMin
local windMax = Game.windMax

local uDefs = UnitDefs
local wDefs = WeaponDefs

local myTeamID = Spring.GetMyTeamID
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetTooltip = Spring.GetCurrentTooltip

local vsx, vsy = Spring.GetViewGeometry()

local maxWidth = 0
local textBuffer = {}
local textBufferCount = 0

------------------------------------------------------------------------------------
-- Functions
------------------------------------------------------------------------------------


function RectRound(px,py,sx,sy,cs)
	
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.floor(sx),math.floor(sy),math.floor(cs)
	
	gl.Rect(px+cs, py, sx-cs, sy)
	gl.Rect(sx-cs, py+cs, sx, sy-cs)
	gl.Rect(px+cs, py+cs, px, sy-cs)
	
	gl.Texture(bgcorner)
	gl.TexRect(px, py+cs, px+cs, py)		-- top left
	gl.TexRect(sx, py+cs, sx-cs, py)		-- top right
	gl.TexRect(px, sy-cs, px+cs, sy)		-- bottom left
	gl.TexRect(sx, sy-cs, sx-cs, sy)		-- bottom right
	gl.Texture(false)
end

local function DrawText(t1, t2)
	textBufferCount = textBufferCount + 1
	textBuffer[textBufferCount] = {t1,t2,cX,cY}
	cY = cY - fontSize
	maxWidth = max(maxWidth, (gl.GetTextWidth(t1)*fontSize), (gl.GetTextWidth(t2)*fontSize)+(fontSize*6.5))
end

local function DrawTextBuffer()
	local num = #textBuffer
	for i=1, num do
		glText(textBuffer[i][1], textBuffer[i][3], textBuffer[i][4], fontSize, "o")
		glText(textBuffer[i][2], textBuffer[i][3] + (fontSize*6.5), textBuffer[i][4], fontSize, "o")
	end
end

local function teamColorStr(teamID)
	
	if not teamID then return "\255\255\255\255" end
	
	local R, G, B = spGetTeamColor(teamID)
	
	if not R then return "\255\255\255\255" end
	
	R = floor(R * 255)
	G = floor(G * 255)
	B = floor(B * 255)
	
	if (R < 11) then R = 11	end -- Note: char(10) terminates string
	if (G < 11) then G = 11	end
	if (B < 11) then B = 11	end
	
	return "\255" .. char(R) .. char(G) .. char(B)
end

local function teamName(teamID)
	
	if not teamID then
		return "Error:NoTeamID"
	end
	
	local _, teamLeader = spGetTeamInfo(teamID)
	if not teamLeader then
		return "Error:NoLeader"
	end
	
	local leaderName = spGetPlayerInfo(teamLeader)
	return leaderName or "Error:NoName"
end

local guishaderEnabled = false	-- not a config var
function RemoveGuishader()
	if guishaderEnabled and WG['guishader_api'] ~= nil then
		WG['guishader_api'].RemoveRect('unit_stats_title')
		WG['guishader_api'].RemoveRect('unit_stats_data')
		guishaderEnabled = false
	end
end

------------------------------------------------------------------------------------
-- Code
------------------------------------------------------------------------------------
function widget:Initialize()
	local highlightWidget = widgetHandler:FindWidget("HighlightUnit")
	if highlightWidget then
		widgetHandler:RemoveWidgetCallIn("DrawScreen", highlightWidget)
	end
end

function widget:Shutdown()
	local highlightWidget = widgetHandler:FindWidget("HighlightUnit")
	if highlightWidget then
		widgetHandler:UpdateWidgetCallIn("DrawScreen", highlightWidget)
	end
	RemoveGuishader()
end

function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()
end

function widget:DrawScreen()
	
	local alt, ctrl, meta, shift = spGetModKeyState()
	if not meta then RemoveGuishader() return end
	
	local mx, my = spGetMouseState()
	local rType, uID = spTraceScreenRay(mx, my)

	if (rType ~= "unit") or not uID then RemoveGuishader() return end
	
	local uDefID = spGetUnitDefID(uID) ; if not uDefID then RemoveGuishader() return end
	
	local uDef = uDefs[uDefID]
	local _, _, _, _, buildProg = spGetUnitHealth(uID)
	local uTeam = spGetUnitTeam(uID)
	
	maxWidth = 0
	
	cX = mx + xOffset
	cY = my + yOffset
	cYstart = cY
	
	local text = yellow .. uDef.humanName .. white .. "    " .. uDef.name .. "    (#" .. uID .. " , "..teamColorStr(uTeam) .. teamName(uTeam) .. white .. ")"
	
	glColor(0,0,0,0.5)
	RectRound(cX-bgpadding, cY-bgpadding, cX+(gl.GetTextWidth(text)*fontSize)+bgpadding, cY+(fontSize/2)+bgpadding, bgcornerSize)
	
	if (WG['guishader_api'] ~= nil) then
		guishaderEnabled = true
		WG['guishader_api'].InsertRect(cX-bgpadding, cY-bgpadding, cX+(gl.GetTextWidth(text)*fontSize)+bgpadding, cY+(fontSize/2)+bgpadding, 'unit_stats_title')
	end
	
	glColor(1.0, 1.0, 1.0, 1.0)
	glText(text, cX, cY, fontSize, "o")
	cY = cY - 2 * fontSize
	textBuffer = {}
	textBufferCount = 0
	
	if(WG.energyConversion) then
		local makerTemp = WG.energyConversion.convertCapacities[uDefID]
		local curAvgEffi = spGetTeamRulesParam(myTeamID(), 'mmAvgEffi')
		local avgCR = 0.015
		if(makerTemp) then 
			DrawText(orange .. "Metal maker properties", '')
			DrawText("M-Capac.", makerTemp.c)
			DrawText("M-Effi.", format('%.2f m / 1000 e', makerTemp.e * 1000))
			cY = cY - fontSize
		end

		if pplants[uDef.name] then
		-- Powerplants 
			DrawText(orange .. "Powerplant properties", '')
			DrawText("CR is metal maker conversion rate", '')
			
			local totalEOut = uDef.energyMake
			
			if negsolar[uDef.name] then
				totalEOut = totalEOut + math.abs(uDef.energyUpkeep)
			end
			
			if (uDef.tidalGenerator > 0 and tidalStrength > 0) then
			    local mult = 1 -- DEFAULT
			    if uDef.customParams then
					mult = uDef.customParams.energymultiplier or mult
			    end
				totalEOut = totalEOut +(tidalStrength * mult)
			end
			
			if (uDef.windGenerator > 0) then
				local mult = 1 -- DEFAULT
			    if uDef.customParams then
					mult = uDef.customParams.energymultiplier or mult
			    end
				
				local unitWindMin = math.min(windMin, uDef.windGenerator)
				local unitWindMax = math.min(windMax, uDef.windGenerator)
				totalEOut = totalEOut + (((unitWindMin + unitWindMax) / 2 ) * mult)
			end
			
			DrawText("Avg. E-Out.", totalEOut)
			DrawText("M-Cost.", uDef.metalCost)
			
			DrawText("Avg-Effi.", format('%.2f%% e / (m + e * avg. CR) ', totalEOut * 100 / (uDef.metalCost + uDef.energyCost * avgCR)))
			if(curAvgEffi>0) then
				DrawText("Curr-Effi.", format('%.2f%% e / (m + e * curr. CR) ', totalEOut * 100 / (uDef.metalCost + uDef.energyCost * curAvgEffi)))
			end
			cY = cY - fontSize
		end
			
		if not (#uDef.weapons>0) or uDef.isBuilding or pplants[uDef.name] then
			if ((uDef.extractsMetal and uDef.extractsMetal  > 0) or (uDef.metalMake and uDef.metalMake > 0) or (uDef.energyMake and uDef.energyMake>0) or (uDef.tidalGenerator and uDef.tidalGenerator > 0)  or (uDef.windGenerator and uDef.windGenerator > 0)) then
			-- Powerplants 
				--DrawText(metalColor .. "Total metal generation efficiency", '')
				DrawText(metalColor .. "Estimated time of recovering 100% of cost", '')
				
				local totalMOut = uDef.metalMake or 0
				local totalEOut = uDef.energyMake or 0
				
				if (uDef.extractsMetal and uDef.extractsMetal  > 0) then
					local metalExtractor = {inc = 0, out = 0, passed= false}
					local tooltip = spGetTooltip()
					string.gsub(tooltip, 'Metal ....%d+%.%d', function(x) string.gsub(x, "%d+%.%d", function(y) metalExtractor.inc = tonumber(y); end) end)
					string.gsub(tooltip, 'Energy ....%d+%.%d+..../....-%d+%.%d+', function(x) string.gsub(x, "%d+%.%d", function(y) if (metalExtractor.passed) then metalExtractor.out = tonumber(y); else metalExtractor.passed = true end; end) end)
					
					totalMOut = totalMOut + metalExtractor.inc
					totalEOut = totalEOut -  metalExtractor.out
				end
				
				if (uDef.tidalGenerator > 0 and tidalStrength > 0) then
					  local mult = 1 -- DEFAULT
					  if uDef.customParams then
						mult = uDef.customParams.energymultiplier or mult
					  end
					  
					totalEOut = totalEOut + tidalStrength * mult
				end
				
				if (uDef.windGenerator > 0) then
				
					  local mult = 1 -- DEFAULT
					  if uDef.customParams then
						mult = uDef.customParams.energymultiplier or mult
					  end
				
					local unitWindMin = math.min(windMin, uDef.windGenerator)
					local unitWindMax = math.min(windMax, uDef.windGenerator)
					totalEOut = totalEOut + ((unitWindMin + unitWindMax) / 2) * mult
				end
		
				if(totalEOut * avgCR + totalMOut > 0) then
				
					local avgSec = (uDef.metalCost + uDef.energyCost * avgCR)/(totalEOut * avgCR + totalMOut)
					local currSec = (uDef.metalCost + uDef.energyCost * curAvgEffi)/(totalEOut * curAvgEffi + totalMOut)
				
					DrawText('Average ', format('%i sec (%i min %i sec)', avgSec, avgSec/60, avgSec%60))
					if(curAvgEffi>0) then
						DrawText('Current ', format('%i sec (%i min %i sec)', currSec, currSec/60, currSec%60))
					end
				else
					DrawText('Average ', "Unknown")
				end
				cY = cY - fontSize
			end
		end
	end
	
	-- Units that are still building
	if buildProg and buildProg < 1 then
		
		local myTeamID = spGetMyTeamID()
		local mCur, mStor, mPull, mInc, mExp, mShare, mSent, mRec = spGetTeamResources(myTeamID, 'metal')
		local eCur, eStor, ePull, eInc, eExp, eShare, eSent, eRec = spGetTeamResources(myTeamID, 'energy')
		
		local mTotal = uDef.metalCost
		local eTotal = uDef.energyCost
		local buildRem = 1 - buildProg
		local mRem = mTotal * buildRem
		local eRem = eTotal * buildRem
		local mEta = (mRem - mCur) / (mInc + mRec)
		local eEta = (eRem - eCur) / (eInc + eRec)
		
		DrawText("Prog", format("%d%% / %d%%", 100 * buildProg, 100 * buildRem))
		DrawText("Metal", format("%d / %d (" .. yellow .. "%d" .. white .. ")", mTotal * buildProg, mTotal, (mTotal * buildRem) + 1))
		DrawText("Energy", format("%d / %d (" .. yellow .. "%d" .. white .. ")", eTotal * buildProg, eTotal, (eTotal * buildRem) + 1))
		cY = cY - fontSize
	end
	
	------------------------------------------------------------------------------------
	-- Generic information, cost, move, class
	------------------------------------------------------------------------------------
	DrawText("Cost", format(metalColor .. '%d' .. white .. ' / ' ..
							energyColor .. '%d' .. white .. ' / ' ..
							buildColor .. '%d', uDef.metalCost, uDef.energyCost, uDef.buildTime)
			)
		if not (uDef.isBuilding or uDef.isFactory) then
		DrawText("Move", format("%.1f / %.1f / %.0f (Speed / Accel / Turn)", uDef.speed, 900 * uDef.maxAcc, 30 * uDef.turnRate * (180 / 32767)))
	end
	
	DrawText("Class", Game.armorTypes[uDef.armorType or 0] or '???')
	
	local losRadius = spGetUnitSensorRadius(uID, 'los') or 0
	local airLosRadius = spGetUnitSensorRadius(uID, 'airLos') or 0
	local seismicRadius = spGetUnitSensorRadius(uID, 'seismic') or 0


	DrawText('Los', losRadius .. (airLosRadius > losRadius and format(' (AirLos %d)', airLosRadius) or ''))
	if uDef.radarRadius >= 64 then DrawText("Radar", format(green .. "%d", uDef.radarRadius)) end
	if uDef.sonarRadius >= 64 then DrawText("Sonar", format(blue .. "%d", uDef.sonarRadius)) end
	if uDef.jammerRadius >= 64 then DrawText("Jam", format(orange .. "%d", uDef.jammerRadius)) end
	if seismicRadius > 0 then DrawText('Seis' , '\255\255\26\255' .. seismicRadius) end

	if uDef.buildSpeed > 0 then DrawText("Build", format(yellow .. "%d", uDef.buildSpeed)) end
	if uDef.buildDistance > 0 then DrawText("B Dist", format(yellow .. "%d", uDef.buildDistance)) end
	if (uDef.repairSpeed > 0 and uDef.repairSpeed ~= uDef.buildSpeed) then DrawText("Repair", format(yellow .. "%d", uDef.repairSpeed)) end
	if (uDef.reclaimSpeed > 0 and uDef.reclaimSpeed ~= uDef.buildSpeed) then DrawText("Reclaim", format(yellow .. "%d", uDef.reclaimSpeed)) end
	if (uDef.resurrectSpeed > 0 and uDef.resurrectSpeed ~= uDef.buildSpeed) then DrawText("Resurrect", format(yellow .. "%d", uDef.resurrectSpeed)) end
	if (uDef.captureSpeed > 0 and uDef.captureSpeed ~= uDef.buildSpeed) then DrawText("Capture", format(yellow .. "%d", uDef.captureSpeed)) end
	if (uDef.terraformSpeed > 0 and uDef.terraformSpeed ~= uDef.buildSpeed) then DrawText("Capture", format(yellow .. "%d", uDef.terraformSpeed)) end
	if uDef.stealth then DrawText("Other", "Stealthy") end
	if uDef.mass > 0 then DrawText("Mass", format(orange .. "%d", uDef.mass)) end
	if uDef.isTransport and uDef.transportMass > 0 then DrawText("Transporter Max Mass", format(orange .. "%d", uDef.transportMass)) end
	
	
	cY = cY - fontSize
	
	
	------------------------------------------------------------------------------------
	-- Weapons
	------------------------------------------------------------------------------------
	local uExp = spGetUnitExperience(uID)
	if uExp and (uExp > 0.25) then
		uExp = uExp / (1 + uExp)
		DrawText("Exp", format("+%d%% damage, +%d%% firerate, +%d%% health", 100 * uExp, 100 / (1 - uExp * 0.4) - 100, 70 * uExp))
		cY = cY - fontSize
	end
	
	local wepCounts = {} -- wepCounts[wepDefID] = #
	local wepsCompact = {} -- uWepsCompact[1..n] = wepDefID
	
	local uWeps = uDef.weapons
	for i = 1, #uWeps do
		local wDefID = uWeps[i].weaponDef
		local wCount = wepCounts[wDefID]
		if wCount then
			wepCounts[wDefID] = wCount + 1
		else
			wepCounts[wDefID] = 1
			wepsCompact[#wepsCompact + 1] = wDefID
		end
	end
	
	for i = 1, #wepsCompact do
		
		local wDefId = wepsCompact[i]
		local uWep = wDefs[wDefId]
		
		if uWep.range > 16 and not uWep.name:find("teleport",1,true) then
			
			local oDmg = uWep.damages[0]
			local oBurst = uWep.salvoSize * uWep.projectiles
			local oRld = uWep.stockpile and uWep.stockpileTime or uWep.reload
			local wepCount = wepCounts[wDefId]
			
			if wepCount > 1 then
				DrawText("Weap", format(yellow .. "%dx" .. white .. " %s", wepCount, uWep.type))
			else
				DrawText("Weap", uWep.type)
			end
			
			DrawText("Info", format("%d range, %d aoe, %d%% edge", uWep.range, uWep.damageAreaOfEffect, 100 * uWep.edgeEffectiveness))
			

			if uWep.coverageRange and uWep.stockpile then
			  	DrawText("Anti", format("%d Interceptor Range", uWep.coverageRange))
			end

			local dmgString
			if oBurst > 1 then
				dmgString = format(yellow .. "%d (x%d)" .. white .. " / " .. yellow .. "%.2f" .. white .. " = " .. yellow .. "%.2f", oDmg, oBurst, oRld, oBurst * oDmg / oRld)
			else
				dmgString = format(yellow .. "%d" .. white .. " / " .. yellow .. "%.2f" .. white .. " = " .. yellow .. "%.2f", oDmg, oRld, oDmg / oRld)
			end
			
			if wepCount > 1 then
				dmgString = dmgString .. white .. " (Each)"
			end
			
			DrawText("Dmg", dmgString)
			
			if (uWep.metalCost > 0) or (uWep.energyCost > 0) then
				
				-- Stockpiling weapons are weird
				-- They take the correct amount of resources overall
				-- They take the correct amount of time
				-- They drain (32/30) times more resources than they should (And the listed drain is real, having lower income than listed drain WILL stall you)
				local drainAdjust = uWep.stockpile and 32/30 or 1
				
				DrawText('Cost', format(metalColor .. '%d' .. white .. ', ' ..
										 energyColor .. '%d' .. white .. ' = ' ..
										 metalColor .. '-%d' .. white .. ', ' ..
										 energyColor .. '-%d' .. white .. ' per second',
										 uWep.metalCost,
										 uWep.energyCost,
										 drainAdjust * uWep.metalCost / oRld,
										 drainAdjust * uWep.energyCost / oRld))
			end
			
			cY = cY - fontSize
		end
		if (weaponInfo[wDefId]) then
			local radius = weaponInfo[wDefId].radius
			local damage = weaponInfo[wDefId].damage
			local duration = weaponInfo[wDefId].duration
			DrawText("Area Dmg", format(white .. "%d aoe, %d max damage per second , %d seconds", radius, damage * 30 / DAMAGE_PERIOD, duration / 30 ))
		end
	end
	
	-- background
	glColor(0,0,0,0.33)
	RectRound(cX-bgpadding, cY+(fontSize/3)+bgpadding, cX+maxWidth+bgpadding, cYstart-bgpadding, bgcornerSize)
	
	DrawTextBuffer()
	
	if (WG['guishader_api'] ~= nil) then
		guishaderEnabled = true
		WG['guishader_api'].InsertRect(cX-bgpadding, cYstart-bgpadding, cX+maxWidth+bgpadding, cY+bgpadding, 'unit_stats_data')
	end
	glColor(1,1,1,1)
end

------------------------------------------------------------------------------------
