function widget:GetInfo()
	return {
		name = "Rank Icons",
		desc = "Shows a rank icon depending on experience next to units",
		author = "trepan (idea quantum,jK), Floris",
		date = "Feb, 2008",
		license = "GNU GPL, v2 or later",
		layer = 5,
		enabled = true  -- loaded by default?
	}
end

local iconsize = 40
local iconoffset = 22
local scaleIconAmount = 90

local rankScopeDivider = 2.25    -- the higher the number the narrower the scope, the higher the assigned rank will be

local falloffDistance = 1300
local cutoffDistance = 2300

local distanceMult = 1
local usedFalloffDistance = falloffDistance * distanceMult
local usedCutoffDistance = cutoffDistance * distanceMult
local iconsizeMult = 1
local usedIconsize = iconsize * iconsizeMult

local chobbyInterface

local rankTexBase = 'LuaUI/Images/ranks/'
local rankTextures = {
	[0] = nil,
	[1] = rankTexBase .. 'rank1.png',
	[2] = rankTexBase .. 'rank2.png',
	[3] = rankTexBase .. 'rank3.png',
	[4] = rankTexBase .. 'rank4.png',
	[5] = rankTexBase .. 'rank5.png',
	[6] = rankTexBase .. 'rank6.png',
	[7] = rankTexBase .. 'rank7.png',
	[8] = rankTexBase .. 'rank8.png',
	[9] = rankTexBase .. 'rank9.png',
	[10] = rankTexBase .. 'rank10.png',
}

local ranks = {
	[0] = {},
	[1] = {},
	[2] = {},
	[3] = {},
	[4] = {},
	[5] = {},
	[6] = {},
	[7] = {},
	[8] = {},
	[9] = {},
	[10] = {},
}
local numRanks = #ranks

local unitPowerXpCoeffient = {}
local unitHeights = {}

local unitUsedIconsize = usedIconsize

-- speed-ups

local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitExperience = Spring.GetUnitExperience
local GetAllUnits = Spring.GetAllUnits
local IsUnitAllied = Spring.IsUnitAllied
local IsUnitInView = Spring.IsUnitInView
local IsUnitIcon = Spring.IsUnitIcon
local GetSpectatingState = Spring.GetSpectatingState
local GetCameraPosition = Spring.GetCameraPosition
local GetUnitPosition = Spring.GetUnitPosition

local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glAlphaTest = gl.AlphaTest
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glTranslate = gl.Translate
local glBillboard = gl.Billboard
local glColor = gl.Color
local glDrawFuncAtUnit = gl.DrawFuncAtUnit

local GL_GREATER = GL.GREATER

local min = math.min
local max = math.max
local floor = math.floor
local diag = math.diag

local unitIconMult = {}
local isAirUnit = {}
for udid, unitDef in pairs(UnitDefs) do
	unitIconMult[udid] = math.min(1.4, math.max(1.25, (Spring.GetUnitDefDimensions(udid).radius / 40) + math.min(unitDef.power / 400, 2)))
	if unitDef.canFly then
		isAirUnit[udid] = true
	end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function widget:GetConfigData()
	return {
		distanceMult = distanceMult,
		iconsizeMult = iconsizeMult,
	}
end

function widget:SetConfigData(data)
	--load config
	if data.distanceMult ~= nil then
		distanceMult = data.distanceMult
		usedFalloffDistance = falloffDistance * distanceMult
		usedCutoffDistance = cutoffDistance * distanceMult
	end
	if data.iconsizeMult ~= nil then
		iconsizeMult = data.iconsizeMult
		usedIconsize = iconsize * iconsizeMult
	end
end

local function getRank(unitDefID, xp)
	return max(0, min(floor(xp * (1.44 - xp) / unitPowerXpCoeffient[unitDefID]), numRanks))
end

local function updateUnitRank(unitID, unitDefID)
	for i = 0, numRanks do
		ranks[i][unitID] = nil
	end
	local xp = GetUnitExperience(unitID)
	if xp then
		ranks[getRank(unitDefID, xp)][unitID] = unitDefID
	end
end

