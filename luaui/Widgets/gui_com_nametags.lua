local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Commander Name Tags",
		desc = "Displays a name tags above commanders.",
		author = "Bluestone, Floris",
		date = "20 february 2015",
		license = "GNU GPL, v2 or later",
		layer = -2,
		enabled = true,
	}
end


-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID
local spGetViewGeometry = Spring.GetViewGeometry
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetSpectatingState = Spring.GetSpectatingState
local spGetUnitTeam = Spring.GetUnitTeam
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamInfo = Spring.GetTeamInfo
local spGetPlayerList = Spring.GetPlayerList
local spGetTeamColor = Spring.GetTeamColor
local spGetUnitDefID = Spring.spGetUnitDefID
local spGetAllUnits = Spring.GetAllUnits
local spIsUnitVisible = Spring.IsUnitVisible
local spIsUnitIcon = Spring.IsUnitIcon
local spGetCameraPosition = Spring.GetCameraPosition
local spGetUnitPosition = Spring.GetUnitPosition
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetTeamList = Spring.GetTeamList
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spGetModOptions = Spring.GetModOptions
local spGetConfigString = Spring.GetConfigString
local spIsGUIHidden = Spring.IsGUIHidden

-- Localized Lua functions
local mathFloor = math.floor
local mathDiag = math.diag
local stringFind = string.find
local pairs = pairs
local select = select
local tonumber = tonumber

