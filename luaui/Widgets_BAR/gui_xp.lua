
function widget:GetInfo()
  return {
    name      = "Rank Icons",
    desc      = "Shows a rank icon depending on experience next to units",
    author    = "trepan (idea quantum,jK)",
    date      = "Feb, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 5,
    enabled   = true  -- loaded by default?
  }
end


local iconsize   = 50
local iconoffset = 17
local scaleIconAmount = 60

local falloffDistance = 1300
local cutoffDistance = 1800

local rankTexBase = 'LuaUI/Images/ranks/'
local rankTextures = {
	[0] = nil,
	[1] = rankTexBase .. 'rank1.png',
	[2] = rankTexBase .. 'rank2.png',
	[3] = rankTexBase .. 'rank3.png',
	[4] = rankTexBase .. 'rank4.png',
	[5] = rankTexBase .. 'rank5.png',
	[6] = rankTexBase .. 'rank6.png',
	[7] = rankTexBase .. 'star.png',
}

local ranks = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {}, [6] = {}, [7] = {} }

local unitPowerXpCoeffient = {}
local unitHeights  = {}

local usedIconsize = iconsize

-- speed-ups
local GetUnitDefID			= Spring.GetUnitDefID
local GetUnitExperience		= Spring.GetUnitExperience
local GetAllUnits			= Spring.GetAllUnits
local IsUnitAllied			= Spring.IsUnitAllied
local IsUnitInView			= Spring.IsUnitInView
local IsUnitIcon			= Spring.IsUnitIcon
local GetSpectatingState	= Spring.GetSpectatingState
local GetCameraPosition		= Spring.GetCameraPosition
local GetUnitPosition		= Spring.GetUnitPosition

local glDepthTest		= gl.DepthTest
local glDepthMask		= gl.DepthMask
local glAlphaTest		= gl.AlphaTest
local glTexture	 		= gl.Texture
local glTexRect	 		= gl.TexRect
local glTranslate		= gl.Translate
local glBillboard		= gl.Billboard
local glColor			= gl.Color
local glDrawFuncAtUnit	= gl.DrawFuncAtUnit

local GL_GREATER = GL.GREATER

local min	= math.min
local floor	= math.floor
local diag	= math.diag

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function widget:GetConfigData()
	return {
		ranks = ranks,
	}
end

function widget:SetConfigData(data) --load config
	if Spring.GetGameFrame() > 0 then
		if data.ranks ~= nil then
			ranks = data.ranks
		end
	end
end

function widget:Initialize()

	for unitDefID, ud in pairs(UnitDefs) do
		ud.power_xp_coeffient  = ((ud.power / 1000) ^ -0.2) / 6  -- dark magic
		unitPowerXpCoeffient[unitDefID] = ud.power_xp_coeffient
		unitHeights[unitDefID] = ud.height + iconoffset
	end

	local allUnits = GetAllUnits()
	for i=1,#allUnits do
		SetUnitRank(allUnits[i])
	end
end

function widget:Shutdown()
	for _,rankTexture in ipairs(rankTextures) do
		gl.DeleteTexture(rankTexture)
	end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function SetUnitRank(unitID)
	local xp = GetUnitExperience(unitID)
	if not xp then
		return
	end
	xp = min(floor(xp / unitPowerXpCoeffient[GetUnitDefID(unitID)]),7)
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function widget:UnitExperience(unitID,unitDefID,unitTeam, xp, oldXP)
	if xp < 0 then xp = 0 end
	if oldXP < 0 then oldXP = 0 end

	local rank    = min(floor(xp / unitPowerXpCoeffient[unitDefID]),7)
	local oldRank = min(floor(oldXP / unitPowerXpCoeffient[unitDefID]),7)

	if rank ~= oldRank then
		for i=0, rank-1 do
			ranks[i][unitID] = nil
		end
		ranks[rank][unitID] = unitDefID
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if IsUnitAllied(unitID) or GetSpectatingState() then
		SetUnitRank(unitID)
	end
end


function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	for i=0,7 do
		ranks[i][unitID] = nil
	end
end


function widget:UnitGiven(unitID, unitDefID, oldTeam, newTeam)
	if not IsUnitAllied(unitID) and not GetSpectatingState()  then
		for i=0,7 do
			ranks[i][unitID] = nil
		end
	end
end


-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local function DrawUnitFunc(yshift)
	glTranslate(0,yshift,0)
	glBillboard()
	glTexRect(-usedIconsize*0.5, -usedIconsize*0.5, usedIconsize*0.5, usedIconsize*0.5)
end


function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorld()
	if chobbyInterface then return end
	if Spring.IsGUIHidden() then return end

	glColor(1,1,1,1)
	glDepthMask(true)
	glDepthTest(true)
	glAlphaTest(GL_GREATER, 0.001)

	local camX, camY, camZ = GetCameraPosition()
	local camDistance

	for i=1, 7 do
		if next(ranks[i]) then
			glTexture(rankTextures[i])
			for unitID,unitDefID in pairs(ranks[i]) do
				if IsUnitInView(unitID) then
					local x,y,z = GetUnitPosition(unitID)
					camDistance = diag(camX-x, camY-y, camZ-z)
					if camDistance < cutoffDistance then
						usedIconsize = (iconsize*0.2) + (camDistance/scaleIconAmount)
						glColor(1,1,1,min(1, 1 - (camDistance-falloffDistance) / cutoffDistance))
						glDrawFuncAtUnit(unitID, false, DrawUnitFunc, unitHeights[unitDefID])
					end
				end
			end
		end
	end

	glColor(1,1,1,1)
	glTexture(false)
	glAlphaTest(false)
	glDepthTest(false)
	glDepthMask(false)
end
