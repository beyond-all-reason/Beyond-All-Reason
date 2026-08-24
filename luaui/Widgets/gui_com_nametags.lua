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
local spGetMyPlayerID = Spring.GetMyPlayerID
local spGetViewGeometry = Spring.GetViewGeometry
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetSpectatingState = Spring.GetSpectatingState
local spGetUnitTeam = Spring.GetUnitTeam
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamInfo = Spring.GetTeamInfo
local spGetPlayerList = Spring.GetPlayerList
local spGetTeamColor = Spring.GetTeamColor
local spGetUnitDefID = Spring.GetUnitDefID
local spGetTeamUnitsByDefs = Spring.GetTeamUnitsByDefs
local spGetTeamUnitDefCount = Spring.GetTeamUnitDefCount
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
local spGetGroundHeight = Spring.GetGroundHeight

-- Localized Lua functions
local mathFloor = math.floor
local mathDiag = math.diag
local stringFind = string.find
local stringChar = string.char
local pairs = pairs
local select = select
local tonumber = tonumber

-- Localized GL functions
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glAlphaTest = gl.AlphaTest
local glColor = gl.Color
local glBlending = gl.Blending
local glLoadFont = gl.LoadFont
local glDeleteFont = gl.DeleteFont

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local hideBelowGameframe = 130 -- delay to give spawn fx some time
local drawForIcon = true -- note that commander icon still gets drawn on top of the name
local nameScaling = true
local useThickLeterring = false -- Sorry, the performance cost of this is quite high :( triples the amount of text drawn
local heightOffset = 50
local fontSize = 15 -- not real fontsize, it will be scaled
local scaleFontAmount = 120
local fontShadow = true -- only shows if font has a white outline
local shadowOpacity = 0.35

local showPlayerRank = false
local showSkillValue = true
local playerRankSize = fontSize * 1.05
local playerRankImages = "luaui\\images\\advplayerslist\\ranks\\"

-- Terrain occlusion of world-anchored nametags is sampled with Spring.GetGroundHeight,
-- which is the most expensive part of the per-frame work. Each commander is re-evaluated
-- only every N draw frames (staggered by unitID) unless the camera jumped.
local occlusionCheckInterval = 4
local cameraJumpDistance = 512 -- camera moved further than this in a single frame -> re-evaluate everything

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local ColorIsDark = BAR.Utilities.Color.ColorIsDark

local GL_GREATER = GL.GREATER
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

-- Inline "text color + outline color" code understood by the engine font renderer.
-- Baking the colors into the string lets all nametags be printed inside a single
-- font:Begin()/font:End() batch (one draw call per font per frame) without any
-- per-name SetTextColor/SetOutlineColor calls or display lists.
local colorAndOutlineCode = (Engine and Engine.textColorCodes and Engine.textColorCodes.ColorAndOutline) or "\254"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local vsx, vsy = spGetViewGeometry()

local fontfile = "fonts/" .. spGetConfigString("bar_font2", "Exo2-SemiBold.otf")
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local fontfileSize = 50
local fontfileOutlineSize = 8.5
local fontfileOutlineStrength = 10
local font, shadowFont, fonticon

local function loadFonts()
	local fontfileScale2 = fontfileScale * 0.66
	font = glLoadFont(
		fontfile,
		fontfileSize * fontfileScale,
		fontfileOutlineSize * fontfileScale,
		fontfileOutlineStrength
	)
	shadowFont = glLoadFont(fontfile, fontfileSize * fontfileScale, 35 * fontfileScale, 1.6)
	fonticon = glLoadFont(
		fontfile,
		fontfileSize * fontfileScale2,
		fontfileOutlineSize * fontfileScale2,
		fontfileOutlineStrength * 0.33
	)
end

local function deleteFonts()
	glDeleteFont(font)
	glDeleteFont(shadowFont)
	glDeleteFont(fonticon)
end

loadFonts()

local isSinglePlayer = BAR.Utilities.Gametype.IsSinglePlayer()

local anonymousMode = spGetModOptions().teamcolors_anonymous_mode
local anonymousName = "?????"

local comms = {} -- unitID -> nametag attributes, see GetCommAttributes()
local occluded = {} -- unitID -> cached terrain-occlusion result of the world-anchored nametag
local CheckedForSpec = false

local spec = spGetSpectatingState()
local GaiaTeam = spGetGaiaTeamID()

-- Resolving the name shown for a team (player list, active/spec flags, rank, skill from the
-- custom player table) costs several GetPlayerInfo calls, so it is cached per team and only
-- re-resolved when players change.
local teamNameInfo = {} -- teamID -> { name, rawName, playerID, rank, skill, decoyName }
local teamColorCache = {} -- teamID -> { r, g, b } as last seen by the team color poll
local teamList = {} -- all non-gaia teams (static for the duration of a game)
local sweepIndex = 0 -- round-robin cursor for the per-team consistency sweep

do
	local teams = spGetTeamList()
	for i = 1, #teams do
		local teamID = teams[i]
		if teamID ~= GaiaTeam then
			teamList[#teamList + 1] = teamID
			local r, g, b = spGetTeamColor(teamID)
			teamColorCache[teamID] = { r, g, b }
		end
	end
end

local lastCamX, lastCamY, lastCamZ = 0, 0, 0
local drawFrame = 0
local iconResScale = math.sqrt(vsy / 1080) -- resolution compensation for icon nametags
local iconFontSize = fontSize * 1.9 * iconResScale

local comHeight = {}
local comIsDecoy = {}
local comDefIDList = {} -- array of commander DefIDs for GetTeamUnitsByDefs / GetTeamUnitDefCount
for unitDefID, defs in pairs(UnitDefs) do
	if
		defs.customParams.iscommander
		or defs.customParams.isdecoycommander
		or defs.customParams.isscavcommander
		or defs.customParams.isscavdecoycommander
	then
		comHeight[unitDefID] = defs.height
		comIsDecoy[unitDefID] = defs.customParams.decoyfor
		comDefIDList[#comDefIDList + 1] = unitDefID
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function round(num, idp)
	local mult = 10 ^ (idp or 0)
	return mathFloor(num * mult + 0.5) / mult
end

local function colorByte(value)
	if value <= 0 then
		return 0
	elseif value >= 1 then
		return 255
	end
	return mathFloor(value * 255 + 0.5)
end

-- prefixes text with an inline color code that sets both the text color and the outline color
local function colorizeText(text, r, g, b, a, outlineR, outlineG, outlineB, outlineA)
	return colorAndOutlineCode
		.. stringChar(
			colorByte(r),
			colorByte(g),
			colorByte(b),
			colorByte(a),
			colorByte(outlineR),
			colorByte(outlineG),
			colorByte(outlineB),
			colorByte(outlineA)
		)
		.. text
end

-- resolves (and caches) what is shown for a team: player name + rank + skill, or AI /
-- scavenger names. Expensive (several GetPlayerInfo calls incl. the custom player table),
-- so the result is cached until players change.
local function GetTeamNameInfo(team)
	local info = teamNameInfo[team]
	if info then
		return info
	end
	info = { decoyName = BAR.I18N("units.decoyCommanderNameTag") }

	local luaAI = spGetTeamLuaAI(team)
	if luaAI and luaAI ~= "" and stringFind(luaAI, "Scavengers") then
		--name = "Scav Commander" -- todo: i18n this thing
		info.name = BAR.I18N("units.scavCommanderNameTag")
		info.decoyName = BAR.I18N("units.scavDecoyCommanderNameTag")
	elseif spGetGameRulesParam("ainame_" .. team) then
		info.name = BAR.I18N("ui.playersList.aiName", { name = spGetGameRulesParam("ainame_" .. team) })
	else
		local playerID, playerRank
		local name = "------"
		local players = spGetPlayerList(team)
		local playersLen = players and #players or 0
		if playersLen > 0 then
			-- default to the first player, prefer the first active non-spectating one
			playerID = players[1]
			name = spGetPlayerInfo(playerID, false) or "------"
			playerRank = select(9, spGetPlayerInfo(playerID, false))
			for i = 1, playersLen do
				local pID = players[i]
				local pname, active, isspec, _, _, _, _, _, rank = spGetPlayerInfo(pID, false)
				if active and not isspec then
					playerID = pID
					name = pname
					playerRank = rank
					break
				end
			end
		end
		info.playerID = playerID
		info.rawName = name
		info.name = (
			playerID
			and WG.playernames
			and WG.playernames.getPlayername
			and WG.playernames.getPlayername(playerID)
		) or name
		info.rank = playerRank and playerRank + 1
	end

	if showSkillValue then
		local playerID = select(2, spGetTeamInfo(team, false))
		if playerID then
			local customtable = select(11, spGetPlayerInfo(playerID))
			if customtable and customtable.skill then
				local skill = customtable.skill
				skill = skill and tonumber(skill:match("-?%d+%.?%d*")) or 0
				skill = round(skill, 0)

				if customtable.skilluncertainty and tonumber(customtable.skilluncertainty) > 6.65 then
					skill = "??"
				end
				info.skill = skill
			end
		end
	end

	teamNameInfo[team] = info
	return info
end

-- builds everything the draw loop needs for a commander: pre-colorized text strings and
-- the world-space height offset. Cheap (team color + string concat), so it is simply
-- re-built whenever a team color / name / rank setting changes.
local function GetCommAttributes(unitDefID, team)
	local info = GetTeamNameInfo(team)
	local isDecoy = comIsDecoy[unitDefID]
	local name = isDecoy and info.decoyName or info.name
	local playerRank = (not isDecoy) and info.rank or nil

	local r, g, b, a = spGetTeamColor(team)
	local lightOutline = ColorIsDark(r, g, b) -- try to keep these values the same as the playerlist
	local o = lightOutline and 1 or 0

	local displayName = name
	if anonymousMode ~= "disabled" and not spec then
		displayName = anonymousName
	end

	local attributes = {
		team = team,
		unitDefID = unitDefID,
		text = colorizeText(displayName, r, g, b, a, o, o, o, 1),
		height = comHeight[unitDefID] + heightOffset,
	}

	if useThickLeterring then
		attributes.thickText = colorizeText(displayName, o, o, o, 1, o, o, o, 1)
		if lightOutline and fontShadow then
			attributes.shadowText = colorizeText(displayName, 0, 0, 0, shadowOpacity, 0, 0, 0, shadowOpacity)
		end
	end

	if showPlayerRank and playerRank and (anonymousMode == "disabled" or spec) and not isSinglePlayer then
		attributes.rankTexture = playerRankImages .. playerRank .. ".png"
		attributes.halfTextWidth = font:GetTextWidth(displayName) * 0.5
		if showSkillValue and info.skill then
			attributes.skillText = colorizeText(tostring(info.skill), 0.66, 0.66, 0.66, 1, 0, 0, 0, 0.6)
		end
	end

	return attributes
end

local function RemoveCom(unitID)
	comms[unitID] = nil
	occluded[unitID] = nil
end

local function CheckCom(unitID, unitDefID, unitTeam)
	if not comHeight[unitDefID] or unitTeam == GaiaTeam then
		RemoveCom(unitID)
		return
	end
	comms[unitID] = GetCommAttributes(unitDefID, unitTeam)
end

-- re-creates the attributes of every tracked commander (of one team, or of all teams)
local function RebuildAttributes(teamID)
	for unitID, attributes in pairs(comms) do
		if teamID == nil or attributes.team == teamID then
			comms[unitID] = GetCommAttributes(attributes.unitDefID, attributes.team)
		end
	end
end

-- Full enumeration of one team's commanders. GetTeamUnitsByDefs scans every unit of the
-- team once per unitDefID in the list (80+ commander defs), which gets expensive for big
-- teams - so this only runs when the cheap tally in SweepTeam disagrees with what we track.
local function EnumerateTeam(teamID)
	local found = spGetTeamUnitsByDefs(teamID, comDefIDList)
	local seen = {}
	if found then
		for i = 1, #found do
			local unitID = found[i]
			seen[unitID] = true
			CheckCom(unitID, spGetUnitDefID(unitID), teamID)
		end
	end
	-- drop tracked commanders the engine no longer reports for this team (died out of LOS, transferred, ...)
	for unitID, attributes in pairs(comms) do
		if attributes.team == teamID and not seen[unitID] then
			RemoveCom(unitID)
		end
	end
end

-- Cheap consistency check: GetTeamUnitDefCount is O(1) per def for allied/spectated teams
-- and only walks the (few) units of that def for enemies. Enumerate only on a mismatch.
local function SweepTeam(teamID)
	local engineCount = 0
	for i = 1, #comDefIDList do
		engineCount = engineCount + (spGetTeamUnitDefCount(teamID, comDefIDList[i]) or 0)
	end
	local trackedCount = 0
	for _, attributes in pairs(comms) do
		if attributes.team == teamID then
			trackedCount = trackedCount + 1
		end
	end
	if engineCount ~= trackedCount then
		EnumerateTeam(teamID)
	end
end

local function CheckAllComs()
	for i = 1, #teamList do
		SweepTeam(teamList[i])
	end
end

-- player assignments changed: re-resolve names, re-colorize everything
local function InvalidateTeamNames()
	teamNameInfo = {}
	RebuildAttributes()
end

local sec = 0
local sweepSec = 0
function widget:Update(dt)
	sec = sec + dt
	sweepSec = sweepSec + dt

	if sweepSec > 0.5 then
		sweepSec = 0

		-- team colors (player color palette / same-team-colors changes)
		for i = 1, #teamList do
			local teamID = teamList[i]
			local r, g, b = spGetTeamColor(teamID)
			local cached = teamColorCache[teamID]
			if not cached then
				teamColorCache[teamID] = { r, g, b }
			elseif cached[1] ~= r or cached[2] ~= g or cached[3] ~= b then
				cached[1], cached[2], cached[3] = r, g, b
				RebuildAttributes(teamID)
			end
		end

		-- verify the tracked commander set of one team per tick (round-robin); unit callins
		-- keep the set up to date, this is only the safety net that used to be a full rescan
		if #teamList > 0 then
			sweepIndex = sweepIndex % #teamList + 1
			SweepTeam(teamList[sweepIndex])
		end
	end

	if sec > 2.0 then
		sec = 0

		-- displayed player names (aliases via WG.playernames can change without a callin)
		for teamID, info in pairs(teamNameInfo) do
			if info.playerID then
				local wantedName = (
					WG.playernames
					and WG.playernames.getPlayername
					and WG.playernames.getPlayername(info.playerID)
				) or info.rawName
				if wantedName ~= info.name then
					info.name = wantedName
					RebuildAttributes(teamID)
				end
			end
		end
	end
end

-- Cheap terrain-occlusion check: sample ground height along the camera->target ray
-- at a few intermediate points. If any sample is above the ray, the target is
-- hidden behind a hill. Used to preserve the "hidden behind terrain" behavior we
-- used to get for free from the depth buffer when drawing in DrawWorld.
local function isOccludedByTerrain(camX, camY, camZ, tx, ty, tz)
	local dx, dy, dz = tx - camX, ty - camY, tz - camZ
	for i = 1, 4 do
		local t = i * 0.2
		local px = camX + dx * t
		local pz = camZ + dz * t
		local py = camY + dy * t
		if spGetGroundHeight(px, pz) > py + 4 then
			return true
		end
	end
	return false
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	iconResScale = math.sqrt(vsy / 1080)
	iconFontSize = fontSize * 1.9 * iconResScale

	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		deleteFonts()
		loadFonts()
		RebuildAttributes() -- cached text widths depend on the font
	end
end

-- Nametags are drawn in DrawScreenEffects so they render after the deferred lighting,
-- distortion, bloom and tonemapping passes (which would otherwise discolor / ripple
-- the text). All nametags are printed inside one font:Begin()/font:End() batch per
-- font, so the whole set costs a single draw call per font per frame.
function widget:DrawScreenEffects()
	if spIsGUIHidden() then
		return
	end
	local gameFrame = spGetGameFrame()
	if gameFrame < hideBelowGameframe then
		return
	end

	-- untested fix: when you resign, to also show enemy com playernames
	if not CheckedForSpec and gameFrame > 1 and spec then
		CheckedForSpec = true
		CheckAllComs()
	end

	drawFrame = drawFrame + 1

	local camX, camY, camZ = spGetCameraPosition()
	-- a big camera jump invalidates every cached occlusion result at once
	local cameraJumped = mathDiag(camX - lastCamX, camY - lastCamY, camZ - lastCamZ) > cameraJumpDistance
	lastCamX, lastCamY, lastCamZ = camX, camY, camZ

	local drawRanks = showPlayerRank
	if drawRanks then
		glAlphaTest(GL_GREATER, 0)
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end

	local fontBegun, iconFontBegun, shadowFontBegun = false, false, false
	local boundRankTexture

	for unitID, attributes in pairs(comms) do
		if spIsUnitVisible(unitID, 50, false) then
			local ux, uy, uz = spGetUnitPosition(unitID)
			if ux then
				if drawForIcon and spIsUnitIcon(unitID) then
					-- Icon-mode nametag: fixed screen size, slightly shrinking with camera distance
					local sx, sy = spWorldToScreenCoords(ux, uy + 50 + heightOffset, uz)
					local scale = 1 - mathDiag(camX - ux, camY - uy, camZ - uz) / 25000
					if scale < 0.5 then
						scale = 0.5
					end
					if not iconFontBegun then
						fonticon:Begin()
						iconFontBegun = true
					end
					fonticon:Print(attributes.text, sx, sy, iconFontSize * scale, "con")
				else
					-- World-anchored nametag, projected into screen space
					local ty = uy + attributes.height
					local sx, sy = spWorldToScreenCoords(ux, ty, uz)
					if sx > -200 and sx < vsx + 200 and sy > -100 and sy < vsy + 100 then
						local isOccluded = occluded[unitID]
						if isOccluded == nil or cameraJumped or (drawFrame + unitID) % occlusionCheckInterval == 0 then
							isOccluded = isOccludedByTerrain(camX, camY, camZ, ux, ty, uz)
							occluded[unitID] = isOccluded
						end
						if not isOccluded then
							local camDistance = mathDiag(camX - ux, camY - uy, camZ - uz)
							if camDistance < 150 then
								camDistance = 150
							end
							-- Approximate the previous billboarded scale: the world-space
							-- formula was usedFontSize = 0.5*fontSize + camDistance/scaleFontAmount,
							-- billboarded; perspective then shrunk it by ~focalPx/camDistance.
							-- Collapsing both gives a nearly distance-independent pixel size with
							-- a small near-camera bump.
							local screenScale = (0.5 + camDistance / (scaleFontAmount * fontSize))
								* (vsy * 1.22 / camDistance)
							if screenScale < 0.9 then
								screenScale = 0.9
							elseif screenScale > 5.0 then
								screenScale = 5.0
							end
							local size = fontSize * screenScale
							local rankTexture = attributes.rankTexture
							if rankTexture then
								sx = sx + playerRankSize * 0.5 * screenScale -- make room for the rank icon
							end

							if not fontBegun then
								font:Begin()
								fontBegun = true
							end
							if useThickLeterring then
								local shadowText = attributes.shadowText
								if shadowText then
									if not shadowFontBegun then
										shadowFont:Begin()
										shadowFontBegun = true
									end
									shadowFont:Print(shadowText, sx, sy - size / 44, size, "con")
								end
								local thickText = attributes.thickText
								font:Print(thickText, sx - size / 38, sy - size / 33, size, "con")
								font:Print(thickText, sx + size / 38, sy - size / 33, size, "con")
							end
							font:Print(attributes.text, sx, sy, size, "con")

							-- player rank (+ skill value)
							if rankTexture then
								local halfSize = playerRankSize * 0.5 * screenScale
								local x_l = sx - (attributes.halfTextWidth * size + halfSize + size * 0.1)
								local y_l = sy + size * 0.33
								if rankTexture ~= boundRankTexture then
									glTexture(rankTexture)
									boundRankTexture = rankTexture
								end
								glTexRect(x_l - halfSize, y_l - halfSize, x_l + halfSize, y_l + halfSize)
								local skillText = attributes.skillText
								if skillText then
									font:Print(
										skillText,
										x_l - playerRankSize * 0.86 * screenScale,
										y_l - playerRankSize * 0.29 * screenScale,
										playerRankSize * 0.66 * screenScale,
										"con"
									)
								end
							end
						end
					end
				end
			end
		end
	end

	if shadowFontBegun then
		shadowFont:End()
	end
	if fontBegun then
		font:End()
	end
	if iconFontBegun then
		fonticon:End()
	end

	if drawRanks then
		if boundRankTexture then
			glTexture(false)
		end
		glAlphaTest(false)
		glColor(1, 1, 1, 1)
	end
end

function widget:Initialize()
	WG.nametags = {}
	WG.nametags.GetShowPlayerRank = function()
		return showPlayerRank
	end
	WG.nametags.SetShowPlayerRank = function(value)
		showPlayerRank = value
		RebuildAttributes()
	end

	CheckAllComs()
end

function widget:Shutdown()
	deleteFonts()
end

function widget:PlayerChanged(playerID)
	local prevSpec = spec
	spec = spGetSpectatingState()

	-- team membership / active state changed: names may resolve differently now
	InvalidateTeamNames()

	if playerID == spGetMyPlayerID() then
		-- our own view changed (resigned, spectator team/fullview switch): what the engine
		-- lets us see changed, so re-check which commanders we track
		if spec and prevSpec ~= spec then
			CheckedForSpec = true
		end
		CheckAllComs()
	end
end

function widget:PlayerAdded(playerID)
	InvalidateTeamNames()
end

function widget:PlayerRemoved(playerID, reason)
	InvalidateTeamNames()
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	CheckCom(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	RemoveCom(unitID)
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	CheckCom(unitID, unitDefID, spGetUnitTeam(unitID) or unitTeam)
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	CheckCom(unitID, unitDefID, spGetUnitTeam(unitID) or newTeam or unitTeam)
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
	widgetHandler:AddAction("comnamescale", toggleNameScaling, nil, "p")
	if data.nameScaling ~= nil then
		nameScaling = data.nameScaling
	end
	if data.version and data.showPlayerRank ~= nil then
		showPlayerRank = data.showPlayerRank
	end
end