-- Localized GL functions
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glDepthTest = gl.DepthTest
local glAlphaTest = gl.AlphaTest
local glColor = gl.Color
local glTranslate = gl.Translate
local glBillboard = gl.Billboard
local glDrawFuncAtUnit = gl.DrawFuncAtUnit
local glBlending = gl.Blending
local glScale = gl.Scale
local glCallList = gl.CallList
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glDeleteList = gl.DeleteList
local glCreateList = gl.CreateList
local glLoadFont = gl.LoadFont

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local hideBelowGameframe = 130	-- delay to give spawn fx some time
local drawForIcon = true      -- note that commander icon still gets drawn on top of the name
local nameScaling = true
local useThickLeterring = false  -- Sorry, the performance cost of this is quite high :( doubles the cost of a draw call
local heightOffset = 50
local fontSize = 15        -- not real fontsize, it will be scaled
local scaleFontAmount = 120
local fontShadow = true        -- only shows if font has a white outline
local shadowOpacity = 0.35

local showPlayerRank = false
local showSkillValue = true
local playerRankSize = fontSize * 1.05
local playerRankImages = "luaui\\images\\advplayerslist\\ranks\\"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local ColorIsDark = Spring.Utilities.Color.ColorIsDark

local GL_GREATER = GL.GREATER
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local vsx, vsy = spGetViewGeometry()

local fontfile = "fonts/" .. spGetConfigString("bar_font2", "Exo2-SemiBold.otf")
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local fontfileSize = 50
local fontfileOutlineSize = 8.5
local fontfileOutlineStrength = 10
local font = glLoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
local shadowFont = glLoadFont(fontfile, fontfileSize * fontfileScale, 35 * fontfileScale, 1.6)
local fontfileScale2 = fontfileScale * 0.66
local fonticon = glLoadFont(fontfile, fontfileSize * fontfileScale2, fontfileOutlineSize * fontfileScale2, fontfileOutlineStrength * 0.33)

local singleTeams = false
local teamListLen = #spGetTeamList()
local allyTeamListLen = #Spring.GetAllyTeamList()
if teamListLen - 1 == allyTeamListLen - 1 then
	singleTeams = true
end

local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()

local anonymousMode = spGetModOptions().teamcolors_anonymous_mode
local anonymousName = '?????'

local usedFontSize

local comms = {}
local comnameList = {}
local comnameIconList = {}
local teamColorKeys = {}
local teams = spGetTeamList()
local teamsLen = #teams
local stringFormat = string.format
for i = 1, teamsLen do
	local teamID = teams[i]
	local r, g, b = spGetTeamColor(teamID)
	teamColorKeys[teamID] = stringFormat("%s_%s_%s", r, g, b)
end
teams = nil

local drawScreenUnits = {}
local CheckedForSpec = false

local spec = spGetSpectatingState()
local myTeamID = spGetMyTeamID()
local GaiaTeam = spGetGaiaTeamID()

local comHeight = {}
for unitDefID, defs in pairs(UnitDefs) do
	if defs.customParams.iscommander or defs.customParams.isdecoycommander or defs.customParams.isscavcommander or defs.customParams.isscavdecoycommander then
		comHeight[unitDefID] = defs.height
	end
end

local sameTeamColors = false
if WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors ~= nil then
	sameTeamColors = WG['playercolorpalette'].getSameTeamColors()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function round(num, idp)
	local mult = 10 ^ (idp or 0)
	return mathFloor(num * mult + 0.5) / mult
end

-- gets the name, color, and height of the commander
local function GetCommAttributes(unitID, unitDefID)
	local team = spGetUnitTeam(unitID)
	if team == nil then
		return nil
	end

	local playerRank
	local name = ''
	local luaAI = spGetTeamLuaAI(team)
	if luaAI and luaAI ~= "" and stringFind(luaAI, 'Scavengers')  then
		--name = "Scav Commander" -- todo: i18n this thing
		local unitDefCustomParams = UnitDefs[unitDefID].customParams
		if unitDefCustomParams.decoyfor then
			name = Spring.I18N('units.scavDecoyCommanderNameTag')
		else
			name = Spring.I18N('units.scavCommanderNameTag')
		end
	elseif spGetGameRulesParam('ainame_' .. team) then
		local unitDefCustomParams = UnitDefs[unitDefID].customParams
		if unitDefCustomParams.decoyfor then
			name = Spring.I18N('units.decoyCommanderNameTag')
		else
			name = Spring.I18N('ui.playersList.aiName', { name = spGetGameRulesParam('ainame_' .. team) })
		end

	else
		local unitDefCustomParams = UnitDefs[unitDefID].customParams
		if unitDefCustomParams.decoyfor then
			name = Spring.I18N('units.decoyCommanderNameTag')
		else
			local players = spGetPlayerList(team)
			local playersLen = players and #players or 0
			if playersLen > 0 then
				local firstPlayer = players[1]
				name = spGetPlayerInfo(firstPlayer, false) or '------'
				name = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(firstPlayer)) or name
				playerRank = select(9, spGetPlayerInfo(firstPlayer, false))
			else
				name = '------'
			end

			if playersLen > 0 then
				for i = 1, playersLen do
					local pID = players[i]
					local pname, active, isspec = spGetPlayerInfo(pID, false)
					if active and not isspec then
						pname = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(pID)) or pname
						playerRank = select(9, spGetPlayerInfo(pID, false))
						name = pname
						break
					end
				end
			end
		end
	end

	local r, g, b, a = spGetTeamColor(team)
	local bgColor = { 0, 0, 0, 1 }
	if ColorIsDark(r, g, b) then
		bgColor = { 1, 1, 1, 1 }	-- try to keep these values the same as the playerlist
	end

	local skill
	if showSkillValue then
		local playerID = select(2, spGetTeamInfo(team, false))
		if playerID then
			local customtable = select(11, spGetPlayerInfo(playerID))
			if customtable and customtable.skill then
				skill = customtable.skill
				skill = skill and tonumber(skill:match("-?%d+%.?%d*")) or 0
				skill = round(skill, 0)

				if customtable.skilluncertainty and tonumber(customtable.skilluncertainty) > 6.65 then
					skill = "??"
				end
			end
		end
	end

	local xp = 0
	local height = comHeight[unitDefID] + heightOffset
	return { name, { r, g, b, a }, height, bgColor, nil, playerRank and playerRank+1, xp, skill}
