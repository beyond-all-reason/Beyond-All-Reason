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

local GetUnitTeam = Spring.GetUnitTeam
local GetPlayerInfo = Spring.GetPlayerInfo
local GetTeamInfo = Spring.GetTeamInfo
local GetPlayerList = Spring.GetPlayerList
local GetTeamColor = Spring.GetTeamColor
local GetUnitDefID = Spring.GetUnitDefID
local GetAllUnits = Spring.GetAllUnits
local IsUnitVisible = Spring.IsUnitVisible
local IsUnitIcon = Spring.IsUnitIcon
local GetCameraPosition = Spring.GetCameraPosition
local GetUnitPosition = Spring.GetUnitPosition

local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glDepthTest = gl.DepthTest
local glAlphaTest = gl.AlphaTest
local glColor = gl.Color
local glTranslate = gl.Translate
local glBillboard = gl.Billboard
local glDrawFuncAtUnit = gl.DrawFuncAtUnit
local GL_GREATER = GL.GREATER
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local glBlending = gl.Blending
local glScale = gl.Scale
local glCallList = gl.CallList

local diag = math.diag

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local vsx, vsy = Spring.GetViewGeometry()

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local fontfileSize = 50
local fontfileOutlineSize = 8.5
local fontfileOutlineStrength = 10
local font, shadowFont, fonticon, fontfileScale2

local singleTeams = false
if #Spring.GetTeamList() - 1 == #Spring.GetAllyTeamList() - 1 then
	singleTeams = true
end

local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousName = '?????'

local usedFontSize

local comms = {}
local comnameList = {}
local comnameIconList = {}
local teamColorKeys = {}
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local r, g, b = GetTeamColor(teams[i])
	teamColorKeys[teams[i]] = r..'_'..g..'_'..b
end
teams = nil

local drawScreenUnits = {}
local CheckedForSpec = false

local spec = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local GaiaTeam = Spring.GetGaiaTeamID()

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
	return math.floor(num * mult + 0.5) / mult
end