function widget:Initialize()

	WG['rankicons'] = {}
	WG['rankicons'].getDrawDistance = function()
		return distanceMult
	end
	WG['rankicons'].setDrawDistance = function(value)
		distanceMult = value
		usedFalloffDistance = falloffDistance * distanceMult
		usedCutoffDistance = cutoffDistance * distanceMult
	end
	WG['rankicons'].getScale = function()
		return iconsizeMult
	end
	WG['rankicons'].setScale = function(value)
		iconsizeMult = value
		usedIconsize = iconsize * iconsizeMult
	end
	WG['rankicons'].getRank = function(unitDefID, xp)
		return getRank(unitDefID, xp)
	end
	WG['rankicons'].getRankTextures = function(unitDefID, xp)
		return rankTextures
	end

	for unitDefID, ud in pairs(UnitDefs) do
		unitPowerXpCoeffient[unitDefID] = ((ud.power / 2000) ^ -0.2) / numRanks / rankScopeDivider -- dark magic
		unitHeights[unitDefID] = ud.height + iconoffset
	end

	local allUnits = GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		updateUnitRank(unitID, GetUnitDefID(unitID))
	end
end

function widget:Shutdown()
	for _, rankTexture in ipairs(rankTextures) do
		gl.DeleteTexture(rankTexture)
	end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function widget:UnitExperience(unitID, unitDefID, unitTeam, xp, oldXP)
	if xp < 0 then
		xp = 0
	end
	if oldXP < 0 then
		oldXP = 0
	end

	local rank = getRank(unitDefID, xp)
	local oldRank = getRank(unitDefID, oldXP)

	if rank ~= oldRank then
		--for i = 0, rank - 1 do
		--	ranks[i][unitID] = nil
		--end
		for i = 0, numRanks do
			ranks[i][unitID] = nil
		end
		ranks[rank][unitID] = unitDefID
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if IsUnitAllied(unitID) or GetSpectatingState() then
		updateUnitRank(unitID, GetUnitDefID(unitID))
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	for i = 0, numRanks do
		ranks[i][unitID] = nil
	end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if isAirUnit[unitDefID] and spGetUnitMoveTypeData(unitID).aircraftState == "crashing" then
		widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	end
end

function widget:UnitGiven(unitID, unitDefID, oldTeam, newTeam)
	if not IsUnitAllied(unitID) and not GetSpectatingState() then
		for i = 0, numRanks do
			ranks[i][unitID] = nil
		end
	end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local function DrawUnitFunc(yshift)
	glTranslate(0, yshift, 0)
	glBillboard()
	glTexRect(-unitUsedIconsize * 0.5, -unitUsedIconsize * 0.5, unitUsedIconsize * 0.5, unitUsedIconsize * 0.5)
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
	if Spring.IsGUIHidden() then
		return
	end

	glColor(1, 1, 1, 1)
	glDepthMask(true)
	glDepthTest(true)
	glAlphaTest(GL_GREATER, 0.001)

	local camX, camY, camZ = GetCameraPosition()
	local camDistance

	for i = 1, numRanks do
		if next(ranks[i]) then
			glTexture(rankTextures[i])
			for unitID, unitDefID in pairs(ranks[i]) do
				if IsUnitInView(unitID) then
					local x, y, z = GetUnitPosition(unitID)
					camDistance = diag(camX - x, camY - y, camZ - z)
					if camDistance < usedCutoffDistance then
						local opacity = min(1, 1 - (camDistance - usedFalloffDistance) / usedCutoffDistance)
						unitUsedIconsize = ((usedIconsize * 0.12) + (camDistance / scaleIconAmount)) - ((1 - opacity) * (usedIconsize * 1.25))
						unitUsedIconsize = unitUsedIconsize * unitIconMult[unitDefID]
						glColor(1, 1, 1, opacity)
						glDrawFuncAtUnit(unitID, false, DrawUnitFunc, unitHeights[unitDefID])
					end
				end
			end
		end
	end

	glColor(1, 1, 1, 1)
	glTexture(false)
	glAlphaTest(false)
	glDepthTest(false)
	glDepthMask(false)
end