end

local function RemoveLists()
	for name in pairs(comnameList) do
		glDeleteList(comnameList[name])
	end
	for name in pairs(comnameIconList) do
		glDeleteList(comnameIconList[name])
	end
	comnameList = {}
	comnameIconList = {}
end


local function createComnameList(attributes)
	if comnameList[attributes[1]] ~= nil then
		glDeleteList(comnameList[attributes[1]])
	end
	comnameList[attributes[1]] = glCreateList(function()
		local x,y = 0,0
		if (anonymousMode == "disabled" or spec) and showPlayerRank and attributes[6] and not isSinglePlayer then
			x = (playerRankSize*0.5)
		end
		local outlineColor = { 0, 0, 0, 1 }
		if ColorIsDark(attributes[2][1], attributes[2][2], attributes[2][3]) then
			outlineColor = { 1, 1, 1, 1 }		-- try to keep these values the same as the playerlist
		end
		local name = attributes[1]
		if anonymousMode ~= "disabled" and not spec then
			name = anonymousName
		end
		if useThickLeterring then
			if outlineColor[1] == 1 and fontShadow then
				glTranslate(0, -(fontSize / 44), 0)
				shadowFont:Begin()
				shadowFont:SetTextColor({ 0, 0, 0, shadowOpacity })
				shadowFont:SetOutlineColor({ 0, 0, 0, shadowOpacity })
				shadowFont:Print(name, x, y, fontSize, "con")
				shadowFont:End()
				glTranslate(0, (fontSize / 44), 0)
			end
			font:SetTextColor(outlineColor)
			font:SetOutlineColor(outlineColor)

			font:Print(name, x-(fontSize / 38), y-(fontSize / 33), fontSize, "con")
			font:Print(name, x+(fontSize / 38), y-(fontSize / 33), fontSize, "con")
		end
		font:Begin()
		font:SetTextColor(attributes[2])
		font:SetOutlineColor(outlineColor)
		font:Print(name, x, y, fontSize, "con")
		font:End()

		-- player rank
		if showPlayerRank and attributes[6] and (anonymousMode == "disabled" or spec) and not isSinglePlayer then
			local halfSize = playerRankSize*0.5
			local x_l = x - (((font:GetTextWidth(name) * fontSize) * 0.5) + halfSize + (fontSize * 0.1))
			local y_l = y + (fontSize * 0.33)
			glTexture(playerRankImages..attributes[6]..'.png')
			glTexRect(x_l-halfSize, y_l-halfSize, x_l+halfSize, y_l+halfSize)
			glTexture(false)

			-- skill value
			if showSkillValue and attributes[8] then
				font:Begin()
				font:SetTextColor(0.66,0.66,0.66,1)
				font:SetOutlineColor(0,0,0,0.6)
				font:Print(attributes[8], x_l-(playerRankSize*0.86), y_l-(playerRankSize*0.29), playerRankSize*0.66, "con")
				font:End()
			end
		end
	end)
end


local function CheckCom(unitID, unitDefID, unitTeam)
	if comHeight[unitDefID] and unitTeam ~= GaiaTeam then
		if unitTeam ~= GaiaTeam then
			comms[unitID] = GetCommAttributes(unitID, unitDefID)
		end
	elseif comms[unitID] then
		comms[unitID] = nil
	end
end


-- check if team colors have changed
local function CheckTeamColors()
	local detectedChanges = false
	local teams = spGetTeamList()
	local teamsLen = #teams
	for i = 1, teamsLen do
		local teamID = teams[i]
		local r, g, b = spGetTeamColor(teamID)
		local colorKey = stringFormat("%s_%s_%s", r, g, b)
		if teamColorKeys[teamID] ~= colorKey then
			teamColorKeys[teamID] = colorKey
			detectedChanges = true
		end
	end
	if detectedChanges then
		RemoveLists()
	end
end