-- gets the name, color, and height of the commander
local function GetCommAttributes(unitID, unitDefID)
	local team = GetUnitTeam(unitID)
	if team == nil then
		return nil
	end

	local playerRank
	local name = ''
	local luaAI = Spring.GetTeamLuaAI(team)
	if luaAI and luaAI ~= "" and string.find(luaAI, 'Scavengers')  then
		--name = "Scav Commander" -- todo: i18n this thing
		if UnitDefs[unitDefID].customParams.decoyfor then
			name = Spring.I18N('units.scavDecoyCommanderNameTag')
		else
			name = Spring.I18N('units.scavCommanderNameTag')
		end
	elseif Spring.GetGameRulesParam('ainame_' .. team) then
		if UnitDefs[unitDefID].customParams.decoyfor then
			name = Spring.I18N('units.decoyCommanderNameTag')
		else
			name = Spring.I18N('ui.playersList.aiName', { name = Spring.GetGameRulesParam('ainame_' .. team) })
		end

	else
		if UnitDefs[unitDefID].customParams.decoyfor then
			name = Spring.I18N('units.decoyCommanderNameTag')
		else
			local players = GetPlayerList(team)
			name = (#players > 0) and GetPlayerInfo(players[1], false) or '------'
			if players[1] then
				playerRank = select(9, GetPlayerInfo(players[1], false))
			end

			for _, pID in ipairs(players) do
				local pname, active, isspec = GetPlayerInfo(pID, false)
				playerRank = select(9, GetPlayerInfo(pID, false))
				if active and not isspec then
					name = pname
					break
				end
			end
		end
	end

	local r, g, b, a = GetTeamColor(team)
	local bgColor = { 0, 0, 0, 1 }
	if (r + g * 1.2 + b * 0.4) < 0.65 then
		bgColor = { 1, 1, 1, 1 }	-- try to keep these values the same as the playerlist
	end

	local skill
	if showSkillValue then
		local playerID = select(2, GetTeamInfo(team, false))
		local customtable = select(11, GetPlayerInfo(playerID))
		if customtable and customtable.skill then
			skill = customtable.skill
			skill = skill and tonumber(skill:match("-?%d+%.?%d*")) or 0
			skill = round(skill, 0)
		end
	end

	local xp = 0
	local height = comHeight[unitDefID] + heightOffset
	return { name, { r, g, b, a }, height, bgColor, nil, playerRank and playerRank+1, xp, skill}
end

local function RemoveLists()
	for name, list in pairs(comnameList) do
		gl.DeleteList(comnameList[name])
	end
	for name, list in pairs(comnameIconList) do
		gl.DeleteList(comnameIconList[name])
	end
	comnameList = {}
	comnameIconList = {}
end


local function createComnameList(attributes)
	if comnameList[attributes[1]] ~= nil then
		gl.DeleteList(comnameList[attributes[1]])
	end
	comnameList[attributes[1]] = gl.CreateList(function()
		local x,y = 0,0
		if (anonymousMode == "disabled" or spec) and showPlayerRank and attributes[6] and not isSinglePlayer then
			x = (playerRankSize*0.5)
		end
		local outlineColor = { 0, 0, 0, 1 }
		if (attributes[2][1] + attributes[2][2] * 1.2 + attributes[2][3] * 0.4) < 0.65 then
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
	local teams = Spring.GetTeamList()
	for i = 1, #teams do
		local r, g, b = GetTeamColor(teams[i])
		if teamColorKeys[teams[i]] ~= r..'_'..g..'_'..b then
			teamColorKeys[teams[i]] = r..'_'..g..'_'..b
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
	local allUnits = GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		CheckCom(unitID, GetUnitDefID(unitID), GetUnitTeam(unitID))
	end
end

local sec = 0
function widget:Update(dt)
	sec = sec + dt
	if WG['playercolorpalette'] ~= nil then
		if WG['playercolorpalette'].getSameTeamColors and sameTeamColors ~= WG['playercolorpalette'].getSameTeamColors() then
			sameTeamColors = WG['playercolorpalette'].getSameTeamColors()
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
	if not singleTeams and WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors() then
		if myTeamID ~= Spring.GetMyTeamID() then
			-- old
			local name = GetPlayerInfo(select(2, GetTeamInfo(myTeamID, false)), false)
			if comnameList[name] ~= nil then
				comnameList[name] = gl.DeleteList(comnameList[name])
			end
			-- new
			myTeamID = Spring.GetMyTeamID()
			name = GetPlayerInfo(select(2, GetTeamInfo(myTeamID, false)), false)
			if comnameList[name] ~= nil then
				comnameList[name] = gl.DeleteList(comnameList[name])
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
	vsx, vsy = Spring.GetViewGeometry()

	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if not fontfileScale or fontfileScale ~= newFontfileScale then
		RemoveLists()
		CheckAllComs()
		fontfileScale = newFontfileScale
		fontfileScale2 = fontfileScale * 0.66
		font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
		shadowFont = gl.LoadFont(fontfile, fontfileSize * fontfileScale, 35 * fontfileScale, 1.6)
		fonticon = gl.LoadFont(fontfile, fontfileSize * fontfileScale2, fontfileOutlineSize * fontfileScale2, fontfileOutlineStrength * 0.33)
	end
end

local function createComnameIconList(unitID, attributes)
	if comnameIconList[attributes[1]] ~= nil then
		gl.DeleteList(comnameIconList[attributes[1]])
	end
	comnameIconList[attributes[1]] = gl.CreateList(function()
		local x, y, z = GetUnitPosition(unitID)
		x, z = Spring.WorldToScreenCoords(x, y, z)

		local outlineColor = { 0, 0, 0, 1 }
		if (attributes[2][1] + attributes[2][2] * 1.2 + attributes[2][3] * 0.4) < 0.65 then
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
	end)
end

function widget:DrawScreenEffects()	-- using DrawScreenEffects so that guishader will blur it when needed
	if Spring.IsGUIHidden() then return end
	if Spring.GetGameFrame() < hideBelowGameframe then return end

	for unitID, attributes in pairs(drawScreenUnits) do
		if not comnameIconList[attributes[1]] then
			createComnameIconList(unitID, attributes)
		end
		local x, y, z = GetUnitPosition(unitID)
		if x and y and z then
			x, z = Spring.WorldToScreenCoords(x, y + 50 + heightOffset, z)
			local scale = 1 - (attributes[5] / 25000)
			if scale < 0.5 then
				scale = 0.5
			end
			gl.PushMatrix()
			gl.Translate(x, z, 0)
			gl.Scale(scale, scale, scale)
			gl.CallList(comnameIconList[attributes[1]])
			gl.PopMatrix()
		end
	end
	drawScreenUnits = {}
end




function widget:DrawWorld()
	if Spring.IsGUIHidden() then return end
	if Spring.GetGameFrame() < hideBelowGameframe then return end

	-- untested fix: when you resign, to also show enemy com playernames  (because widget:PlayerChanged() isnt called anymore)
	if spec and not CheckedForSpec and Spring.GetGameFrame() > 0 then
		CheckedForSpec = true
		CheckAllComs()
	end

	glDepthTest(true)
	glAlphaTest(GL_GREATER, 0)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	local camX, camY, camZ = GetCameraPosition()
	local camDistance
	for unitID, attributes in pairs(comms) do
		if IsUnitVisible(unitID, 50) then
			local x, y, z = GetUnitPosition(unitID)
			camDistance = diag(camX - x, camY - y, camZ - z)

			if drawForIcon and IsUnitIcon(unitID) then
				attributes[5] = camDistance
				drawScreenUnits[unitID] = attributes
			else
				usedFontSize = (fontSize * 0.5) + (camDistance / scaleFontAmount)
				glDrawFuncAtUnit(unitID, false, DrawName, attributes)
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
	spec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()

	local name, _ = GetPlayerInfo(playerID, false)
	comnameList[name] = nil
	sec = 99
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
	CheckCom(unitID, GetUnitDefID(unitID), unitTeam)
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