local function CheckAllComs()
	CheckTeamColors()

	-- check commanders
	local allUnits = spGetAllUnits()
	local allUnitsLen = #allUnits
	for i = 1, allUnitsLen do
		local unitID = allUnits[i]
		CheckCom(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID))
	end
end

local sec = 0
function widget:Update(dt)
	sec = sec + dt
	local playerColorPalette = WG['playercolorpalette']
	if playerColorPalette ~= nil then
		local getSameTeamColors = playerColorPalette.getSameTeamColors
		if getSameTeamColors and sameTeamColors ~= getSameTeamColors() then
			sameTeamColors = getSameTeamColors()
			RemoveLists()
			CheckAllComs()
			sec = 0
		end
	elseif sameTeamColors then
		sameTeamColors = false
		RemoveLists()
		CheckAllComs()
		sec = 0
	end
	if not singleTeams and playerColorPalette ~= nil and playerColorPalette.getSameTeamColors then
		local currentTeamID = spGetMyTeamID()
		if myTeamID ~= currentTeamID then
			-- old
			local teamPlayerID = select(2, spGetTeamInfo(myTeamID, false))
			local name = spGetPlayerInfo(teamPlayerID, false)
			name = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(teamPlayerID)) or name
			if comnameList[name] ~= nil then
				comnameList[name] = glDeleteList(comnameList[name])
			end
			if comnameIconList[name] ~= nil then
				comnameIconList[name] = glDeleteList(comnameIconList[name])
			end
			myTeamID = currentTeamID
			teamPlayerID = select(2, spGetTeamInfo(myTeamID, false))
			name = spGetPlayerInfo(teamPlayerID, false)
			name = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(teamPlayerID)) or name
			if comnameList[name] ~= nil then
				comnameList[name] = glDeleteList(comnameList[name])
			end
			if comnameIconList[name] ~= nil then
				comnameIconList[name] = glDeleteList(comnameIconList[name])
			end
			CheckAllComs()
			sec = 0
		end
	end
	if sec > 1.2 then
		sec = 0
		CheckAllComs()
	end
end

local function DrawName(attributes)
	if comnameList[attributes[1]] == nil then
		createComnameList(attributes)
	end
	glTranslate(0, attributes[3], 0)
	glBillboard()
	if nameScaling then
		glScale(usedFontSize / fontSize, usedFontSize / fontSize, usedFontSize / fontSize)
	end
	glCallList(comnameList[attributes[1]])

	if nameScaling then
		glScale(1, 1, 1)
	end
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()

	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		RemoveLists()
		CheckAllComs()
		fontfileScale = newFontfileScale
		fontfileScale2 = fontfileScale * 0.66
		font = glLoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
		shadowFont = glLoadFont(fontfile, fontfileSize * fontfileScale, 35 * fontfileScale, 1.6)
		fonticon = glLoadFont(fontfile, fontfileSize * fontfileScale2, fontfileOutlineSize * fontfileScale2, fontfileOutlineStrength * 0.33)
	end
end

local function createComnameIconList(unitID, attributes)
	if comnameIconList[attributes[1]] ~= nil then
		glDeleteList(comnameIconList[attributes[1]])
	end
	comnameIconList[attributes[1]] = glCreateList(function()
		local x, y, z = spGetUnitPosition(unitID)
		if x and y and z then
			x, z = spWorldToScreenCoords(x, y, z)

			local outlineColor = { 0, 0, 0, 1 }
			if ColorIsDark(attributes[2][1], attributes[2][2], attributes[2][3]) then
				-- try to keep these values the same as the playerlist
				outlineColor = { 1, 1, 1, 1 }
			end
			local name = attributes[1]
			if anonymousMode ~= "disabled" and (not spec) then
				name = anonymousName
			end
			fonticon:Begin()
			fonticon:SetTextColor(attributes[2])
			fonticon:SetOutlineColor(outlineColor)
			fonticon:Print(name, 0, 0, fontSize * 1.9, "con")
			fonticon:End()
		end
	end)
end

function widget:DrawScreenEffects()	-- using DrawScreenEffects so that guishader will blur it when needed
	if spIsGUIHidden() then return end
	if spGetGameFrame() < hideBelowGameframe then return end

	for unitID, attributes in pairs(drawScreenUnits) do
		if not comnameIconList[attributes[1]] then
			createComnameIconList(unitID, attributes)
		end
		local x, y, z = spGetUnitPosition(unitID)
		if x and y and z then
			x, z = spWorldToScreenCoords(x, y + 50 + heightOffset, z)
			local scale = 1 - (attributes[5] / 25000)
			if scale < 0.5 then
				scale = 0.5
			end
			glPushMatrix()
			glTranslate(x, z, 0)
			glScale(scale, scale, scale)
			glCallList(comnameIconList[attributes[1]])
			glPopMatrix()
		end
	end
	drawScreenUnits = {}
end




function widget:DrawWorld()
	if spIsGUIHidden() then return end
	if spGetGameFrame() < hideBelowGameframe then return end

	-- untested fix: when you resign, to also show enemy com playernames  (because widget:PlayerChanged() isnt called anymore)
	if not CheckedForSpec and spGetGameFrame() > 1 then
		if spec then
			CheckedForSpec = true
			CheckAllComs()
		end
	end

	glDepthTest(true)
	glAlphaTest(GL_GREATER, 0)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	local camX, camY, camZ = spGetCameraPosition()
	for unitID, attributes in pairs(comms) do
		if spIsUnitVisible(unitID, 50) then
			local x, y, z = spGetUnitPosition(unitID)
			if x and y and z then
				local camDistance = mathDiag(camX - x, camY - y, camZ - z)

				if drawForIcon and spIsUnitIcon(unitID) then
					attributes[5] = camDistance
					drawScreenUnits[unitID] = attributes
				else
					usedFontSize = (fontSize * 0.5) + (camDistance / scaleFontAmount)
					glDrawFuncAtUnit(unitID, false, DrawName, attributes)
				end
			end
		end
	end

	glAlphaTest(false)
	glColor(1, 1, 1, 1)
	glDepthTest(false)
end

function widget:Initialize()
	WG.nametags = {}
	WG.nametags.GetShowPlayerRank = function()
		return showPlayerRank
	end
	WG.nametags.SetShowPlayerRank = function(value)
		showPlayerRank = value
		RemoveLists()
		CheckAllComs()
	end

	CheckAllComs()
end

function widget:Shutdown()
	RemoveLists()
	gl.DeleteFont(font)
end

function widget:PlayerChanged(playerID)
	local prevSpec = spec
	spec = spGetSpectatingState()
	myTeamID = spGetMyTeamID()

	local name, _ = spGetPlayerInfo(playerID, false)
	name = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID)) or name
	comnameList[name] = nil
	sec = 99

	if spec and prevSpec ~= spec then
		CheckedForSpec = true
		CheckAllComs()
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	CheckCom(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	comms[unitID] = nil
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	CheckCom(unitID, unitDefID, unitTeam)
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	CheckCom(unitID, unitDefID, unitTeam)
end

function widget:UnitEnteredLos(unitID, unitTeam)
	CheckCom(unitID, spGetUnitDefID(unitID), unitTeam)
end

function toggleNameScaling()
	nameScaling = not nameScaling
	return true
end

function widget:GetConfigData()
	return {
		version = 1.1,
		nameScaling = nameScaling,
		showPlayerRank = showPlayerRank,
	}
end

function widget:SetConfigData(data)
	widgetHandler:AddAction("comnamescale", toggleNameScaling, nil, 'p')
	if data.nameScaling ~= nil then
		nameScaling = data.nameScaling
	end
	if data.version and data.showPlayerRank ~= nil then
		showPlayerRank = data.showPlayerRank
	end
end
